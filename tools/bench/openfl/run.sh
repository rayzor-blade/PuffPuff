#!/bin/sh
# Builds OpenFL's native text benchmark (hxcpp, release) and runs it, for comparison with tools/bench's text cases.
#
#   tools/bench/openfl/run.sh
#   LIME_VERSION=8.3.2 OPENFL_VERSION=9.5.2 HXCPP_VERSION=4.3.2 RUNS=5 tools/bench/openfl/run.sh
#
# Lime, OpenFL and hxcpp go into a haxelib repository under .puffpuff/bench/openfl, not the global one.
# Writes the result, the median of RUNS runs per measurement, to .puffpuff/bench/openfl/<machine>.json.
# It opens a window: OpenFL's renderer needs a GL context. Needs macOS with Xcode.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
lime="${LIME_VERSION:-8.3.2}"
openfl="${OPENFL_VERSION:-9.5.2}"
hxcpp="${HXCPP_VERSION:-4.3.2}"
runs="${RUNS:-5}"
work="$repo/.puffpuff/bench/openfl"
machine="$(uname -s)-$(uname -m)"

mkdir -p "$work/app"
cp -R "$here/project.xml" "$here/src" "$work/app/"
cd "$work"
[ -d .haxelib ] || haxelib newrepo >/dev/null
have() { haxelib list 2>/dev/null | grep -q "^$1: \[$2\]"; }
have lime "$lime" || haxelib install lime "$lime" --always >/dev/null
have openfl "$openfl" || haxelib install openfl "$openfl" --always >/dev/null
have hxcpp "$hxcpp" || haxelib install hxcpp "$hxcpp" --always >/dev/null

# hxcpp asks Xcode for the SDK by major version, but Xcode names it with the minor version too.
sdk="$(xcrun --sdk macosx --show-sdk-version)"
haxelib run lime build app/project.xml mac -release -DMACOSX_VER="$sdk" >"$work/build.log" 2>&1 || { tail -30 "$work/build.log"; exit 1; }

bin="$work/app/Export/macos/bin/TextBench.app/Contents/MacOS/TextBench"
: >"$work/runs.txt"
i=0
while [ $i -lt "$runs" ]; do
	"$bin" 2>/dev/null | grep -E '^(layout|frame|check)\.' >>"$work/runs.txt"
	i=$((i + 1))
done

LIME="$lime" OPENFL="$openfl" HXCPP="$hxcpp" SDK="$sdk" python3 -I - "$work/runs.txt" "$work/$machine.json" <<'PY'
import json, os, statistics, subprocess, sys, datetime
runs = {}
for line in open(sys.argv[1]):
    k, v = line.split()
    runs.setdefault(k, []).append(float(v))
cpu = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"], capture_output=True, text=True).stdout.strip()
out = {
    "meta": {"lime": os.environ["LIME"], "openfl": os.environ["OPENFL"], "hxcpp": os.environ["HXCPP"], "sdk": os.environ["SDK"],
             "cpu": cpu, "date": datetime.date.today().isoformat(), "runs": len(next(iter(runs.values())))},
    "results": {k: {"median": statistics.median(v), "min": min(v), "max": max(v)} for k, v in runs.items()},
}
json.dump(out, open(sys.argv[2], "w"), indent=2)
for k, v in out["results"].items():
    print(f"{k:24s} median {v['median']:10.2f}   min {v['min']:10.2f}   max {v['max']:10.2f}")
PY
