#!/bin/sh
# Builds OpenFL sample projects against PuffPuff and renders each one headless to a PNG in .puffpuff/snapshots.
# A sample passes when it builds, runs 40 frames without an exception and draws more than one color. A console sample
# (status console) draws nothing and only has to run.
#
#   tests/samples/run.sh [name ...]    names are the end of a path in samples.txt, such as TicTacToe or display/DrawingShapes.
#                                      Named samples always run. None means every sample with status run.
#   tests/samples/run.sh --list        print samples.txt
#   OPENFL=path                        OpenFL checkout with the openfl_wgpu gate (default ../openfl)
#   ASH=path                           ash binary
#   PUFFPUFF_HAXE_FLAGS=...            extra Haxe compiler flags
#
# Samples that use actuate or box2d need those haxelibs installed. Sources are cloned by fetch.sh at pinned commits.
# A sample written for GLSL or AGAL runs from a port: ports/<path>/<source> holds the files rewritten for HXSL.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
if [ "$1" = "--list" ]; then grep -v '^#' "$here/samples.txt"; exit; fi
openfl="$(cd "${OPENFL:-$repo/../openfl}" && pwd)"
ash="${ASH:-ash}"
out="$repo/.puffpuff/samples"
mkdir -p "$out"
"$here/fetch.sh"

wanted="$*"
if [ -z "$wanted" ]; then
	wanted=$(awk -F'\t' '!/^#/ && $1 == "openfl-samples" && ($3 == "run" || $3 == "console") {print $2}' "$here/samples.txt")
fi

failed=0
for want in $wanted; do
	path=$(awk -F'\t' -v w="$want" '!/^#/ && $1 == "openfl-samples" && ($2 == w || $2 ~ ("/" w "$")) {print $2}' "$here/samples.txt")
	status=$(awk -F'\t' -v p="$path" '!/^#/ && $1 == "openfl-samples" && $2 == p {print $3}' "$here/samples.txt")
	if [ -z "$path" ] || [ "$(echo "$path" | wc -l)" -ne 1 ]; then
		echo "$want: not exactly one openfl-samples entry"
		failed=1
		continue
	fi
	dir="$here/.cache/openfl-samples/$path"
	name=$(echo "$path" | tr '/' '-')

	# Main class, window size, source folder, assets and libraries, from the sample's project.xml.
	info=$(python3 -I - "$dir/project.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
r = ET.parse(sys.argv[1]).getroot()
app = r.find('app'); win = r.find('window'); src = r.find('source')
width = win.get('width') if win is not None and win.get('width') else '800'
height = win.get('height') if win is not None and win.get('height') else '600'
assets = ";".join(a.get('path') + ":" + (a.get('rename') or a.get('path')) for a in r.findall('assets'))
libs = ",".join(h.get('name') for h in r.findall('haxelib') if h.get('name') not in ('openfl', 'lime'))
print("\t".join([app.get('main'), width + "x" + height, src.get('path') if src is not None else 'Source', assets, libs]))
PY
)
	main=$(echo "$info" | cut -f1); size=$(echo "$info" | cut -f2); source=$(echo "$info" | cut -f3)
	assets=$(echo "$info" | cut -f4); libs=$(echo "$info" | cut -f5)

	libflags=""
	for lib in $(echo "$libs" | tr ',' ' '); do libflags="$libflags -lib $lib"; done
	assetflag=""
	[ "$status" = console ] && assetflag="-D sample_blank_ok"
	if [ -n "$assets" ]; then
		abs=""
		for entry in $(echo "$assets" | tr ';' ' '); do abs="$abs;$dir/${entry%%:*}:${entry#*:}"; done
		assetflag="$assetflag -D sample_assets=${abs#;}"
	fi

	# A port (HXSL in place of GLSL or AGAL) has its changed sources in ports/<path>/<source>, which win over the sample's own.
	portflag=""
	[ -d "$here/ports/$path/$source" ] && portflag="-cp $here/ports/$path/$source"

	if ! log=$(cd "$repo" && haxe build.hxml -cp "$openfl/src" -cp "$dir/$source" $portflag -cp "$here/host" $libflags \
		-D openfl=9.5.2 -D openfl_wgpu -D "sample_main=$main" -D "sample_name=$name" -D "sample_size=$size" $assetflag ${PUFFPUFF_HAXE_FLAGS:-} \
		-main SampleHost -hl "$out/$name.hl" 2>&1); then
		echo "$path: does not build: $(echo "$log" | grep -v Warning | head -1)"
		failed=1
		continue
	fi
	if res=$(cd "$out" && PUFFPUFF_SNAPSHOT_DIR="${PUFFPUFF_SNAPSHOT_DIR:-$repo/.puffpuff/snapshots}" perl -e 'alarm 120; exec @ARGV' "$ash" "$name.hl" 2>&1) \
		&& echo "$res" | grep -q "^sample $name ok"; then
		echo "$path: ok"
	else
		reason=$(echo "$res" | grep -v '^\[ash\]' | grep -iE 'exception|error|flat color' | head -1)
		echo "$path: ${reason:-no result: $(echo "$res" | grep -v '^\[ash\]' | tail -1)}"
		failed=1
	fi
done
exit $failed
