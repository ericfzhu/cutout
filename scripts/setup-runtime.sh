#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export UV_CACHE_DIR="$ROOT/.cache/uv"
PYTHON="$ROOT/.cache/python/cpython-3.11.14-macos-aarch64-none/bin/python3"
if ! command -v uv >/dev/null; then
    echo 'Install uv first: https://docs.astral.sh/uv/getting-started/installation/' >&2
    exit 1
fi
if [[ "$(uname -m)" != arm64 ]]; then
    echo 'This build targets Apple Silicon Macs.' >&2
    exit 1
fi
uv python install 3.11.14 --install-dir "$ROOT/.cache/python" --no-bin
uv pip install --python "$PYTHON" --target "$ROOT/.cache/site-packages" -r "$ROOT/Runtime/requirements.lock"
"$PYTHON" "$ROOT/scripts/fetch-model.py"
cp "$ROOT/ThirdParty/BiRefNet-LICENSE" "$ROOT/.cache/model/LICENSE"
ln -sfn ../.cache/segmentation "$ROOT/Runtime/segmentation"
ln -sfn ../.cache/model "$ROOT/Runtime/model"
ln -sfn ../.cache/site-packages "$ROOT/Runtime/site-packages"
echo 'Runtime ready. Build with ./scripts/build.sh'
