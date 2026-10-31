# Vector graphics benchmarks

Turning paths into triangles with `puffpuff.canvas.Canvas2D` and drawing them. There is no OpenFL baseline yet: OpenFL
draws vector graphics through OpenGL triangles or Cairo, and neither has been measured on the same scene.

## Cases

<!-- bench-table prefixes="canvas2d.,mesh.,gpu.frame.vectors." -->
| Case | Operations per run | Median per operation | Allocation per operation |
|---|---:|---:|---:|
| `canvas2d.build.cold` | 300 | 7.5 us | 17 KB |
| `canvas2d.build.reused` | 64 | 387.0 ns | 72 B |
| `mesh.appendTranslated` | 3000 | 1.8 ns | 0 B |
| `gpu.frame.vectors.submit` | 1 | 498.5 us | 40 KB |
| `gpu.frame.vectors.readback` | 1 | 1.44 ms | 2.1 MB |
<!-- /bench-table -->

The scene is 300 shapes in a 20-column grid: circles, rounded rectangles and triangles filled with a solid colour, and
cubic curves stroked 2 px wide.

- `canvas2d.build.cold`: builds the scene from scratch (flatten, tessellate with analytic anti-aliasing edges, record
  the paint), with nothing cached.
- `canvas2d.build.reused`: 64 of the shapes drawn again each run, translated by a changing offset, so the triangles
  built before are reused and only moved.
- `mesh.appendTranslated`: copies 3000 vertices into a mesh moved by an offset: the cost of reusing a cached shape,
  per vertex.
- `gpu.frame.vectors.*`: the 300 shapes built and drawn into a 512 x 512 offscreen texture, as a frame. See the
  [method](README.md#method) for submit and read back.

## Known weak spots

- A cold build allocates about 17 KB per shape; per-frame allocation has not been driven to zero.
- With a hybrid-tier Ash 0.1.14 some runs drop the stroked shapes (225 of 300 shapes produce vertices); the check in
  `gpu.frame.vectors` exists to catch it. It does not happen on the LLVM tier.

## Reproducing

```sh
tools/bench/run.sh --mode llvm canvas2d,mesh,gpu.frame.vectors
```
