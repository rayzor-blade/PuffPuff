#!/usr/bin/env python3
"""Pin native/hdlls.json to the blinc_abi libraries of an Ashui release, with their checksums."""

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path


MANIFEST = Path(__file__).resolve().parent.parent / "native/hdlls.json"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", help="release tag, such as v0.2.3")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    with tempfile.TemporaryDirectory() as directory:
        subprocess.run(["gh", "release", "download", args.tag, "--repo", manifest["source"]["repository"],
                        "--pattern", "blinc_abi-*.hdll", "--dir", directory], check=True)
        for platform, entry in manifest["platforms"].items():
            path = Path(directory) / entry["releaseAsset"]
            if not path.is_file():
                raise SystemExit(f"{args.tag} has no {entry['releaseAsset']}")
            entry["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            print(f"{platform}: {entry['sha256']}")
    manifest["source"]["tag"] = args.tag
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
