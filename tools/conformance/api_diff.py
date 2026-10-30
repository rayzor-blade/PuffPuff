#!/usr/bin/env python3
"""Compares the public API of PuffPuff's `lime.*` layer with upstream Lime.

    tools/conformance/api_diff.py <upstream lime>/src [--package lime.math] [--json out.json]

Source-level, not compiler-level: members are read from `.hx` text, `#if` blocks are evaluated
against the HashLink/desktop defines in `DEFINES`, and a type's members are only those declared
in it (inherited ones are not followed). So a "missing" member may be provided by a base class
here; treat the report as a to-check list, not a verdict.
"""
import argparse, json, os, re, sys, warnings

# Upstream types this backend replaces rather than ports: it has no OpenGL, Cairo, OpenAL or
# HarfBuzz, and no per-API render contexts (`RenderContext` itself is kept).
OUT_OF_SCOPE = (
    "lime.graphics.opengl.", "lime.graphics.cairo.", "lime.media.openal.", "lime.media.howlerjs.",
    "lime.text.harfbuzz.", "lime.media.vorbis.", "lime.net.curl.", "lime.net.oauth.",
    "lime.graphics.Canvas2DRenderContext", "lime.graphics.DOMRenderContext",
    "lime.graphics.CairoRenderContext", "lime.graphics.FlashRenderContext", "lime.graphics.OpenGL", "lime.graphics.GL", "lime.graphics.VulkanRenderContext",
    "lime.graphics.WebGL", "lime.media.FlashAudioContext", "lime.media.HTML5AudioContext",
    "lime.media.WebAudioContext", "lime.media.OpenALAudioContext", "lime.system.JNI", "lime.system.CFFI",
    "lime._internal.backend.", "lime._internal.macros.", "lime.tools.", "lime.graphics.vulkan.",
)

DEFINES = {"hl", "sys", "native", "lime_cffi", "desktop", "macos", "mac", "lime", "lime_hl"}
TYPE_RE = re.compile(r"^\s*((?:@:[\w()., \"'=]+\s+|extern\s+|private\s+|final\s+)*)(class|interface|abstract|enum abstract|enum|typedef)\s+(\w+)")
MEMBER_RE = re.compile(r"^\s*((?:@[\w:().,\"' =]+\s+)*)((?:public|private|static|inline|override|extern|final|dynamic|macro|overload)\s+)*(function|var|final)\s+(?:(get|set)_)?(\w+)")


def evaluate(cond):
    cond = cond.replace("-", "_")
    expr = re.sub(r"[A-Za-z_]\w*", lambda m: f"({m.group(0) in DEFINES})", cond)
    expr = expr.replace("!", " not ").replace("&&", " and ").replace("||", " or ")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            return bool(eval(expr, {"__builtins__": {}}))
    except Exception:
        return False


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def active_lines(text):
    """Yields lines that survive `#if` evaluation."""
    stack = []  # (parent_active, taken, active)
    for line in text.split("\n"):
        s = line.strip()
        m = re.match(r"#(if|elseif)\b\s*(.*)", s)
        if m and m.group(1) == "if":
            parent = all(a for _, _, a in stack)
            val = evaluate(m.group(2))
            stack.append((parent, val, val))
            continue
        if m and stack:
            parent, taken, _ = stack[-1]
            val = (not taken) and evaluate(m.group(2))
            stack[-1] = (parent, taken or val, val)
            continue
        if s.startswith("#else") and stack:
            parent, taken, _ = stack[-1]
            stack[-1] = (parent, True, not taken)
            continue
        if s.startswith("#end"):
            if stack:
                stack.pop()
            continue
        if s.startswith("#"):
            continue
        if all(a for _, _, a in stack):
            yield line


def parse(path):
    """Returns {type name: {"kind": ..., "members": {name: kind+static}}} for one file."""
    with open(path, encoding="utf-8", errors="replace") as f:
        text = strip_comments(f.read())
    out, current, depth, type_depth = {}, None, 0, 0
    for line in active_lines(text):
        t = TYPE_RE.match(line)
        if t and depth == 0:
            current = t.group(3)
            kind = t.group(2)
            if "private" in t.group(1).split():
                current = None
            else:
                out[current] = {"kind": kind, "members": {}}
                type_depth = depth
        elif current and depth == type_depth + 1:
            m = MEMBER_RE.match(line)
            if m:
                mods = (m.group(2) or "") + " " + " ".join(re.findall(r"\b(?:public|private|static)\b", line.split(m.group(5))[0]))
                kind = out[current]["kind"]
                is_public = "public" in mods or kind in ("interface", "enum", "typedef") or "@:op" in (m.group(1) or "") or "@:from" in (m.group(1) or "") or "@:to" in (m.group(1) or "")
                if m.group(4) and not is_public:
                    pass
                if is_public and not m.group(4):
                    if m.group(5).startswith("__"):
                        continue  # internals, not API
                    name = ("static " if "static" in mods else "") + m.group(5)
                    out[current]["members"][name] = m.group(3)
        depth += line.count("{") - line.count("}")
        if depth <= type_depth:
            if current and depth == type_depth and "}" in line:
                current = None
    return out


def collect(root, package):
    types = {}
    base = os.path.join(root, *package.split("."))
    for d, _, files in os.walk(base):
        for fn in sorted(files):
            if not fn.endswith(".hx"):
                continue
            path = os.path.join(d, fn)
            rel = os.path.relpath(path, root)[:-3].replace(os.sep, ".")
            module = rel
            for name, info in parse(path).items():
                key = module if name == fn[:-3] else module + "." + name
                types[key] = info
    return types


def refs(consumer, ours):
    """Lime types a consumer names (imports or qualified uses) with no source file here, by use count."""
    pat = re.compile(r"\blime\.[a-z_]+(?:\.[a-z_]+)*\.[A-Z]\w*")
    counts = {}
    for d, _, files in os.walk(consumer):
        for fn in files:
            if fn.endswith(".hx"):
                with open(os.path.join(d, fn), encoding="utf-8", errors="replace") as f:
                    for t in pat.findall(strip_comments(f.read())):
                        counts[t] = counts.get(t, 0) + 1
    missing = {t: n for t, n in counts.items() if not os.path.exists(os.path.join(ours, *t.split(".")) + ".hx")}
    for t, n in sorted(missing.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"{n:4} {t}{'  (out of scope: no GL/Cairo/etc.)' if t.startswith(OUT_OF_SCOPE) else ''}")
    print(f"{len(missing)} of {len(counts)} referenced lime types missing, "
          f"{sum(1 for t in missing if not t.startswith(OUT_OF_SCOPE))} in scope")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("upstream")
    ap.add_argument("--ours", default=os.path.join(os.path.dirname(__file__), "..", "..", "src"))
    ap.add_argument("--package", default="lime")
    ap.add_argument("--json")
    ap.add_argument("--refs", help="OpenFL (or other consumer) src dir: list the lime types it references that we lack")
    a = ap.parse_args()
    if a.refs:
        return refs(a.refs, a.ours)
    up, mine = collect(a.upstream, a.package), collect(a.ours, a.package)

    missing_all = sorted(set(up) - set(mine))
    missing_types = [t for t in missing_all if not t.startswith(OUT_OF_SCOPE)]
    skipped_types = [t for t in missing_all if t.startswith(OUT_OF_SCOPE)]
    extra_types = sorted(set(mine) - set(up))
    gaps = {}
    for name in sorted(set(up) & set(mine)):
        miss = sorted(set(up[name]["members"]) - set(mine[name]["members"]))
        if miss:
            gaps[name] = miss
    report = {"package": a.package, "missingTypes": missing_types, "outOfScopeTypes": skipped_types, "extraTypes": extra_types, "missingMembers": gaps}
    if a.json:
        with open(a.json, "w") as f:
            json.dump(report, f, indent=1)

    print(f"types: upstream {len(up)}, ours {len(mine)}, missing {len(missing_types)} (+{len(skipped_types)} out of scope), extra {len(extra_types)}")
    for t in missing_types:
        print(f"  missing type {t}")
    print(f"types present in both with missing members: {len(gaps)} ({sum(len(v) for v in gaps.values())} members)")
    for name, miss in sorted(gaps.items(), key=lambda kv: -len(kv[1])):
        print(f"  {name}: {len(miss)} missing — {', '.join(miss[:12])}{' …' if len(miss) > 12 else ''}")


if __name__ == "__main__":
    sys.exit(main())
