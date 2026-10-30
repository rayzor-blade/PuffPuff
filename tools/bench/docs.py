#!/usr/bin/env python3
"""Fills the generated blocks of docs/benchmarks/*.md from the recorded baseline.

    docs.py [<baseline.json>] [<openfl.json>]

A page marks a block with
    <!-- bench-table prefixes="text.,gpu.frame.text." -->  ...  <!-- /bench-table -->
for a table of the baseline cases whose names start with one of the prefixes,
    <!-- bench-meta -->  ...  <!-- /bench-meta -->
for the line naming the build the baseline was recorded from, and
    <!-- openfl-comparison -->  ...  <!-- /openfl-comparison -->
for the table compare_openfl.py prints. The rest of a page is written by hand. tools/bench/run.sh --baseline runs this.
"""
import json, os, platform, re, sys

sys.dont_write_bytecode = True

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare_openfl

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
docs = os.path.join(root, "docs", "benchmarks")
machine = f"{platform.system()}-{platform.machine()}"
baseline_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "tools", "bench", "baselines", f"{machine}-llvm.json")
openfl_path = sys.argv[2] if len(sys.argv) > 2 else compare_openfl.default_of
doc = json.load(open(baseline_path))
cases = doc["results"]
meta = doc["meta"]


def time(ns):
    if ns >= 1e6:
        return f"{ns / 1e6:.2f} ms"
    if ns >= 1e3:
        return f"{ns / 1e3:.1f} us"
    return f"{ns:.1f} ns"


def size(b):
    if b >= 1e6:
        return f"{b / 1e6:.1f} MB"
    if b >= 1e3:
        return f"{b / 1e3:.0f} KB"
    return f"{b:.0f} B"


def table(prefixes):
    rows = ["| Case | Operations per run | Median per operation | Allocation per operation |", "|---|---:|---:|---:|"]
    for r in cases:
        if any(r["name"].startswith(p) for p in prefixes):
            rows.append(f"| `{r['name']}` | {r.get('ops', 1)} | {time(r['medianNs'])} | {size(r.get('allocBytesPerOp', 0))} |")
    return "\n".join(rows)


def meta_line():
    return f"PuffPuff `{meta['commit']}` on {meta['ash']}, {meta['mode']} tier, {meta['cpu']}."


def fill(text):
    text = re.sub(r'(<!-- bench-table prefixes="([^"]*)" -->\n)(.*?)(<!-- /bench-table -->)',
                  lambda m: m.group(1) + table(m.group(2).split(",")) + "\n" + m.group(4), text, flags=re.S)
    text = re.sub(r"(<!-- bench-meta -->\n)(.*?)(<!-- /bench-meta -->)", lambda m: m.group(1) + meta_line() + "\n" + m.group(3), text, flags=re.S)
    if "<!-- openfl-comparison -->" in text:
        if os.path.exists(openfl_path):
            text = re.sub(r"(<!-- openfl-comparison -->\n)(.*?)(<!-- /openfl-comparison -->)",
                          lambda m: m.group(1) + compare_openfl.render(baseline_path, openfl_path) + "\n" + m.group(3), text, flags=re.S)
        else:
            print(f"no OpenFL results at {openfl_path}; run tools/bench/openfl/run.sh to refresh the comparison", file=sys.stderr)
    return text


for name in sorted(os.listdir(docs)):
    if name.endswith(".md"):
        path = os.path.join(docs, name)
        old = open(path).read()
        new = fill(old)
        if new != old:
            open(path, "w").write(new)
            print(f"updated docs/benchmarks/{name}")
