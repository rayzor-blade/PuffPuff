#!/usr/bin/env python3
"""Merges and compares benchmark results.

    report.py merge <time.json> <alloc.json> -o <out.json>
    report.py compare <baseline.json> <current.json> [--tolerance 0.30] [--accept-checksums]

compare exits 1 when a case fails, runs slower than the baseline by more than the tolerance (best-of-N
nanoseconds), allocates noticeably more, or produces different output (checksum) without --accept-checksums.
"""
import argparse, json, sys


def load(path):
    with open(path) as f:
        return json.load(f)


def merge(args):
    t, a = load(args.time), load(args.alloc)
    by_name = {r["name"]: r for r in a["results"]}
    results = []
    for r in t["results"]:
        m = dict(r)
        extra = by_name.get(r["name"], {})
        for k in ("allocBytesPerOp", "leakBytes"):
            if k in extra:
                m[k] = extra[k]
        if extra.get("error") and extra["error"] != m.get("error"):
            m["error"] = (m["error"] + "; " if m.get("error") else "") + extra["error"]
        results.append(m)
    meta = dict(t["meta"])
    meta["pass"] = "merged"
    with open(args.out, "w") as f:
        json.dump({"meta": meta, "results": results}, f, indent=1)
    print(f"merged {len(results)} cases -> {args.out}")


def check(args):
    bad = [r["name"] + ": " + r["error"] for r in load(args.file)["results"] if r.get("error")]
    for line in bad:
        print("FAIL", line)
    return 1 if bad else 0


def pct(cur, base):
    return (cur - base) / base * 100.0 if base else 0.0


def compare(args):
    base, cur = load(args.baseline), load(args.current)
    bm, cm = base["meta"], cur["meta"]
    print(f"baseline: {bm.get('commit')} on {bm.get('cpu')} ({bm.get('ash')})")
    print(f"current : {cm.get('commit')} on {cm.get('cpu')} ({cm.get('ash')})")
    if bm.get("machine") != cm.get("machine") or bm.get("cpu") != cm.get("cpu"):
        print("WARNING: baseline was recorded on a different machine; the comparison is not meaningful")
    base_by = {r["name"]: r for r in base["results"]}
    bad = 0
    print(f"{'case':38}{'base ns':>11}{'now ns':>11}{'change':>9}{'base B/op':>11}{'now B/op':>10}  status")
    for r in cur["results"]:
        b = base_by.get(r["name"])
        flags = []
        if r.get("error"):
            flags.append("FAIL: " + r["error"])
        if b is None:
            flags.append("new")
        else:
            if r.get("minNs") and b.get("minNs"):
                ch = pct(r["minNs"], b["minNs"])
                if ch > args.tolerance * 100:
                    flags.append("SLOWER")
                elif ch < -args.tolerance * 100:
                    flags.append("faster")
            if (r.get("leakBytes") or 0) > 1048576:
                flags.append("LEAK")
            ba, ca = b.get("allocBytesPerOp"), r.get("allocBytesPerOp")
            if ba is not None and ca is not None and ca > ba + max(8.0, ba * 0.10):
                flags.append("MORE ALLOCATION")
            if b.get("checksum") and r.get("checksum") and b["checksum"] != r["checksum"] and not args.accept_checksums:
                flags.append("OUTPUT CHANGED")
        if any(f.isupper() or f.startswith("FAIL") for f in flags if f not in ("faster", "new")):
            bad += 1
        bn, cn = (b or {}).get("minNs"), r.get("minNs")
        ch = f"{pct(cn, bn):+.0f}%" if bn and cn else "-"
        fmt = lambda v: "-" if v is None else f"{v:.1f}"
        print(f"{r['name']:38}{fmt(bn):>11}{fmt(cn):>11}{ch:>9}{fmt((b or {}).get('allocBytesPerOp')):>11}{fmt(r.get('allocBytesPerOp')):>10}  {', '.join(flags) or 'ok'}")
    missing = [n for n in base_by if n not in {r['name'] for r in cur['results']}]
    if missing:
        print("not run this time:", ", ".join(missing))
    print("RESULT:", "regressions or failures found" if bad else "no regressions")
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("merge")
    m.add_argument("time")
    m.add_argument("alloc")
    m.add_argument("-o", "--out", required=True)
    k = sub.add_parser("check")
    k.add_argument("file")
    c = sub.add_parser("compare")
    c.add_argument("baseline")
    c.add_argument("current")
    c.add_argument("--tolerance", type=float, default=0.30)
    c.add_argument("--accept-checksums", action="store_true")
    args = ap.parse_args()
    if args.cmd == "merge":
        merge(args)
        return 0
    if args.cmd == "check":
        return check(args)
    return compare(args)


if __name__ == "__main__":
    sys.exit(main())
