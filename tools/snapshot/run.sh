#!/bin/sh
# Renders a PuffPuff scene offscreen to a PNG with puffpuff.snapshot.Snapshot, on Ash.
# The PNG lands in .puffpuff/snapshots (or $PUFFPUFF_SNAPSHOT_DIR) and each render
# or failure appends a line to events.log there, for a watcher to tail:
#
#   tools/snapshot/run.sh tools/snapshot/scenes/ClearGradient.hx         render once
#   tools/snapshot/run.sh --watch tools/snapshot/scenes/ClearGradient.hx render again on changes
#   tools/snapshot/run.sh --window tools/snapshot/scenes/ClearGradient.hx open in a live window
#   PUFFPUFF_HAXE_FLAGS=...                                              extra Haxe compiler flags
#   ASH=path tools/snapshot/run.sh ...                                   custom ash binary path
set -e
watch=0
window=0
while :; do
	case "$1" in
	--watch) watch=1; shift ;;
	--window) window=1; shift ;;
	*) break ;;
	esac
done
[ -n "$1" ] || { echo "usage: run.sh [--watch] [--window] Scene.hx" >&2; exit 2; }
scene="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
name="$(basename "$scene" .hx)"

cd "$(dirname "$0")"
repo="$(cd ../.. && pwd)"
vib="$(cd "$repo/.." && pwd)"

if [ -n "${ASH:-}" ]; then
	ash="$ASH"
elif [ -x "$HOME/.ash/bin/ash" ]; then
	ash="$HOME/.ash/bin/ash"
elif [ -x "$vib/ash/target/release/ash" ]; then
	ash="$vib/ash/target/release/ash"
else
	ash="ash"
fi

PUFFPUFF_SNAPSHOT_DIR="${PUFFPUFF_SNAPSHOT_DIR:-$repo/.puffpuff/snapshots}"
export PUFFPUFF_SNAPSHOT_DIR
mkdir -p "$PUFFPUFF_SNAPSHOT_DIR" bin
events="$PUFFPUFF_SNAPSHOT_DIR/events.log"
touch "$events"

render() {
	if ! out=$(cd "$repo" && haxe build.hxml -cp "$(dirname "$scene")" ${PUFFPUFF_HAXE_FLAGS:-} -main "$name" -hl "$repo/tools/snapshot/bin/$name.hl" 2>&1); then
		echo "error $name does not compile: $(echo "$out" | grep -v Warning | head -1)" >> "$events"
		echo "$out" >&2
		return 1
	fi
	if [ $window -eq 1 ]; then
		(cd bin && PUFFPUFF_WINDOW=1 "$ash" "$PWD/$name.hl")
		return
	fi
	(cd bin && perl -e 'alarm 120; exec @ARGV' "$ash" "$PWD/$name.hl") ||
		{ status=$?; grep -q "^error $name " "$events" 2>/dev/null || echo "error $name exited with status $status" >> "$events"; return 1; }
}

if [ $watch -eq 0 ]; then
	render
	exit
fi

stamp="bin/.$name.stamp"
touch "$stamp"
render || true
echo "watching $scene; Ctrl-C stops" >&2
while sleep 0.5; do
	if [ -n "$(find "$scene" "$repo/src" -newer "$stamp" -name '*.hx' 2>/dev/null | head -1)" ]; then
		touch "$stamp"
		render || true
	fi
done
