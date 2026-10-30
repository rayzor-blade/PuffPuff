# Image benchmarks

CPU pixel operations of `lime.graphics.Image`, on a 256 x 256 image. They are Lime's own Haxe implementations,
because PuffPuff has no native image code. There is no OpenFL baseline yet: the comparison is with Lime's native
(C++) image functions, which have not been measured here.

## Cases

<!-- bench-table prefixes="image." -->
| Case | Operations per run | Median per operation | Allocation per operation |
|---|---:|---:|---:|
| `image.fillRect` | 65536 | 1.6 ns | 0 B |
| `image.copyPixels` | 65536 | 0.1 ns | 0 B |
| `image.copyPixels.merge` | 65536 | 100.4 ns | 128 B |
| `image.getPixels` | 65536 | 42.9 ns | 68 B |
| `image.setPixel32.row` | 256 | 6.0 ns | 0 B |
<!-- /bench-table -->

An operation is a pixel, except for `image.setPixel32.row`, where it is one `setPixel32` call (256 along a row).

- `image.fillRect`: fills the whole image with a colour.
- `image.copyPixels`: copies the whole image onto another.
- `image.copyPixels.merge`: copies with alpha merged over the destination.
- `image.getPixels`: reads the whole image out as bytes, converting the pixel format.
- `image.setPixel32.row`: writes one pixel at a time along a row.

## Known weak spots

Measured, not fixed:

- Only plain copies run at memory speed (`image.copyPixels`, 0.1 ns per pixel).
- `image.copyPixels.merge` costs about 100 ns per pixel and `image.getPixels` about 45 ns per pixel, both allocating on
  each call, because the pixel format conversion and the blend are scalar Haxe. They are the first candidates for
  in-place SIMD batches over the pixel data, or for moving the work to the GPU when the destination is a texture.

## Reproducing

```sh
tools/bench/run.sh --mode llvm image
```
