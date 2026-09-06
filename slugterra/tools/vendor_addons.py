"""Install pinned upstream addon directories, preserving their licenses and code."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import urllib.request
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
LOCK = PROJECT / "addons.lock.json"


def install() -> None:
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    cache = PROJECT.parent / ".downloads"
    cache.mkdir(exist_ok=True)
    for addon in lock["addons"]:
        archive = cache / f'{addon["name"]}-{addon["version"]}.zip'
        if not archive.exists():
            print(f'Downloading {addon["name"]} {addon["version"]}', flush=True)
            request = urllib.request.Request(addon["url"], headers={"User-Agent": "Slugterra-build"})
            with urllib.request.urlopen(request, timeout=90) as response:
                archive.write_bytes(response.read())
        actual = hashlib.sha256(archive.read_bytes()).hexdigest()
        if actual != addon["sha256"]:
            raise ValueError(f'Checksum mismatch for {addon["name"]}: {actual}')
        marker = f'addons/{addon["directory"]}/'
        if addon["name"] == "gdUnit4":
            marker = "addons/gdUnit4/"
        destination = (PROJECT / "addons" / addon["directory"]).resolve()
        count = 0
        with zipfile.ZipFile(archive) as package:
            for entry in package.infolist():
                name = entry.filename.replace("\\", "/")
                # Source archives may wrap the project in a repository directory.
                start = name.find(marker)
                if start < 0 or (start > 0 and name[start - 1] != "/") or entry.is_dir():
                    continue
                relative = PurePosixPath(name[start + len(marker):])
                target = destination.joinpath(*relative.parts).resolve()
                if not target.is_relative_to(destination):
                    raise ValueError(f"Unsafe archive member: {name}")
                contents = package.read(entry)
                if target.exists() and target.suffix == ".import":
                    # Godot may have regenerated this cache sidecar locally.
                    continue
                if target.exists():
                    if target.read_bytes() != contents:
                        raise ValueError(f"Refusing to overwrite modified vendor file: {target}")
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(contents)
                count += 1
        if count == 0:
            raise ValueError(f"Archive has no {marker} directory")
        print(f'Verified {addon["name"]}: {count} files ({actual})', flush=True)


if __name__ == "__main__":
    install()
