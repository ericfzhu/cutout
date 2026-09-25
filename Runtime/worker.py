"""Offline, persistent BiRefNet worker. JSON lines over stdin/stdout; no sockets."""
import contextlib
import gc
import json
import os
from pathlib import Path
import sys
import time
import traceback

# Set before importing the inference stack. Never fetch code, weights or telemetry.
os.environ.update(HF_HUB_OFFLINE="1", TRANSFORMERS_OFFLINE="1",
                  HF_HUB_DISABLE_TELEMETRY="1", DO_NOT_TRACK="1",
                  PYTORCH_ENABLE_MPS_FALLBACK="1", TOKENIZERS_PARALLELISM="false")
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "site-packages"))
sys.path.insert(0, str(ROOT))
PROTOCOL = sys.stdout


def emit(**event):
    PROTOCOL.write(json.dumps(event) + "\n")
    PROTOCOL.flush()


class Engine:
    def __init__(self, mode="segmentation"):
        if mode not in ("segmentation", "matting"):
            raise ValueError("Unknown background removal mode.")
        self.mode = mode
        import torch
        from model import birefnet as architecture
        from model.birefnet import BiRefNet
        from model.BiRefNet_config import BiRefNetConfig
        from safetensors.torch import load_file

        self.torch = torch
        torch.set_num_threads(4)
        self.device = "mps" if torch.backends.mps.is_available() else "cpu"
        self.dtype = torch.float16 if self.device == "mps" else torch.float32
        if self.device == "mps":
            # torchvision's deformable convolution has no Metal kernel. Its CPU
            # FP16 path is extremely slow, so run just this operation in FP32.
            from torchvision.ops import deform_conv2d

            def metal_deform_conv(**kwargs):
                tensor = kwargs["input"]
                cpu = {key: value.to(device="cpu", dtype=torch.float32)
                       if isinstance(value, torch.Tensor) else value
                       for key, value in kwargs.items()}
                return deform_conv2d(**cpu).to(device=tensor.device, dtype=tensor.dtype)

            architecture.deform_conv2d = metal_deform_conv
        # Avoid allocating and initializing a second full copy of the model.
        with torch.device("meta"):
            self.model = BiRefNet(config=BiRefNetConfig(bb_pretrained=False))
        weights_folder = "segmentation" if mode == "segmentation" else "model"
        weights = load_file(str(ROOT / weights_folder / "model.safetensors"))
        self.model.load_state_dict(weights, strict=True, assign=True)
        del weights
        self.model.eval().requires_grad_(False).to(device=self.device, dtype=self.dtype)

    def remove(self, source, destination):
        import numpy as np
        from PIL import Image, ImageOps
        from torchvision import transforms

        torch = self.torch
        with Image.open(source) as opened:
            if opened.width * opened.height > 40_000_000:
                raise ValueError("Please use an image smaller than 40 megapixels.")
            original = ImageOps.exif_transpose(opened).convert("RGBA")
        # Composite existing transparency onto white for model input, but retain
        # original alpha in the export (never resurrect transparent pixels).
        rgb = Image.new("RGBA", original.size, (255, 255, 255, 255))
        rgb.alpha_composite(original)
        transform = transforms.Compose([
            transforms.Resize((1024, 1024)), transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        ])
        tensor = transform(rgb.convert("RGB")).unsqueeze(0).to(device=self.device, dtype=self.dtype)
        start = time.monotonic()
        with torch.inference_mode():
            prediction = self.model(tensor)[-1].sigmoid().float().cpu()[0, 0]
        if not torch.isfinite(prediction).all():
            raise RuntimeError("The model returned an invalid mask. Please try another image.")
        # Continuous alpha, not a binary threshold: retain hair and soft edges.
        matte = Image.fromarray((prediction.numpy() * 255).round().clip(0, 255).astype(np.uint8))
        matte = matte.resize(original.size, Image.Resampling.LANCZOS)
        alpha = np.asarray(original.getchannel("A"), dtype=np.uint16)
        combined = (np.asarray(matte, dtype=np.uint16) * alpha + 127) // 255
        original.putalpha(Image.fromarray(combined.astype(np.uint8)))
        temporary = str(destination) + ".partial"
        original.save(temporary, format="PNG")
        os.replace(temporary, destination)
        seconds = time.monotonic() - start
        del tensor, prediction, rgb, original, matte, alpha, combined
        gc.collect()
        if self.device == "mps":
            torch.mps.empty_cache()
        return seconds


def main():
    engine = None
    for line in sys.stdin:
        request = {}
        try:
            request = json.loads(line)
            if not isinstance(request, dict):
                request = {}
                raise ValueError("Expected a JSON object.")
            request_id = request["id"]
            with contextlib.redirect_stdout(sys.stderr):
                mode = request.get("mode", "segmentation")
                if mode not in ("segmentation", "matting"):
                    raise ValueError("Unknown background removal mode.")
                if engine is None or engine.mode != mode:
                    # Hold only one model in unified memory, including during switching.
                    engine = None
                    gc.collect()
                    import torch
                    if torch.backends.mps.is_available():
                        torch.mps.empty_cache()
                    emit(id=request_id, event="status", message="Loading " + mode + "…")
                    engine = Engine(mode)
                emit(id=request_id, event="status", message="Removing background…")
                seconds = engine.remove(request["input"], request["output"])
            emit(id=request_id, event="complete", output=request["output"],
                 seconds=round(seconds, 2), device=engine.device)
        except Exception as error:
            traceback.print_exc(file=sys.stderr)
            emit(id=request.get("id", ""), event="error", message=str(error))
            # Release memory and allow the next request to recover cleanly.
            engine = None
            gc.collect()


if __name__ == "__main__":
    main()
