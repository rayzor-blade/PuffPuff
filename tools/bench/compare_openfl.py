#!/usr/bin/env python3
"""Prints the PuffPuff-versus-OpenFL text comparison as a Markdown table.

    compare_openfl.py [<puffpuff.json>] [<openfl.json>]

Defaults: tools/bench/baselines/<machine>-llvm.json (from tools/bench/run.sh --baseline) and
.puffpuff/bench/openfl/<machine>.json (from tools/bench/openfl/run.sh). Medians on both sides.
"""
import json, os, platform, sys

machine = f"{platform.system()}-{platform.machine()}"
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
pp_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "tools", "bench", "baselines", f"{machine}-llvm.json")
of_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, ".puffpuff", "bench", "openfl", f"{machine}.json")
pp = {r["name"]: r for r in json.load(open(pp_path))["results"]}
pp_meta = json.load(open(pp_path))["meta"]
of_doc = json.load(open(of_path))
of, of_meta = of_doc["results"], of_doc["meta"]


def ms(name):
    return pp[name]["medianNs"] / 1e6


rows = [
    ("New 133-character paragraph: layout (OpenFL, with wrapping) or shaping one line (PuffPuff)",
     of["layout.paragraph.us"]["median"] / 1000, [("composed", ms("text.shape.paragraph")), ("native engine", ms("text.shape.paragraph.native"))]),
    ("200 labels, static, per frame, PuffPuff submitted", of["frame.static.ms"]["median"], [("", ms("gpu.frame.text.static.submit"))]),
    ("200 labels, static, per frame, PuffPuff finished and read back", of["frame.static.ms"]["median"], [("", ms("gpu.frame.text.static.readback"))]),
    ("200 labels, text set every frame, PuffPuff submitted", of["frame.dynamic.ms"]["median"],
     [("composed", ms("gpu.frame.text.dynamic.submit")), ("native engine", ms("gpu.frame.text.dynamic.native.submit"))]),
    ("200 labels, text set every frame, PuffPuff finished and read back", of["frame.dynamic.ms"]["median"],
     [("composed", ms("gpu.frame.text.dynamic.readback")), ("native engine", ms("gpu.frame.text.dynamic.native.readback"))]),
]
print(f"OpenFL {of_meta['openfl']} on Lime {of_meta['lime']}, hxcpp {of_meta['hxcpp']} release, {of_meta['runs']} runs ({of_meta['date']}); "
      f"PuffPuff {pp_meta['commit']} on {pp_meta['ash']} ({pp_meta['mode']} tier); {pp_meta['cpu']}.\n")
print("| Measurement | OpenFL (ms) | PuffPuff (ms) | PuffPuff is |")
print("|---|---:|---:|---:|")
for label, a, variants in rows:
    for name, b in variants:
        print(f"| {label}{' (' + name + ')' if name else ''} | {a:.3f} | {b:.3f} | {a / b:.1f}x faster |")
