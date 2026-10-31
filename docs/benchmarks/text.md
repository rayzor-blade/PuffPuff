# Text benchmarks

Shaping and laying out lines of text, and drawing screens of labels, against OpenFL's native text path.

## Against OpenFL

The OpenFL side is a small OpenFL application (`tools/bench/openfl/src/Main.hx`) built with hxcpp in release mode
and run natively. The PuffPuff side is the `text.*` and `gpu.frame.text.*` cases below.

<!-- openfl-comparison -->
OpenFL 9.5.2 on Lime 8.3.2, hxcpp 4.3.2 release, 5 runs (2026-10-30); PuffPuff 20d72c3 on ash 0.1.14 (llvm tier); Apple M1 Pro.

| Measurement | OpenFL (ms) | PuffPuff (ms) | PuffPuff is |
|---|---:|---:|---:|
| New 133-character paragraph: layout (OpenFL, with wrapping) or shaping one line (PuffPuff) | 0.628 | 0.010 | 60.6x faster |
| New 133-character paragraph: layout (OpenFL, with wrapping) or shaping one line (PuffPuff) (whole lines, for reference) | 0.628 | 0.043 | 14.7x faster |
| 200 labels, static, per frame, PuffPuff submitted | 1.450 | 0.219 | 6.6x faster |
| 200 labels, static, per frame, PuffPuff finished and read back | 1.450 | 1.118 | 1.3x faster |
| 200 labels, text set every frame, PuffPuff submitted | 9.113 | 0.540 | 16.9x faster |
| 200 labels, text set every frame, PuffPuff submitted (whole lines, for reference) | 9.113 | 3.107 | 2.9x faster |
| 200 labels, text set every frame, PuffPuff finished and read back | 9.113 | 1.538 | 5.9x faster |
| 200 labels, text set every frame, PuffPuff finished and read back (whole lines, for reference) | 9.113 | 4.518 | 2.0x faster |
<!-- /openfl-comparison -->

PuffPuff has one text path, in `blinc_abi`. It shapes each character once per style and subpixel phase, or the
characters that must be shaped together (a ligature, a joining or combining script, a line with right-to-left
text), keeps the result, and builds a new line from the pieces with kerning from a table of character pairs. A new
line costs lookups; text it has not seen costs shaping only for the pieces it lacks, and the cache is emptied when
the glyph atlas is. The "whole lines, for reference" rows switch that cache off so every line is shaped as a whole,
which is how the engine alone works; they show what the cache saves and are not a second code path in use.

### How to read it

- **Frame rows.** OpenFL's number is the time per frame of a real window with vsync off (fps set to 1000), averaged
  over 300 frames after 30 warm-up frames. It includes OpenFL's update, render and buffer swap. For the "set every
  frame" rows OpenFL lays each label out again, rasterizes it on the CPU and uploads it.
- **Submitted and read back** are described in the [method](README.md#method): the true comparison with a frame
  that is presented lies between the two rows.
- **Paragraph row.** OpenFL's time is `TextField` layout of a wrapped paragraph (the text engine, no drawing).
  PuffPuff's time is shaping one new line: it does not wrap yet, so the two do slightly different work. Both rows are
  for text the engine has not seen before; text it has seen is cheaper on both sides.
- **Runtimes differ.** OpenFL is native code compiled by hxcpp; PuffPuff runs on Ash's JIT. The shaping itself is
  native code on both sides; the surrounding Haxe is compiled by hxcpp on one and JIT-compiled on the other.
- **Not a `TextField` comparison yet.** PuffPuff's OpenFL backend does not draw `TextField` yet, so this compares the
  two text paths directly, not the same program on both backends.

### Accuracy

Lines built from the cache are compared with the same lines shaped whole by `TextCacheCheck` (Latin, accents, Greek,
Cyrillic, quotes, CJK, symbols, emoji, Hebrew, Arabic, combining marks) and by a Rust test in `blinc_abi`, and the
benchmark's own check does the same on every run. On the Latin lines the width and every glyph position are identical
to shaping whole (0 px). The check also forces a glyph atlas clear and confirms the cache follows it.

## Cases

<!-- bench-table prefixes="text.,gpu.frame.text." -->
| Case | Operations per run | Median per operation | Allocation per operation |
|---|---:|---:|---:|
| `text.shape.paragraph` | 1 | 10.4 us | 24 KB |
| `text.shape.paragraph.whole` | 1 | 42.8 us | 25 KB |
| `text.shape.labels200` | 200 | 3.1 us | 6 KB |
| `text.shape.labels200.whole` | 200 | 14.5 us | 6 KB |
| `text.measure.labels200` | 200 | 1.7 us | 400 B |
| `gpu.frame.text.static.submit` | 1 | 218.9 us | 3 KB |
| `gpu.frame.text.static.readback` | 1 | 1.12 ms | 2.1 MB |
| `gpu.frame.text.dynamic.submit` | 1 | 540.0 us | 67 KB |
| `gpu.frame.text.dynamic.readback` | 1 | 1.54 ms | 2.2 MB |
| `gpu.frame.text.dynamic.whole.submit` | 1 | 3.11 ms | 67 KB |
| `gpu.frame.text.dynamic.whole.readback` | 1 | 4.52 ms | 2.2 MB |
<!-- /bench-table -->

- `text.shape.paragraph`: one 133 character line of new text each run, shaped and its glyphs placed.
  `.whole` shapes it as a whole line instead.
- `text.shape.labels200`: 200 labels of 28 characters, each new; an operation is one label. `.whole` as above.
- `text.measure.labels200`: the same labels, measured and not drawn.
- `gpu.frame.text.static.*`: 200 labels shaped once and drawn every frame.
- `gpu.frame.text.dynamic.*`: 200 labels with new text every frame, drawn with `FontAtlas.drawText`. `.whole`
  switches the cache off.

Allocation in the text cases includes the benchmark building its own label strings. `prepare` allocates a result object
per glyph (24 KB for the paragraph); `drawText`, which the frame cases use, reads the glyphs without making objects.

## Known differences from OpenFL

- **Hinted advances.** OpenFL native lays text out with each glyph's advance rounded to a whole pixel, and keeps kerning
  fractional. It does so for the default anti-aliasing and for `ADVANCED` below sharpness 400; at `ADVANCED` with
  sharpness 400 or more it uses exact advances (measured, 14 px Arial). PuffPuff uses exact advances by default,
  which match OpenFL's unhinted mode to within about 0.1 px. For 14 px Arial the hinted layout makes `a` 8 px against
  7.79 px, "The quick brown fox" 128 px against 125.28 px, and the same text up to a few percent wider, so a field can
  wrap at a different place. Setting `puffpuff.text.FontAtlas.hintedAdvances = true` makes PuffPuff round each
  character's advance for text that asks for hinting (OpenFL's `autoHint`), and then the widths match OpenFL native: the
  benchmark paragraph is 292.97 px in 3 lines on both, checked by `TextHintCheck` against widths measured on OpenFL.
  It is off by default.

## Known weak spots

- PuffPuff's text API does not wrap lines; OpenFL's `TextEngine` will do that from per-character advances once
  `TextLayout` provides them for every script.
- The comparison covers Latin labels. Other scripts work (see accuracy) but have no OpenFL baseline.

## Reproducing

```sh
tools/bench/openfl/run.sh                  # OpenFL 9.5.2 on Lime 8.3.2 with hxcpp, in a haxelib repository under .puffpuff
tools/bench/run.sh --mode llvm --baseline text
python3 tools/bench/docs.py                # regenerates the table above
```

`openfl/run.sh` installs Lime, OpenFL and hxcpp into a haxelib repository under `.puffpuff/bench/openfl`, not the
global one, and passes the Xcode SDK version to hxcpp. Versions can be set with `LIME_VERSION`, `OPENFL_VERSION` and
`HXCPP_VERSION`. It needs macOS with Xcode.
