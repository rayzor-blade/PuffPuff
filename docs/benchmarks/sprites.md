# Sprite and quad benchmarks

Batching textured quads with `puffpuff.gpu.QuadBatcher` and drawing them instanced. This is the path `Tilemap`,
`drawQuads`, bitmaps and HaxeFlixel's sprite batching take. There is no OpenFL baseline yet.

## Cases

<!-- bench-table prefixes="quadbatcher.,gpu.frame.sprites.,trianglebatcher.,gpu.frame.triangles." -->
| Case | Operations per run | Median per operation | Allocation per operation |
|---|---:|---:|---:|
| `quadbatcher.addQuad` | 10000 | 5.0 ns | 0 B |
| `trianglebatcher.vertex` | 10000 | 14.6 ns | 0 B |
| `gpu.frame.sprites.submit` | 1 | 163.9 us | 3 KB |
| `gpu.frame.sprites.readback` | 1 | 1.03 ms | 2.1 MB |
| `gpu.frame.triangles.submit` | 1 | 362.8 us | 5 KB |
| `gpu.frame.triangles.readback` | 1 | 1.19 ms | 2.1 MB |
<!-- /bench-table -->

- `quadbatcher.addQuad`: adds 10000 quads to a batch. It must allocate nothing.
- `gpu.frame.sprites.*`: 5000 quads of 8 x 8 pixels sampling a 4 x 4 texture, in one batch, drawn into a 512 x 512
  offscreen texture as a frame. See the [method](README.md#method) for submit and read back.
- `trianglebatcher.vertex`: adds 10000 squares as two triangles each (six 24-byte vertices) to a triangle batch. It
  must allocate nothing.
- `gpu.frame.triangles.*`: the same 5000 squares as triangles, 30000 vertices, for `Graphics.drawTriangles` and
  bitmap-filled rectangles. Set against the sprite frame it shows what instancing saves: a square is 144 bytes as
  triangles and 48 as an instance, so `drawQuads` and `Tilemap` stay on the instanced path.

## Known weak spots

- Each flush of a batch creates a new uniform buffer and a new storage buffer instead of reusing per-frame buffers
  as the vector path does. Not measured yet; it matters for scenes with many small batches.

## Reproducing

```sh
tools/bench/run.sh --mode llvm gpu.frame.sprites
tools/bench/run.sh --mode llvm gpu.frame.triangles
```
