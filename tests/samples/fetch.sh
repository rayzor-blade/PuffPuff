#!/bin/sh
# Clones the sample repositories listed in sources.txt, at the commits pinned there, into tests/samples/.cache.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$here/.cache"
while read -r name url sha; do
	[ -n "$name" ] || continue
	dir="$here/.cache/$name"
	if [ ! -d "$dir/.git" ]; then
		git init -q "$dir"
		git -C "$dir" remote add origin "$url"
	fi
	if [ "$(git -C "$dir" rev-parse -q --verify HEAD 2>/dev/null)" != "$sha" ]; then
		git -C "$dir" fetch -q --depth 1 origin "$sha"
		git -C "$dir" checkout -q FETCH_HEAD
	fi
done < "$here/sources.txt"
