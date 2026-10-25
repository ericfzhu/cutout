<p align="center">
  <img src="docs/assets/cutout-icon.png" width="96" height="96" alt="Cutout app icon">
</p>

<h1 align="center">Cutout</h1>
<p align="center">Remove image backgrounds. Keep everything on your Mac.</p>
<p align="center">
  <a href="https://github.com/ericfzhu/cutout/releases/latest">Download for Mac</a> ·
  <a href="#using-cutout">Usage</a> ·
  <a href="CHANGELOG.md">What's new</a> ·
  <a href="docs/DEVELOPMENT.md">Build from source</a>
</p>

Cutout is a small native macOS app for turning images into transparent PNGs.
Drop, paste, or open an image, inspect the result, crop it, and copy or save it.
Background removal runs locally with bundled models—no account, uploads,
subscription, or separate Python installation.

![Cutout showing a dog with its background removed on the graph-paper canvas, with mode selection, zoom, crop, copy, and save controls.](docs/assets/cutout-screenshot.jpg)

*Inspect a cutout against the graph-paper preview, then crop, copy, or save a
transparent PNG. Sample photograph from [PyTorch Hub](https://github.com/pytorch/hub/blob/master/images/dog.jpg).*

## Get Cutout

Download **Cutout-1.0.0-macOS-arm64.zip** from the
[latest release](https://github.com/ericfzhu/cutout/releases/latest), unzip it,
and move **Cutout.app** into your Applications folder.

- **Apple Silicon Mac · macOS 14 or newer.** Intel Macs are not supported by this build.
- The runtime and two models are bundled, so the download is large. Once installed,
  image processing works offline.
- This personal-use build is **ad-hoc signed, not notarized**. macOS may block its
  first launch. It does not have a verified Developer ID signature.
- Each release includes `SHA256SUMS` to verify the downloaded ZIP.

GitHub's automatic “Source code” archives contain the project, not the ready-to-run app.

## Using Cutout

1. **Open an image.** Drop it into the window, paste with **⌘V**, or use **⌘O**.
   Cutout acknowledges the import immediately and shows an early original-image
   preview while preparation continues. Background removal starts automatically.
2. **Choose a mode.** Start with **Segmentation** for solid objects, clothing,
   and shoes. Try **Matting** for soft edges and translucent details. Use the **?**
   control for guidance. Completed results are cached while the image stays open.
3. **Inspect the edges.** Switch between Original and Cutout, and choose a grid,
   white, or dark preview background. Pinch or use the magnifiers to zoom;
   drag or scroll to pan. **Fit** returns to the whole image.
4. **Crop if needed.** Drag the crop's corners or edges, or move the selection.
   Done applies it; Cancel discards the edit. Reset restores the full image.
   Entering crop mode returns to the fitted view.
5. **Copy or save.** Copy the result with **⌘C**, or save with **⌘S**.
   The output is a transparent PNG, regardless of the preview background.

Zoom and pan only change the view. Cropping changes the exported dimensions
without rerunning background removal. The dimensions above the controls show
that export size.

### Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Open image | ⌘O |
| Paste image | ⌘V |
| Copy cutout | ⌘C |
| Save PNG | ⌘S |
| Zoom in / out | ⌘= / ⌘− |
| Fit image to window | ⌘0 |

## Private by design

Images are processed on your Mac. The app has no upload path or local web server;
model downloading and telemetry are disabled at runtime. Building from source
requires a one-time download of the runtime and model dependencies.

Working images live in a temporary session folder, removed when replaced or
when Cutout quits normally. Force-quitting can leave temporary files until macOS
cleans them up. Saved PNGs are written only to the location you choose.
Runtime diagnostics live at `~/Library/Caches/local.cutout.app/runtime.log`.

## What to expect

Cutout processes one image at a time. The first image after launch also loads the
model, so it takes longer than subsequent images. It uses the Apple GPU where
supported, with CPU fallbacks for some operations.

Fine hair, lace, transparency, and shadows can still need manual editing.
Output retains the source resolution, but the model estimates the matte at
1024 × 1024. Files over 250 MB and images over 40 megapixels are rejected.
Only the first frame of animated or multipage images is used.

For model details and limitations, see [Image processing](docs/IMAGE-PROCESSING.md).
For setup, testing, and sample performance measurements, see
[Development](docs/DEVELOPMENT.md).

## Project notes

Cutout is a personal project built with SwiftUI, AppKit, and a bundled Python
inference worker. It uses BiRefNet and BiRefNet-matting by Peng Zheng and
collaborators. See [third-party notices](THIRD_PARTY_NOTICES.md) for model,
runtime, and dependency attributions.

Found a problem? [Open an issue](https://github.com/ericfzhu/cutout/issues/new)
with your macOS version, Mac model, and steps to reproduce it. Include an example
image only if you are comfortable sharing it publicly.
