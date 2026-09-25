#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# != 1 ]]; then
    echo 'Usage: ./scripts/test-integration.sh /absolute/path/to/test-dog.jpg' >&2
    echo 'Use the 1546 × 1213 sample linked in README.md.' >&2
    exit 1
fi
mkdir -p "$ROOT/.build"
swiftc -O -parse-as-library -target arm64-apple-macosx14.0 \
    -module-cache-path "$ROOT/.cache/swift" \
    "$ROOT/Sources/AppModel.swift" "$ROOT/Sources/ImageFiles.swift" "$ROOT/Sources/CropGeometry.swift" \
    "$ROOT/Sources/InferenceWorker.swift" "$ROOT/Tests/IntegrationTests.swift" \
    -o "$ROOT/.build/integration-tests"
"$ROOT/.build/integration-tests" "$ROOT/artifacts/Cutout.app/Contents/Resources" "$1"
