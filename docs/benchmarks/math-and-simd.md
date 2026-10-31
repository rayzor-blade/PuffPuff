# Math and SIMD benchmarks

The matrix and vector types of `lime.math` and batched arithmetic with `ash.simd`. There is no OpenFL baseline yet:
the comparison would be with Lime's native `Matrix4` and friends, not measured here.

## Cases

<!-- bench-table prefixes="math.,simd." -->
| Case | Operations per run | Median per operation | Allocation per operation |
|---|---:|---:|---:|
| `math.matrix4.append` | 1 | 7.9 ns | 0 B |
| `math.matrix4.append.scalar` | 1 | 40.2 ns | 0 B |
| `math.matrix3.concat` | 1 | 6.0 ns | 0 B |
| `math.vector4.add` | 1 | 4.4 ns | 0 B |
| `math.float32array.readwrite` | 2048 | 2.4 ns | 0 B |
| `simd.batch.add.inplace` | 4096 | 0.1 ns | 0 B |
| `simd.batch.add.scalar` | 4096 | 0.6 ns | 0 B |
<!-- /bench-table -->

- `math.matrix4.append`: a 4 x 4 matrix product in `lime.math.Matrix4`, with the data in typed bytes and the product
  done in SIMD. `.scalar` is the same product on doubles, kept to show what the SIMD form is worth.
- `math.matrix3.concat`, `math.vector4.add`: scalar on doubles. SIMD was measured slower for these and is not used.
- `math.float32array.readwrite`: reads and writes 2048 elements of a `Float32Array`, per element.
- `simd.batch.add.inplace`: adds two arrays of 4096 floats with in-place `ash.simd.Vec` operations, per element.
  `.scalar` is the same loop on plain floats.

SIMD only pays on typed bytes and in-place batches: per-operation vector values lose to scalar code because the
value is built and taken apart each time.

## Known weak spots

- The hybrid tier of Ash gives different numbers from the LLVM tier for these cases; only LLVM is recorded.

## Reproducing

```sh
tools/bench/run.sh --mode llvm math,simd
```
