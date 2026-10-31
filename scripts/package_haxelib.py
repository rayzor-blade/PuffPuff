#!/usr/bin/env python3
"""Package puffpuff as a Haxelib archive."""

import argparse
import hashlib
import json
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parent.parent
SEMVER = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-(alpha|beta|rc)(\.(0|[1-9]\d*))?)?")
README_IMAGE_BASE = "https://raw.githubusercontent.com/rayzor-blade/PuffPuff/main/"
README_LINK_BASE = "https://github.com/rayzor-blade/PuffPuff/blob/main/"
# README embeds. Served raw so Haxelib's page can show them.
EMBEDDED = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".mp4", ".webm", ".mov")
# Targets that already resolve: a scheme (https:, mailto:), a protocol-relative URL, or a fragment.
ABSOLUTE = re.compile(r"(?i)^(?:[a-z][a-z0-9+.-]*:|//|#)")
# Where a README names a file: Markdown links and images, reference definitions, and HTML src, href and poster.
REFERENCES = (
    re.compile(r"(\]\()(<?)([^)\s>]+)(>?(?:\s+\"[^\"]*\")?\))"),
    re.compile(r"(?m)(^[ \t]{0,3}\[[^\]\n]+\]:[ \t]*<?)([^\s>]+)(>?)"),
    re.compile(r"(?i)(\b(?:src|href|poster)\s*=\s*[\"'])([^\"']+)([\"'])"),
)
# Fenced code blocks and inline code spans. Left as written, since their text is code, not links.
CODE = re.compile(r"(?ms)^(```|~~~).*?^\1[^\n]*$|`[^`\n]+`")


def outside_code(text: str, change) -> str:
    """Applies `change` to `text`, except code blocks and spans."""
    out, at = [], 0
    for code in CODE.finditer(text):
        out.append(change(text[at:code.start()]))
        out.append(code.group(0))
        at = code.end()
    out.append(change(text[at:]))
    return "".join(out)


def relative_references(text: str) -> list[str]:
    """Relative paths a README names outside code. Haxelib's page can't resolve them."""
    found = []

    def collect(part: str) -> str:
        for pattern in REFERENCES:
            for match in pattern.finditer(part):
                target = match.group(match.lastindex - 1)
                if not ABSOLUTE.match(target):
                    found.append(target)
        return part

    outside_code(text, collect)
    return found


def rewrite_links(text: str, base: Path) -> str:
    """
    Points every relative link and embed in `text` (a README in `base`) at the repository's main branch.
    Images and video are served raw so they display, and other files link to their GitHub page. Each target
    must be a file or folder in the repository, and fragments are kept. Raises if a target is missing or
    anything relative is left.
    """
    def published(target: str) -> str:
        path, mark, fragment = target.partition("#")
        source = (base / path).resolve()
        if not source.exists():
            raise ValueError(f"README links to a missing file: {source}")
        relative = source.relative_to(ROOT).as_posix()
        if source.suffix.lower() in EMBEDDED:
            return README_IMAGE_BASE + relative + mark + fragment
        page = README_LINK_BASE if source.is_file() else README_LINK_BASE.replace("/blob/", "/tree/")
        return page + relative + mark + fragment

    def change(part: str) -> str:
        for pattern in REFERENCES:
            def replace(match: re.Match) -> str:
                target = match.group(match.lastindex - 1)
                if ABSOLUTE.match(target):
                    return match.group(0)
                groups = list(match.groups())
                groups[match.lastindex - 2] = published(target)
                return "".join(groups)
            part = pattern.sub(replace, part)
        return part

    rewritten = outside_code(text, change)
    left = relative_references(rewritten)
    if left:
        raise ValueError("README links still relative after rewriting: " + ", ".join(left))
    return rewritten


def release_readme(readme: Path) -> str:
    """Repository previews keep local links. On Haxelib, every link and embed points at the repository."""
    return rewrite_links(readme.read_text(), readme.parent)


def version_of(tag: str) -> str:
    """Turns a tag like v2026.10.07 into Haxelib's 2026.10.7."""
    core, _, preview = tag.removeprefix("v").partition("-")
    if not re.fullmatch(r"\d+\.\d+\.\d+", core):
        raise ValueError(f"{tag} is not a Haxelib version")
    version = ".".join(str(int(part)) for part in core.split("."))
    if preview:
        version += "-" + preview
    if not SEMVER.fullmatch(version):
        raise ValueError(f"{tag} is not a Haxelib version")
    return version


def sha256_of(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native_libraries(assets: Path) -> dict[str, Path]:
    """The pinned blinc_abi libraries in `assets`, checked against the checksums in native/hdlls.json."""
    manifest = json.loads((ROOT / "native/hdlls.json").read_text())
    if not manifest["source"]["tag"]:
        raise ValueError("native/hdlls.json has no release tag: run scripts/pin_native.py")
    found = {}
    for platform, entry in manifest["platforms"].items():
        path = assets / entry["releaseAsset"]
        if not path.is_file():
            raise ValueError(f"missing native library {path}")
        if sha256_of(path) != entry["sha256"]:
            raise ValueError(f"{entry['releaseAsset']} does not match its checksum in native/hdlls.json")
        found[entry["packagePath"]] = path
    return found


def package(output_dir: Path, version: str | None = None, assets: Path | None = None) -> Path:
    lib = json.loads((ROOT / "haxelib.json").read_text())
    if version:
        lib["version"] = version
    natives = native_libraries(assets) if assets else {}
    output_dir.mkdir(parents=True, exist_ok=True)
    output = output_dir / f"{lib['name']}.zip"
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        archive.writestr("haxelib.json", json.dumps(lib, indent=2) + "\n")
        archive.write(ROOT / "LICENSE", "LICENSE")
        archive.writestr("README.md", release_readme(ROOT / "README.md"))
        archive.write(ROOT / "extraParams.hxml", "extraParams.hxml")
        archive.write(ROOT / "native/hdlls.json", "native/hdlls.json")
        for package_path, path in natives.items():
            archive.write(path, package_path)
        for directory in (lib["classPath"], "fonts"):
            for source in sorted((ROOT / directory).rglob("*")):
                if source.is_file() and source.name != ".DS_Store":
                    archive.write(source, source.relative_to(ROOT))
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="directory to write puffpuff.zip into")
    parser.add_argument("--version", help="release tag to stamp into the package")
    parser.add_argument("--assets", type=Path, help="directory holding the native/hdlls.json release assets")
    parser.add_argument("--without-native", action="store_true", help="skip the native libraries; the package cannot be published")
    args = parser.parse_args()
    if not args.assets and not args.without_native:
        parser.error("pass --assets, or --without-native for a package that is not published")
    try:
        version = version_of(args.version) if args.version else None
        print(f"wrote {package(args.output, version, args.assets)}")
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
