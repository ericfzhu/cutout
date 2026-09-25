"""Checks image correctness without spending time on model inference."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".cache/site-packages"))
import numpy as np
import torch
from PIL import Image

spec = importlib.util.spec_from_file_location("worker", ROOT / "Runtime/worker.py")
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class WorkerTests(unittest.TestCase):
    def test_soft_alpha_multiplies_existing_transparency_and_preserves_rgb(self):
        class ConstantMatte:
            def __call__(self, tensor):
                # sigmoid(0) == 0.5, a soft edge rather than a binary mask.
                return [torch.zeros((1, 1, 1024, 1024))]

        engine = worker.Engine.__new__(worker.Engine)
        engine.torch = torch
        engine.device = "cpu"
        engine.dtype = torch.float32
        engine.model = ConstantMatte()
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "image.png"
            output = Path(folder) / "cutout.png"
            pixels = np.zeros((9, 17, 4), dtype=np.uint8)
            pixels[:, :, :3] = (90, 160, 220)
            pixels[:, :5, 3] = 0
            pixels[:, 5:10, 3] = 128
            pixels[:, 10:, 3] = 255
            Image.fromarray(pixels).save(source)
            engine.remove(source, output)
            result = Image.open(output)
            actual = np.asarray(result)
            self.assertEqual(result.mode, "RGBA")
            self.assertEqual(result.size, (17, 9))
            np.testing.assert_array_equal(actual[:, :, :3], pixels[:, :, :3])
            self.assertTrue((actual[:, :5, 3] == 0).all())
            self.assertTrue((actual[:, 5:10, 3] == 64).all())
            self.assertTrue((actual[:, 10:, 3] == 128).all())
            self.assertFalse(Path(str(output) + ".partial").exists())

    def test_protocol_survives_malformed_requests(self):
        import json
        process = subprocess.run(
            [sys.executable, "-B", str(ROOT / "Runtime/worker.py")],
            input="not json\n[]\n", capture_output=True, text=True, timeout=10,
            env={**os.environ, "HF_HUB_OFFLINE": "1"},
        )
        self.assertEqual(process.returncode, 0, process.stderr)
        events = [json.loads(line) for line in process.stdout.splitlines()]
        self.assertEqual([event["event"] for event in events], ["error", "error"])


if __name__ == "__main__":
    unittest.main()
