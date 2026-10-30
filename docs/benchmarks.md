# Benchmarks

What PuffPuff measures, how to reproduce it, and how it compares with OpenFL's native backend. Everything here
is produced by scripts in `tools/bench`; the numbers below are from one machine and one run of those scripts, so
rerun them before quoting a number elsewhere.

## Text against OpenFL

The only area with an OpenFL baseline so far. The OpenFL side is a small OpenFL application
(`tools/bench/openfl/src/Main.hx`) built with hxcpp in release mode and run natively; the PuffPuff side is the
`text.*` and `gpu.frame.text.*` cases of `tools/bench`.

| Measurement | OpenFL (ms) | PuffPuff (ms) | PuffPuff is |
|---|---:|---:|---:|
| New 133-character paragraph: layout (OpenFL, with wrapping) or shaping (PuffPuff, one line) | 0.628 | 0.008 | 79.7x faster |
| 200 labels, static, per frame: PuffPuff submitted | 1.450 | 0.250 | 5.8x faster |
| 200 labels, static, per frame: PuffPuff finished and read back | 1.450 | 1.152 | 1.3x faster |
| 200 labels, text set every frame: PuffPuff submitted | 9.113 | 0.399 | 22.8x faster |
| 200 labels, text set every frame: PuffPuff finished and read back | 9.113 | 1.327 | 6.9x faster |

OpenFL 9.5.2 on Lime 8.3.2, hxcpp 4.3.2 release, median of 5 runs. PuffPuff on Ash 0.1.14, LLVM tier, median of
15 samples. Apple M1 Pro, 2026-10-30.

### How to read it

- **Frame rows.** OpenFL's number is the time per frame of a real window with vsync off (fps set to 1000),
  averaged over 300 frames after 30 warm-up frames. It includes OpenFL's update, render and buffer swap. For the
  "set every frame" row OpenFL lays each label out again, rasterizes it on the CPU and uploads it.
- **PuffPuff "submitted"** is the time to build the frame's quads and submit the command buffer to an offscreen
  texture. The GPU's work is not waited for, so this is the CPU-side cost of the frame. It is not directly
  comparable with a frame that includes presenting; treat it as how much CPU the text path needs.
- **PuffPuff "finished and read back"** waits for the GPU and copies the 512 x 512 frame to the CPU. That copy
  costs about 0.9 ms (the difference to the submitted row) and OpenFL's frame has no equivalent, so this row is a
  conservative upper bound on PuffPuff's frame time. The true comparison lies between the two rows.
- **Paragraph row.** OpenFL's time is `TextField` layout of a wrapped paragraph (the text engine, no drawing).
  PuffPuff's time is shaping one new line: it does not wrap yet, so the two do slightly different work. Both
  rows are for text the engine has not seen before; text it has seen is cheaper on both sides.
- **Runtimes differ.** OpenFL is native code compiled by hxcpp; PuffPuff runs on Ash's JIT. The text cost is
  mostly in cached lookups and a few native calls, so the tier matters little, but it is a difference.
- **Scope.** PuffPuff composes printable ASCII from cached per-character data (`puffpuff.text.RunComposer`).
  Other text, such as CJK, emoji and ligatures, is shaped by the native engine at 0.5 to 1.5 ms per new string
  and is not covered by these numbers. First use of a character or character pair costs one native call.
- **Not a `TextField` comparison yet.** PuffPuff's OpenFL backend does not draw `TextField` yet, so this compares
  the two text paths directly, not the same program on both backends.

### Reproducing

```sh
tools/bench/openfl/run.sh                # builds and runs OpenFL's side; opens a window for a few seconds
tools/bench/run.sh --mode llvm --baseline # PuffPuff's cases; stores tools/bench/baselines/<machine>-llvm.json
python3 tools/bench/compare_openfl.py     # prints the table above
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

Baseline: Ash 0.1.14, LLVM tier, Apple M1 Pro, 2026-10-30. `ns/op` is per logical operation (a pixel, a label, a
matrix); frame cases are per frame.

| Case | Median | Allocation per op |
|---|---:|---:|
| `math.matrix4.append` (SIMD) | 8.0 ns | 0 B |
| `math.matrix4.append.scalar` | 40.7 ns | 0 B |
| `math.matrix3.concat` | 6.0 ns | 0 B |
| `math.vector4.add` | 4.5 ns | 0 B |
| `simd.batch.add.inplace` / `.scalar` | 0.2 ns / 0.6 ns | 0 B |
| `image.fillRect` (per pixel) | 1.6 ns | 0 B |
| `image.copyPixels` (per pixel) | 0.1 ns | 0 B |
| `image.copyPixels.merge` (per pixel) | 102.5 ns | 128 B |
| `image.getPixels` (per pixel) | 45.2 ns | 68 B |
| `text.shape.paragraph`, 133 characters, new each call | 7.9 us | 24 KB |
| `text.shape.paragraph.native`, same, native engine | 1.53 ms | 30 KB |
| `text.shape.labels200` (per 28-character label) | 2.1 us | 6 KB |
| `text.shape.labels200.native` (per label) | 596.7 us | 7.7 KB |
| `text.measure.labels200` (per label) | 614 ns | 352 B |
| `canvas2d.build.cold` | 7.7 us | 16 KB |
| `canvas2d.build.reused` | 387 ns | 72 B |
| `quadbatcher.addQuad` | 5.1 ns | 0 B |
| `mesh.appendTranslated` (per vertex) | 1.8 ns | 0 B |
| `gpu.frame.vectors.submit` / `.readback` | 0.52 ms / 1.42 ms | 40 KB / 2.1 MB |
| `gpu.frame.sprites.submit` / `.readback` | 0.16 ms / 1.01 ms | 3 KB / 2.1 MB |
| `gpu.frame.text.static.submit` / `.readback` | 0.25 ms / 1.15 ms | 3 KB / 2.1 MB |
| `gpu.frame.text.dynamic.submit` / `.readback` | 0.40 ms / 1.33 ms | 58 KB / 2.2 MB |

Allocation in the text cases includes the benchmark building its own label strings. The `.readback` frame cases
allocate the 512 x 512 readback buffer, which is most of their figure.

### Known weak spots

Stated here because they are measured, not because they are fixed:

- Image pixel operations are plain Haxe loops (`image.copyPixels.merge`, `image.getPixels`). Only plain copies
  run at memory speed.
- Composed text covers printable ASCII only, and has no wrapping.
- `canvas2d.build.cold` allocates 16 KB per build; the per-frame allocation work is not done.

### What is not compared yet

No OpenFL baseline exists for vector graphics, sprites, bitmaps, math or memory. Those cases only track PuffPuff
against its own baseline. A claim of being faster than OpenFL's OpenGL or Cairo path for them needs the same scene
measured on that backend first.

## Correctness and rendering checks

The harness checks outputs, and the snapshot scenes in `tools/snapshot/scenes` render headless to PNG with pixel
checks: `OpenFLShapeScene`, `OpenFLGradientScene` and `OpenFLBitmapScene` run a real OpenFL `Stage` on PuffPuff at
display scales 1 and 2, and `TextCompositionScene` compares composed text with the native engine's, line by line.
