#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/.cache/python/cpython-3.11.14-macos-aarch64-none/bin/python3" -B "$ROOT/Tests/test_worker.py"
mkdir -p "$ROOT/.build"
swiftc -parse-as-library -module-cache-path "$ROOT/.cache/swift" \
    "$ROOT/Sources/ImageFiles.swift" "$ROOT/Sources/CropGeometry.swift" "$ROOT/Tests/ImageFilesTests.swift" \
    "$ROOT/Tests/TestError.swift" -o "$ROOT/.build/image-tests"
"$ROOT/.build/image-tests"
swiftc -parse-as-library -module-cache-path "$ROOT/.cache/swift" \
    "$ROOT/Sources/CanvasViewport.swift" "$ROOT/Tests/CanvasViewportTests.swift" \
    -o "$ROOT/.build/viewport-tests"
"$ROOT/.build/viewport-tests"
swiftc -parse-as-library -module-cache-path "$ROOT/.cache/swift" \
    "$ROOT/Sources/AppModel.swift" "$ROOT/Sources/ImageFiles.swift" \
    "$ROOT/Sources/CropGeometry.swift" "$ROOT/Sources/InferenceWorker.swift" \
    "$ROOT/Tests/ImportTests.swift" -o "$ROOT/.build/import-tests"
"$ROOT/.build/import-tests"
