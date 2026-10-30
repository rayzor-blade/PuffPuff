#!/bin/sh
# Runs the benchmark suite on Ash and compares it with the stored baseline.
#
#   tools/bench/run.sh [options] [case-name-prefix]
#
#   --mode hybrid|llvm|both   Ash tier: both (default), hybrid (what plain `ash file.hl` does) or llvm (--mode jit --jit-tier llvm)
#   --baseline                store this run as the baseline for this machine and mode
#   --accept-checksums        do not fail on changed output checksums
#   --tolerance 0.30          allowed slowdown (fraction) before a case counts as a regression
#
# Each mode runs a timing pass, then an allocation pass with ASH_GC_TLAB=0 (exact allocated bytes).
# Results go to .puffpuff/bench/<machine>-<mode>.json; baselines live in tools/bench/baselines/.
# Storing an llvm baseline also regenerates the tables in docs/benchmarks (tools/bench/docs.py).
# Baselines are per machine and per mode: compare numbers only against the same machine.
# ASH=path picks the ash binary. BENCH_ALLOC_RUNS=n fixes the number of runs in the allocation pass; BENCH_DUMP=dir writes rendered frames; set before calling.
set -e
modes=both
baseline=0
extra=""
tol=0.30
while :; do
	case "$1" in
	--mode) modes="$2"; shift 2 ;;
	--baseline) baseline=1; shift ;;
	--accept-checksums) extra="$extra --accept-checksums"; shift ;;
	--tolerance) tol="$2"; shift 2 ;;
	-*) echo "unknown option $1" >&2; exit 2 ;;
	*) break ;;
	esac
done
prefix="${1:-}"
[ "$modes" = both ] && modes="llvm hybrid"

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
bin="$repo/tools/snapshot/bin"
out="$repo/.puffpuff/bench"
mkdir -p "$out" "$bin" "$here/baselines"

if [ -n "${ASH:-}" ]; then ash="$ASH"; elif [ -x "$HOME/.ash/bin/ash" ]; then ash="$HOME/.ash/bin/ash"; elif [ -x "$repo/../ash/target/release/ash" ]; then ash="$repo/../ash/target/release/ash"; else ash=ash; fi

cd "$repo"
haxe build.hxml -cp tools/bench -main Suite -hl "$bin/Suite.hl" 2>&1 | grep -v "Warning" || true

export BENCH_MACHINE="$(uname -s)-$(uname -m)"
export BENCH_COMMIT="$(git rev-parse --short HEAD)$(git diff --quiet HEAD -- src tools/bench 2>/dev/null || echo -dirty)"
export BENCH_ASH="$("$ash" --version 2>&1 | head -1)"
export BENCH_CPU="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -p)"

status=0
for mode in $modes; do
	export BENCH_MODE="$mode"
	flags=""
	[ "$mode" = llvm ] && flags="--mode jit --jit-tier llvm"
	id="$BENCH_MACHINE-$mode"
	echo "== $id: timing pass"
	(cd "$bin" && $ash $flags Suite.hl time "$out/$id.time.json" $prefix) || status=1
	echo "== $id: allocation pass"
	(cd "$bin" && ASH_GC_TLAB=0 $ash $flags Suite.hl alloc "$out/$id.alloc.json" $prefix) || status=1
	python3 -I "$here/report.py" merge "$out/$id.time.json" "$out/$id.alloc.json" -o "$out/$id.json"
	if [ $baseline -eq 1 ]; then
		if python3 -I "$here/report.py" check "$out/$id.json"; then
			cp "$out/$id.json" "$here/baselines/$id.json"
			echo "baseline stored: tools/bench/baselines/$id.json"
			[ "$mode" = llvm ] && python3 -I "$here/docs.py"
		else
			echo "not storing a baseline from a run with failing cases" >&2
			status=1
		fi
	elif [ -f "$here/baselines/$id.json" ]; then
		python3 -I "$here/report.py" compare "$here/baselines/$id.json" "$out/$id.json" --tolerance "$tol" $extra || status=1
	else
		echo "no baseline for $id yet; run with --baseline to store one"
	fi
done
exit $status
