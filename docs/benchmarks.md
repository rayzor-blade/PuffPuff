# Benchmarks

What PuffPuff measures, how to reproduce it, and how it compares with OpenFL's native backend. Everything here
is produced by scripts in `tools/bench`; the numbers below are from one machine and one run of those scripts, so
rerun them before quoting a number elsewhere.

**Build the native text library in release mode.** PuffPuff's text shaping and glyph atlas live in `blinc_abi`
(Rust). A debug build of it is 40 to 80 times slower at shaping a new line (about 570 us against 7 to 15 us for a
28 character label), and every number below is from the release build. The build stages
`../blinc_abi/target/release/libblinc_abi.dylib` and warns when only a debug one exists; build it with
`cargo build --release` in `../blinc_abi`.

## Text against OpenFL

The only area with an OpenFL baseline so far. The OpenFL side is a small OpenFL application
(`tools/bench/openfl/src/Main.hx`) built with hxcpp in release mode and run natively; the PuffPuff side is the
`text.*` and `gpu.frame.text.*` cases of `tools/bench`.

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

PuffPuff has one text path, in `blinc_abi`. It shapes each character once per style and subpixel phase, or the
characters that must be shaped together (a ligature, a joining or combining script, a line with right-to-left
text), keeps the result, and builds a new line from the pieces with kerning from a table of character pairs. A new
line costs lookups; text it has not seen costs shaping only for the pieces it lacks, and the cache is emptied when
the glyph atlas is. The "whole lines, for reference" rows switch that cache off so every line is shaped as a whole,
which is how the engine alone works; they show what the cache saves and are not a second code path in use.

### How to read it

- **Frame rows.** OpenFL's number is the time per frame of a real window with vsync off (fps set to 1000),
  averaged over 300 frames after 30 warm-up frames. It includes OpenFL's update, render and buffer swap. For the
  "set every frame" row OpenFL lays each label out again, rasterizes it on the CPU and uploads it.
- **PuffPuff "submitted"** is the time to build the frame's quads and submit the command buffer to an offscreen
  texture. The GPU's work is not waited for, so this is the CPU-side cost of the frame. It is not directly
  comparable with a frame that includes presenting; treat it as how much CPU the text path needs.
- **PuffPuff "finished and read back"** waits for the GPU and copies the 512 x 512 frame to the CPU. That copy
  costs about 0.9 ms (the difference to the submitted row for static text) and OpenFL's frame has no equivalent,
  so this row is a conservative upper bound on PuffPuff's frame time. The true comparison lies between the two rows.
- **Paragraph row.** OpenFL's time is `TextField` layout of a wrapped paragraph (the text engine, no drawing).
  PuffPuff's time is shaping one new line: it does not wrap yet, so the two do slightly different work. Both
  rows are for text the engine has not seen before; text it has seen is cheaper on both sides.
- **Runtimes differ.** OpenFL is native code compiled by hxcpp; PuffPuff runs on Ash's JIT. The shaping itself is
  native code on both sides; the surrounding Haxe is compiled by hxcpp on one and JIT-compiled on the other.
- **Accuracy.** Lines built from the cache are compared with the same lines shaped whole by `TextCacheCheck`
  (Latin, accents, Greek, Cyrillic, quotes, CJK, symbols, emoji, Hebrew, Arabic, combining marks) and by a Rust
  test, and the benchmark's own check does the same on every run. On the Latin lines the width and every glyph
  position are identical to shaping whole (0 px), and the check also forces a glyph atlas clear and confirms the
  cache follows it.
- **Not a `TextField` comparison yet.** PuffPuff's OpenFL backend does not draw `TextField` yet, so this compares
  the two text paths directly, not the same program on both backends.

### Reproducing

```sh
(cd ../blinc_abi && cargo build --release)  # once; the benchmark stages this library
tools/bench/openfl/run.sh                   # builds and runs OpenFL's side; opens a window for a few seconds
tools/bench/run.sh --mode llvm --baseline   # PuffPuff's cases; stores tools/bench/baselines/<machine>-llvm.json
python3 tools/bench/compare_openfl.py       # prints the table above
```

`openfl/run.sh` installs Lime, OpenFL and hxcpp into a haxelib repository under `.puffpuff/bench/openfl`, not the
global one, and passes the Xcode SDK version to hxcpp. Versions can be set with `LIME_VERSION`, `OPENFL_VERSION`
and `HXCPP_VERSION`. It needs macOS with Xcode.

## PuffPuff cases

All cases are in `tools/bench/Cases.hx`. Each is timed as best of 15 samples (the median is reported) in its own
process, then measured again for allocation per operation with exact counts (`ASH_GC_TLAB=0`) and for memory
growth across a third batch of runs. A case can carry a correctness check and a checksum of its output; a changed
checksum or a failed check fails the run. `tools/bench/run.sh` compares a run with the stored baseline for the
same machine and mode and fails on a slowdown beyond the tolerance (30% by default).

Baseline: PuffPuff `20d72c3`, Ash 0.1.14, LLVM tier, Apple M1 Pro, 2026-10-30. Time is per logical operation (a
pixel, a label, a matrix); frame cases are per frame.

| Case | Median | Allocation per op |
|---|---:|---:|
| `math.matrix4.append` (SIMD) | 7.7 ns | 0 B |
| `math.matrix4.append.scalar` | 41.3 ns | 0 B |
| `math.matrix3.concat` | 6.1 ns | 0 B |
| `math.vector4.add` | 4.5 ns | 0 B |
| `simd.batch.add.inplace` / `.scalar` | 0.2 ns / 0.6 ns | 0 B / 0 B |
| `image.fillRect` (per pixel) | 1.6 ns | 0 B |
| `image.copyPixels` (per pixel) | 0.1 ns | 0 B |
| `image.copyPixels.merge` (per pixel) | 100.4 ns | 128 B |
| `image.getPixels` (per pixel) | 42.9 ns | 68 B |
| `text.shape.paragraph` / `.whole`, 133 characters | 10.4 us / 42.8 us | 24 KB / 25 KB |
| `text.shape.labels200` / `.whole` (per 28-character label) | 3.1 us / 14.5 us | 6 KB / 6 KB |
| `text.measure.labels200` (per label) | 1.7 us | 400 B |
| `canvas2d.build.cold` / `.reused` | 7.0 us / 391.2 ns | 17 KB / 72 B |
| `quadbatcher.addQuad` | 5.1 ns | 0 B |
| `mesh.appendTranslated` (per vertex) | 1.8 ns | 0 B |
| `gpu.frame.vectors.submit` / `.readback` | 506.3 us / 1.47 ms | 40 KB / 2.1 MB |
| `gpu.frame.sprites.submit` / `.readback` | 160.8 us / 980.3 us | 3 KB / 2.1 MB |
| `gpu.frame.text.static.submit` / `.readback` | 218.9 us / 1.12 ms | 3 KB / 2.1 MB |
| `gpu.frame.text.dynamic.submit` / `.readback` | 540.0 us / 1.54 ms | 67 KB / 2.2 MB |
| `gpu.frame.text.dynamic.whole.submit` / `.readback` | 3.11 ms / 4.52 ms | 67 KB / 2.2 MB |

Allocation in the text cases includes the benchmark building its own label strings. The `.readback` frame cases
allocate the 512 x 512 readback buffer, which is most of their figure. `prepare` allocates a result object per
glyph (24 KB for the paragraph); `drawText`, which the frame cases use, reads the glyphs without making objects.

### Known weak spots

Stated here because they are measured, not because they are fixed:

- Image pixel operations are plain Haxe loops (`image.copyPixels.merge`, `image.getPixels`). Only plain copies
  run at memory speed.
- PuffPuff's text API does not wrap lines; OpenFL's `TextEngine` will do that from per-character advances once
  `TextLayout` provides them for every script.
- `canvas2d.build.cold` allocates 17 KB per build; the per-frame allocation work is not done.

### What is not compared yet

No OpenFL baseline exists for vector graphics, sprites, bitmaps, math or memory. Those cases only track PuffPuff
against its own baseline. A claim of being faster than OpenFL's OpenGL or Cairo path for them needs the same scene
measured on that backend first.

## Correctness and rendering checks

The harness checks outputs, and the snapshot scenes in `tools/snapshot/scenes` render headless to PNG with pixel
checks: `OpenFLShapeScene`, `OpenFLGradientScene` and `OpenFLBitmapScene` run a real OpenFL `Stage` on PuffPuff at
display scales 1 and 2, and `TextCacheCheck` compares cached text lines with whole-line shaping across scripts and
across a forced atlas clear.
