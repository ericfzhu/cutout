# Cutout

A personal, offline Mac app for automatic background removal. Drop an image,
paste with ⌘V, or open with ⌘O. Processing starts automatically. Compare the
original with the cutout, preview against white/dark/graph-paper backgrounds,
then copy with ⌘C or save a transparent PNG with ⌘S.

Use **Crop** after background removal. Drag a corner or edge to resize the frame,
or drag inside it to move. **Done** applies the crop to the preview, clipboard
and saved PNG. **Cancel** discards crop edits; **Reset Crop** restores the full
image. Cropping is reversible and does not rerun the model. The dimensions
above the bottom dock show the resulting export size.

## Run

Open `artifacts/Cutout.app`. You can drag the app into your Applications folder.
It contains its own model and runtime: no Python installation, account,
internet connection or localhost server is required to use it.

Requires an Apple Silicon Mac running macOS 14 or newer. The target machine
is an M1 Pro with 16 GB unified memory. One image is processed at a time.

## Build

Requires Apple's Command Line Tools (or Xcode) and uv. From this directory:

```sh
./scripts/setup-runtime.sh  # one-time network downloads
./scripts/build.sh         # builds and ad-hoc signs artifacts/Cutout.app
open artifacts/Cutout.app
```

The runtime is a bundled, relocatable CPython 3.11 with pinned dependencies.
The SwiftUI app launches one persistent child process and exchanges JSON over
anonymous pipes. The worker loads pinned local Python model code directly and
safetensors weights, without remote-code loading or downloads. Model artifacts
are SHA-256 verified during setup. Hugging Face offline mode and telemetry
opt-out are always enabled. There is no HTTP server or upload path.

## Image processing

Defaults to **ZhengPeng7/BiRefNet** segmentation for solid products. The top-right
selector switches to **ZhengPeng7/BiRefNet-matting** for soft edges. Switching
processes each mode once per image and preserves the crop. Completed mode results
are reused immediately. Cancelling a mode switch restores the last completed
result; importing another image clears both cached results. The selector is disabled
while processing or editing a crop. Each launch starts with Segmentation.
Both checkpoints are bundled offline; only one is loaded in memory at a time.
Both run at 1024 × 1024 with ImageNet normalization.
The model predicts continuous alpha, preserving soft edges rather than applying
a hard binary cutoff. That alpha is resized to the source dimensions and
multiplied by any existing transparency. The source RGB content is preserved.
The input's orientation and color profile are normalized to sRGB before inference.
Exports are always transparent PNG, regardless of the preview background.

The Apple GPU uses PyTorch MPS when available; unsupported operations may run
on the CPU. Metal uses FP16, with deformable convolutions explicitly computed
in FP32 on the CPU to avoid a very slow CPU FP16 kernel. A CPU-only FP32 path
works when Metal is unavailable. The app does not
use Apple's foreground extraction as a silent substitute for BiRefNet.

Matting is imperfect: fine details, transparent objects, cast shadows and
background color fringing can need further editing. This app does not relight
the subject, remove shadows on the subject, or promise remove.bg parity.
Export dimensions match the source, but matte detail comes from 1024-pixel inference.
The first frame of animated/multipage files is used. Images over 40 megapixels
or files over 250 MB are rejected to bound memory use.

## Local data

Images are held in a private temporary session folder and removed when replaced
or when the app quits normally. Force-quitting can leave temporary files until
macOS cleans its temporary directory. Exported files are only written to the
location you select. Runtime diagnostics are stored at
`~/Library/Caches/local.cutout.app/runtime.log` (replaced each worker start).
The app is ad-hoc signed for personal use, not notarized for public distribution.

## Source layout

- `Sources/`: native SwiftUI UI, image preparation and worker lifecycle
- `Runtime/worker.py`: local inference and PNG export
- `Runtime/model-manifest.json`: pinned model revision and checksums
- `scripts/`: reproducible setup and standalone app packaging
- `Tests/`: image and end-to-end regression checks
- `.cache/`, `.build/`, `artifacts/`: ignored generated dependencies and binaries

Third-party notices are in `THIRD_PARTY_NOTICES.md` and bundled package metadata.

## Validation on the target Mac

Tested on 22 September 2026 with the public dog photograph from
https://github.com/pytorch/hub/blob/master/images/dog.jpg (1546 × 1213).
This test image is not bundled in the app.

- MPS mixed precision: 9.40 seconds for the first inference and 8.25 seconds
  for a second image in the same worker, excluding initial Python/model startup.
- `time -l` reported a peak memory footprint of 7.19 GB (6.70 GiB) across that run.
- CPU FP32 reference: 14.34 seconds for inference.
- Mixed-precision alpha differed from the CPU reference by 0.0103/255 on average;
  the largest per-pixel difference was 3/255 on this image.
- Native UI import, clipboard copy/paste and transparent PNG export were checked.
- Integration tests passed for automatic file drop processing, cancellation,
  restart/retry, and invalid-image recovery retaining the previous result.
- Unit checks cover soft-alpha composition, existing transparency, orientation,
  malformed worker requests and invalid image data.

Run the unit checks with `./scripts/test.sh`. For the full local runtime test:

```sh
./scripts/test-integration.sh /absolute/path/to/test-dog.jpg
```

These are sample measurements, not a guarantee for all images or system loads.
