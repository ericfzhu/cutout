# Image processing

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

To inspect edges, pinch to zoom or use the magnifier buttons (⌘= / ⌘−).
Drag or scroll to pan while zoomed. Click **Fit** or press **⌘0** to show the
whole image again. The zoom readout is relative to Fit, up to 16×. Switching
Original/Cutout preserves the view; opening another image or entering crop mode
resets it. Crop mode uses the fitted image so dragging edits the crop.
Zoom and pan affect only the preview, never the exported dimensions.

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

Images are processed on your Mac. The app has no upload path or local web server;
model downloading and telemetry are disabled at runtime. Building from source
requires a one-time download of the runtime and model dependencies.

Working images live in a temporary session folder, removed when replaced or
when Cutout quits normally. Force-quitting can leave temporary files until macOS
cleans them up. Saved PNGs are written only to the location you choose.
Runtime diagnostics live at `~/Library/Caches/local.cutout.app/runtime.log`.

