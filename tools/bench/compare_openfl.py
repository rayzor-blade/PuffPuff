#!/usr/bin/env python3
"""Prints the PuffPuff-versus-OpenFL text comparison as a Markdown table.

    compare_openfl.py [<puffpuff.json>] [<openfl.json>]

Defaults: tools/bench/baselines/<machine>-llvm.json (from tools/bench/run.sh --baseline) and
.puffpuff/bench/openfl/<machine>.json (from tools/bench/openfl/run.sh). Medians on both sides.
docs.py uses `render` to fill docs/benchmarks/text.md.
"""
import json, os, platform, sys

sys.dont_write_bytecode = True

machine = f"{platform.system()}-{platform.machine()}"
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
default_pp = os.path.join(root, "tools", "bench", "baselines", f"{machine}-llvm.json")
default_of = os.path.join(root, ".puffpuff", "bench", "openfl", f"{machine}.json")


def render(pp_path=default_pp, of_path=default_of):
    """The comparison as Markdown: a line naming the versions, a blank line, the table."""
    pp_doc = json.load(open(pp_path))
    pp, pp_meta = {r["name"]: r for r in pp_doc["results"]}, pp_doc["meta"]
    of_doc = json.load(open(of_path))
    of, of_meta = of_doc["results"], of_doc["meta"]

    def ms(name):
        return pp[name]["medianNs"] / 1e6

    reference = "whole lines, for reference"
    rows = [
        ("New 133-character paragraph: layout (OpenFL, with wrapping) or shaping one line (PuffPuff)", of["layout.paragraph.us"]["median"] / 1000,
         [("", ms("text.shape.paragraph")), (reference, ms("text.shape.paragraph.whole"))]),
        ("200 labels, static, per frame, PuffPuff submitted", of["frame.static.ms"]["median"], [("", ms("gpu.frame.text.static.submit"))]),
        ("200 labels, static, per frame, PuffPuff finished and read back", of["frame.static.ms"]["median"],
         [("", ms("gpu.frame.text.static.readback"))]),
        ("200 labels, text set every frame, PuffPuff submitted", of["frame.dynamic.ms"]["median"],
         [("", ms("gpu.frame.text.dynamic.submit")), (reference, ms("gpu.frame.text.dynamic.whole.submit"))]),
        ("200 labels, text set every frame, PuffPuff finished and read back", of["frame.dynamic.ms"]["median"],
         [("", ms("gpu.frame.text.dynamic.readback")), (reference, ms("gpu.frame.text.dynamic.whole.readback"))]),
    ]
    if "openfl.textfield.layout.paragraph" in pp:
        rows.insert(0, ("TextField layout of a new wrapped paragraph (OpenFL's own code on each backend)", of["layout.paragraph.us"]["median"] / 1000,
                        [("", ms("openfl.textfield.layout.paragraph"))]))
    out = [f"OpenFL {of_meta['openfl']} on Lime {of_meta['lime']}, hxcpp {of_meta['hxcpp']} release, {of_meta['runs']} runs ({of_meta['date']}); "
           f"PuffPuff {pp_meta['commit']} on {pp_meta['ash']} ({pp_meta['mode']} tier); {pp_meta['cpu']}.", "",
           "| Measurement | OpenFL (ms) | PuffPuff (ms) | PuffPuff is |", "|---|---:|---:|---:|"]
    for label, a, variants in rows:
        for name, b in variants:
            out.append(f"| {label}{' (' + name + ')' if name else ''} | {a:.3f} | {b:.3f} | {a / b:.1f}x faster |")
    layout = pp.get("openfl.textfield.layout.paragraph", {}).get("checksum", "").split(":")
    if len(layout) == 3 and "check.paragraph.lines" in of:
        out += ["", "The layout both sides computed for that paragraph (the same text, width 300 and 14 px `_sans`):", "",
                "| | Lines | Text width (px) | Text height (px) |", "|---|---:|---:|---:|",
                f"| OpenFL | {of['check.paragraph.lines']['median']:.0f} | {of['check.paragraph.textWidth']['median']:.2f} | {of['check.paragraph.textHeight']['median']:.0f} |",
                f"| PuffPuff | {layout[0]} | {float(layout[1]):.2f} | {layout[2]} |"]
    return "\n".join(out)


if __name__ == "__main__":
    print(render(*(sys.argv[1:3])))
