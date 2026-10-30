#!/usr/bin/env python3
"""Drops `#if !openfl_wgpu` from import lines whose lime type the layer now provides.

    tools/conformance/ungate_imports.py [openfl checkout]

Companion to gate_imports.py: gate what is missing, implement it, then ungate it.
"""
import os, re, subprocess, sys
repo = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
openfl = sys.argv[1] if len(sys.argv) > 1 else os.path.join(repo, "..", "openfl")
src = os.path.join(repo, "src") + "/"
files = subprocess.run(["git", "-C", openfl, "diff", "--name-only"], capture_output=True, text=True).stdout.split()
count = 0

def provided(line):
    m = re.match(r"import (lime\.[\w.]+)(?: as \w+)?;", line.strip())
    return bool(m) and os.path.exists(src + m.group(1).replace(".", "/") + ".hx")

def fix(m):
    global count
    body = m.group(1).strip("\n").split("\n")
    keep = [l for l in body if not provided(l)]
    count += len(body) - len(keep)
    out = [l for l in body if provided(l)]
    if keep:
        out += ["#if !openfl_wgpu"] + keep + ["#end"]
    return "\n".join(out) + "\n"

for f in files:
    path = os.path.join(openfl, f)
    s = open(path).read()
    t = re.sub(r"#if !openfl_wgpu\n((?:import [^\n]*\n)+)#end\n", fix, s)
    if t != s:
        open(path, "w").write(t)
print("ungated", count)
