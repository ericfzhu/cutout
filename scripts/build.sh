#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_ROOT="$ROOT/.cache/python/cpython-3.11.14-macos-aarch64-none"
APP="$ROOT/artifacts/Cutout.app"
if [[ ! -f "$ROOT/.cache/segmentation/model.safetensors" || ! -f "$ROOT/.cache/model/model.safetensors" || ! -d "$ROOT/.cache/site-packages/torch" ]]; then
    echo 'Run ./scripts/setup-runtime.sh first.' >&2
    exit 1
fi
mkdir -p "$ROOT/.build" "$APP/Contents/MacOS" "$APP/Contents/Resources/Runtime"
export CLANG_MODULE_CACHE_PATH="$ROOT/.cache/clang"
swiftc -O -parse-as-library -target arm64-apple-macosx14.0 \
    -module-cache-path "$ROOT/.cache/swift" "$ROOT"/Sources/*.swift \
    -o "$APP/Contents/MacOS/Cutout"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Runtime/worker.py" "$ROOT/Runtime/model-manifest.json" "$ROOT/Runtime/segmentation-manifest.json" "$ROOT/Runtime/requirements.lock" "$APP/Contents/Resources/Runtime/"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/"
cp "$ROOT/README.md" "$APP/Contents/Resources/"
# rsync preserves relative interpreter symlinks; the bundle is relocatable.
rsync -a --delete --exclude '__pycache__' "$PYTHON_ROOT/" "$APP/Contents/Resources/Runtime/python/"
rsync -a --delete --exclude '__pycache__' "$ROOT/.cache/site-packages/" "$APP/Contents/Resources/Runtime/site-packages/"
rsync -a --delete --exclude '__pycache__' "$ROOT/.cache/model/" "$APP/Contents/Resources/Runtime/model/"
rsync -a --delete --exclude '__pycache__' "$ROOT/.cache/segmentation/" "$APP/Contents/Resources/Runtime/segmentation/"
swiftc -module-cache-path "$ROOT/.cache/swift" "$ROOT/scripts/make-icon.swift" -o "$ROOT/.build/make-icon"
"$ROOT/.build/make-icon" "$ROOT/.build/Cutout.iconset"
iconutil -c icns "$ROOT/.build/Cutout.iconset" -o "$APP/Contents/Resources/Cutout.icns"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
