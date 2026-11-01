#!/bin/sh
# Runs areas of OpenFL's own unit tests (utest) against PuffPuff on Ash.
#
#   tests/openfl/run.sh [area ...]    areas of ../openfl/tests; none means all of them
#   OPENFL=path                       OpenFL checkout with the openfl_wgpu gate (default ../openfl)
#   ASH=path                          ash binary
#   PUFFPUFF_HAXE_FLAGS=...           extra Haxe compiler flags
#
# Areas listed in `hosted` run inside tests/openfl/host/UnitHost.hx.
# Prints one line per area: assertions, failures and errors. Exits 1 if any area fails to build, crashes or fails.
set -e
repo="$(cd "$(dirname "$0")/../.." && pwd)"
openfl="${OPENFL:-$repo/../openfl}"
openfl="$(cd "$openfl" && pwd)"
ash="${ASH:-ash}"
out="$repo/.puffpuff/unit"
mkdir -p "$out"

areas="$*"
if [ -z "$areas" ]; then
	areas="$(cd "$openfl/tests" && for d in */; do if [ -f "${d}Tests.hx" ]; then printf '%s ' "${d%/}"; fi; done)"
fi

hosted="socket nativewindow application displayobject eventdispatcher stage"
failed=0
for area in $areas; do
	dir="$openfl/tests/$area"
	[ -f "$dir/Tests.hx" ] || { echo "$area: no Tests.hx"; failed=1; continue; }
	# These need a running application (frames, a stage, Lib.application); the rest run on their own.
	main="-main Tests"
	case " $hosted " in *" $area "*) main="-cp $repo/tests/openfl/host -main UnitHost" ;; esac
	# Each area's project.xml says whether it is an integration build.
	grep -q '^[[:space:]]*<define name="integration"' "$dir/project.xml" 2>/dev/null && main="$main -D integration"
	if ! log=$(cd "$repo" && haxe build.hxml -cp "$openfl/src" -cp "$dir" -cp "$dir/src" -lib utest \
		-D openfl=9.5.2 -D openfl_wgpu -D openfl-unit-testing ${PUFFPUFF_HAXE_FLAGS:-} \
		$main -hl "$out/$area.hl" 2>&1); then
		echo "$area: does not compile: $(echo "$log" | grep -v Warning | head -1)"
		failed=1
		continue
	fi
	# Assets sit beside the executable as project.xml places them: renamed to ".", or in an assets folder.
	rm -rf "$out/assets" "$out/openfl-base64.txt" "$out/hello.rtf"
	if [ -d "$dir/assets" ]; then
		if grep -q '<assets path="assets" rename="\."' "$dir/project.xml" 2>/dev/null; then
			cp -R "$dir/assets/." "$out/"
		else
			cp -R "$dir/assets" "$out/assets"
		fi
	fi
	run=$(cd "$out" && perl -e 'alarm 180; exec @ARGV' "$ash" "$area.hl" 2>&1) && status=0 || status=$?
	summary=$(echo "$run" | awk '/^assertations:/{a=$2} /^successes:/{s=$2} /^errors:/{e=$2} /^failures:/{f=$2} END{if (a != "") printf "%s assertions, %s failures, %s errors", a, f, e}')
	if [ -z "$summary" ]; then
		echo "$area: no result (exit $status): $(echo "$run" | grep -v '^\[ash\]' | tail -1)"
		failed=1
		continue
	fi
	echo "$area: $summary"
	case "$summary" in *" 0 failures, 0 errors") ;; *) failed=1; echo "$run" | sed -n '/^results:/,$p' | tail -n +2 | sed 's/^/    /' ;; esac
done
exit $failed
