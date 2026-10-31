#!/usr/bin/env python3
"""Validate and optionally submit the release ZIP."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from zipfile import ZipFile


sys.path.insert(0, str(Path(__file__).resolve().parent))
from package_haxelib import SEMVER, relative_references, version_of  # noqa: E402


def validate(path, account, tag):
    with ZipFile(path) as archive:
        metadata = json.loads(archive.read("haxelib.json"))
        version = metadata["version"]
        if not SEMVER.fullmatch(version):
            raise ValueError(f"invalid Haxelib version {version}")
        if version != version_of(tag):
            raise ValueError(f"{version} does not match release {tag}")
        if account not in metadata.get("contributors", []):
            raise ValueError(f"contributors must include {account}")
        for name in ("LICENSE", "README.md", "extraParams.hxml"):
            if name not in archive.namelist():
                raise ValueError(f"archive is missing {name}")
        # Haxelib shows the README on its own site, where relative paths don't resolve.
        left = relative_references(archive.read("README.md").decode())
        if left:
            raise ValueError("README links and embeds must be absolute for Haxelib: " + ", ".join(left))
    return metadata


def prepare_contributors(path, account):
    """Set the publishing owner on the release copy."""
    with ZipFile(path) as archive:
        metadata = json.loads(archive.read("haxelib.json"))
        contributors = [account] + [name for name in metadata.get("contributors", []) if name != account]
        if contributors == metadata.get("contributors"):
            return
        metadata["contributors"] = contributors
        temporary = path.with_suffix(".tmp")
        with ZipFile(temporary, "w") as patched:
            for entry in archive.infolist():
                data = json.dumps(metadata, indent=2) + "\n" if entry.filename == "haxelib.json" else archive.read(entry)
                patched.writestr(entry, data)
    temporary.replace(path)


def registry_versions(name):
    result = subprocess.run(["haxelib", "info", name], text=True, capture_output=True, timeout=120)
    if result.returncode:
        if "No such Project" in result.stdout + result.stderr:
            return set()
        raise ValueError(f"Could not query Haxelib for {name}: {result.stdout}{result.stderr}")
    return set(re.findall(r"(?m)^\s+[^\n]*?\s(\d+\.\d+\.\d+(?:-[^:\s]+)?)\s*:", result.stdout))


def submit(path, metadata, account, password):
    # Check every dependency is published before submitting.
    for dependency, version in metadata.get("dependencies", {}).items():
        published = registry_versions(dependency)
        if not published or version and version not in published:
            raise ValueError(f"Publish dependency {dependency}{' ' + version if version else ''} first")
    name, version = metadata["name"], metadata["version"]
    if version in registry_versions(name):
        print(f"{name} {version}: already published; skipping")
        return
    arguments = ["haxelib", "submit", str(path)]
    if len(metadata["contributors"]) > 1:
        arguments.append(account)
    arguments += [password, "--never"]
    # Don't let an exception message include the password argument.
    result = subprocess.run(arguments, stdin=subprocess.DEVNULL, timeout=600)
    if result.returncode:
        raise ValueError(f"Submission failed for {name} {version} (exit {result.returncode})")
    if version not in registry_versions(name):
        raise ValueError(f"Haxelib did not report the submitted {name} {version}")
    print(f"{name} {version}: published")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--account", default="rayzor")
    parser.add_argument("--submit", action="store_true", help="submit using HAXELIB_PASSWORD; otherwise validate only")
    args = parser.parse_args()
    try:
        if args.submit and not os.environ.get("HAXELIB_PASSWORD"):
            raise ValueError("Configure the HAXELIB_PASSWORD GitHub Actions secret for " + args.account)
        prepare_contributors(args.archive, args.account)
        metadata = validate(args.archive, args.account, args.tag)
        print(f"Validated {metadata['name']} {metadata['version']} for {args.account}")
        if args.submit:
            submit(args.archive, metadata, args.account, os.environ["HAXELIB_PASSWORD"])
    except (ValueError, KeyError, OSError, subprocess.TimeoutExpired) as error:
        # TimeoutExpired holds the submission command. Don't print it.
        message = "Haxelib command timed out" if isinstance(error, subprocess.TimeoutExpired) else str(error)
        parser.exit(1, f"Error: {message}\n")


if __name__ == "__main__":
    main()
