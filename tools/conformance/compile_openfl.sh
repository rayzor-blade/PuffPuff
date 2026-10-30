#!/bin/sh
# Type-checks OpenFL (a checkout with the openfl_wgpu gate) against PuffPuff's Lime layer, no output.
#
#   tools/conformance/compile_openfl.sh [openfl checkout] [package ...]
#
# Compiles OpenFLSmoke (what a program reaches) by default; with package names it includes those
# packages whole instead. Haxe stops at the first error, so fix and rerun.
set -e
repo="$(cd "$(dirname "$0")/../.." && pwd)"
openfl="${1:-$repo/../openfl}"
[ $# -gt 0 ] && shift
includes="-cp tools/conformance -main OpenFLSmoke"
if [ $# -gt 0 ]; then
	includes=""
	for p in "$@"; do includes="$includes --macro include('$p')"; done
fi
cd "$repo"
haxe build.hxml -cp "$openfl/src" -D openfl=9.5.2 -D openfl_wgpu -hl "${TMPDIR:-/tmp}/openfl-check.hl" --no-output $includes 2>&1 | grep -v "Warning\|WARNING" | head -${LINES_MAX:-20}
