#!/usr/bin/env python3
"""Wraps the import lines a compile reports as 'Type not found' in `#if !openfl_wgpu` ... `#end`.

    compile_openfl.sh > errs.txt; tools/conformance/gate_imports.py errs.txt [types...]

Only import lines are touched; adjacent flagged lines share one gate. With type names given, only
errors naming one of them are gated. A first-wave helper for the OpenFL patch: review the diff.
"""
import re, sys, collections
errs = open(sys.argv[1]).read().splitlines()
only = set(sys.argv[2:])
by_file = collections.defaultdict(set)
for e in errs:
    m = re.match(r"(.+\.hx):(\d+): characters [\d-]+ : Type not found : (\S+)", e)
    if m and (not only or m.group(3) in only):
        by_file[m.group(1)].add(int(m.group(2)))
for path, lines in by_file.items():
    src = open(path).read().split("\n")
    lines = sorted(l for l in lines if src[l - 1].lstrip().startswith("import "))
    groups, cur = [], []
    for l in lines:
        if cur and l == cur[-1] + 1: cur.append(l)
        else:
            if cur: groups.append(cur)
            cur = [l]
    if cur: groups.append(cur)
    for g in reversed(groups):
        src.insert(g[-1], "#end")
        src.insert(g[0] - 1, "#if !openfl_wgpu")
    open(path, "w").write("\n".join(src))
    print(path.split("/src/")[-1], sum(len(g) for g in groups))
