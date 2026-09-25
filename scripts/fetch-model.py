"""Build-time downloads only; all model code and weights are pinned and hashed."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "Runtime/model-manifest.json").read_text())
target = root / ".cache/model"
target.mkdir(parents=True, exist_ok=True)


def digest(path):
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


for manifest_name, folder in [("model-manifest.json", "model"), ("segmentation-manifest.json", "segmentation")]:
    manifest = json.loads((root / "Runtime" / manifest_name).read_text())
    target = root / ".cache" / folder
    target.mkdir(parents=True, exist_ok=True)
    for name, expected in manifest["files"].items():
        destination = target / name
        if destination.exists() and digest(destination) == expected:
            print(f"Verified {name}", flush=True)
            continue
        url = f'https://huggingface.co/{manifest["repository"]}/resolve/{manifest["revision"]}/{name}'
        partial = destination.with_suffix(destination.suffix + ".download")
        subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--output", str(partial), url], check=True)
        if digest(partial) != expected:
            partial.unlink()
            raise RuntimeError(f"Checksum mismatch for {name}")
        partial.replace(destination)
    (target / "__init__.py").touch()
