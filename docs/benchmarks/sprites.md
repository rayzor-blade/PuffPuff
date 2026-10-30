# Sprite and quad benchmarks

Batching textured quads with `puffpuff.gpu.QuadBatcher` and drawing them instanced. This is the path `Tilemap`,
`drawQuads`, bitmaps and HaxeFlixel's sprite batching take. There is no OpenFL baseline yet.

## Cases

<!-- bench-table prefixes="quadbatcher.,gpu.frame.sprites." -->
| Case | Operations per run | Median per operation | Allocation per operation |
|---|---:|---:|---:|
| `quadbatcher.addQuad` | 10000 | 5.1 ns | 0 B |
| `gpu.frame.sprites.submit` | 1 | 160.8 us | 3 KB |
| `gpu.frame.sprites.readback` | 1 | 980.3 us | 2.1 MB |
<!-- /bench-table -->

- `quadbatcher.addQuad`: adds 10000 quads to a batch. It must allocate nothing.
- `gpu.frame.sprites.*`: 5000 quads of 8 x 8 pixels sampling a 4 x 4 texture, in one batch, drawn into a 512 x 512
  offscreen texture as a frame. See the [method](README.md#method) for submit and read back.

## Known weak spots

- Each flush of a batch creates a new uniform buffer and a new storage buffer instead of reusing per-frame buffers
  as the vector path does. Not measured yet; it matters for scenes with many small batches.

## Reproducing

```sh
tools/bench/run.sh --mode llvm quadbatcher,gpu.frame.sprites
```
