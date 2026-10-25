# Developing Cutout

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

## Source layout

- `Sources/`: native SwiftUI UI, image preparation and worker lifecycle
- `Runtime/worker.py`: local inference and PNG export
- `Runtime/model-manifest.json`: pinned model revision and checksums
- `scripts/`: reproducible setup and standalone app packaging
- `Tests/`: image and end-to-end regression checks
- `.cache/`, `.build/`, `artifacts/`: ignored generated dependencies and binaries

Third-party notices are in `THIRD_PARTY_NOTICES.md` and bundled package metadata.

## Tests and measured performance

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

## Packaging a release

Build on an Apple Silicon Mac, run the tests, then run `./scripts/package-release.sh`.
The script packages the signed app as a ZIP and writes `SHA256SUMS` in
`artifacts/release/`. Publish those two files together on the matching GitHub release.

Keep the app version in `Info.plist`, the release tag, and `CHANGELOG.md` aligned.
Release notes should state the supported macOS version, architecture, and signing status.
The current build is ad-hoc signed; it is not Developer ID signed or notarized.
