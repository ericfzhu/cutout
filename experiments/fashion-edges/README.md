# Fashion-product extraction experiment

Completed locally on M1 Pro / 16 GB. Eight variants on two supplied images; 16 transparent PNG results. No images uploaded. Installed Cutout app and its inference pipeline unchanged.

## Finding

Standard BiRefNet segmentation is the strongest direction for these opaque fashion products. On the shirt it produces a visibly tighter sleeve and hem outline than current BiRefNet-matting. On the boot, a second segmentation pass around the product improves tread gaps and reduces retained cast shadow. The main lace loop and openings remain visible. Full silhouettes were also inspected.

ViTMatte did not consistently improve these results: the initial 1024-long-edge refinement brought back softness and some shadow. A higher-detail region pass recovered better tread gaps but still offered no clear overall advantage over the unrefined segmentation result. This conclusion applies to this trimap recipe and these images, not to ViTMatte generally.

Recommended next implementation: a Product mode using segmentation, with an optional product-focused detail pass. Keep the existing matting option for delicate/translucent items, pending actual lace/mesh tests. Do not automatically replace every workflow based on two samples.

## Comparisons and outputs

- [Boot selected comparison](results/boot-selected.jpg)
- [Shirt selected comparison](results/shirt-selected.jpg)
- [All boot sole variants](results/boot-comparison.jpg)
- [All shirt sleeve variants](results/shirt-comparison.jpg)
- [All boot lace variants](results/boot-laces-comparison.jpg)
- [Selected boot transparent PNG](results/boot-segmentation-roi.png)
- [Selected shirt transparent PNG](results/shirt-segmentation.png)
- [Raw timings](results/timings.json)

## Method

Inputs: `/Users/eric/Downloads/867708WCB452010_F.jpg` (2200×2200) and `/Users/eric/Downloads/A4568001_4.webp` (1429×2000). Original files were not modified. Output canvas dimensions remain unchanged.

BiRefNet runs at 1024×1024 through the existing local worker, MPS FP16 with its existing CPU fallback for deformable convolution. Standard segmentation weights load strictly into the bundled architecture. No downloaded remote Python model code was executed.

The product-focused pass uses the current matting result’s alpha >127 bounding box, padded by 10% of its larger dimension. The cropped source is processed at 1024×1024, then the alpha is placed back on the original canvas. Boot region: [309,958,1891,2118]. Shirt region: [48,295,1378,1606]. This spends more inference resolution on the item; it is not simply keeping the largest connected component.

ViTMatte uses original RGB and a trimap generated around the 50% alpha contour, with 13×13 min/max filters (roughly six pixels each side). Confident foreground/background stay fixed. Initial refinement preserves aspect ratio with longest edge 1024. Additional high-detail refinement uses the product region with longest edge capped at 1536: boot 1536×1126; shirt 1330×1311. RGB is preserved; only alpha changes.

| Variant | Boot seconds | Shirt seconds |
| --- | ---: | ---: |
| Current matting | 15.377 | 10.163 |
| Matting product-region pass | 10.915 | 10.277 |
| Segmentation | 10.411 | 11.009 |
| Segmentation product-region pass | 8.924 | 11.362 |
| Current + ViTMatte refinement | 4.250 | 0.965 |
| Segmentation + ViTMatte refinement | 0.589 | 0.387 |
| Product segmentation + ViTMatte refinement | 0.581 | 0.381 |
| Product segmentation + high-detail refinement | 2.477 | 1.462 |

Times are single executions including output save, excluding model loading. Refinement rows measure the additional refinement only; product-region rows measure the additional pass only. The tested boot selection requires baseline + region segmentation (~24.3 seconds combined inference/save), plus loading overhead. A future implementation could derive bounds using segmentation alone, but that pipeline was not evaluated. Warm full-frame BiRefNet runs were approximately 10–11 seconds. No rigorous memory benchmark was performed.

## Limits

Visual comparison only, without ground-truth masks or quantitative accuracy scores. These two examples do not establish performance on lace, mesh, fringe, complex backgrounds, multiple items, or all cast shadows. HR-matting, Lucida fine-tunes and SAM-based alternatives were not included in this focused comparison. There is no claim of perfect shadow removal.

## Reproduce

Run from the Cutout project root using its existing bundled Python and dependencies:

```sh
PYTHONPATH=.cache/site-packages .cache/python/cpython-3.11.14-macos-aarch64-none/bin/python3 experiments/fashion-edges/download.py
.cache/python/cpython-3.11.14-macos-aarch64-none/bin/python3 experiments/fashion-edges/run.py
.cache/python/cpython-3.11.14-macos-aarch64-none/bin/python3 experiments/fashion-edges/refine_detail.py
PYTHONPATH=.cache/site-packages .cache/python/cpython-3.11.14-macos-aarch64-none/bin/python3 experiments/fashion-edges/make_comparisons.py
```

Download revisions and SHA256 hashes are recorded in `model-provenance.json`; downloader is pinned to the tested revisions. Network is needed only to download the two experiment checkpoints (~548 MB total). Inference uses local files. Models and result images are ignored by this experiment’s `.gitignore`.

Model sources: [BiRefNet](https://github.com/ZhengPeng7/BiRefNet), [standard weights](https://huggingface.co/ZhengPeng7/BiRefNet), [ViTMatte](https://github.com/hustvl/ViTMatte), [small checkpoint](https://huggingface.co/hustvl/vitmatte-small-composition-1k).
