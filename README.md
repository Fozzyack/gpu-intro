# GPU

GPU Programming example

## Dot product: Zig + CUDA

Requires Zig 0.17, the NVIDIA driver, and the CUDA Toolkit (`cuda` on Arch).
The default target is the RTX 4080 Super (`sm_89`); CUDA is expected in `/opt/cuda`.

```sh
zig build run
zig build test
```

For a different toolkit location: `zig build run -Dcuda-path=/usr/local/cuda`.

`src/main.zig` creates two vectors and computes a CPU reference. `src/dot.cu`
copies them to GPU memory and launches blocks of 256 threads. Each thread
multiplies one pair of elements. Within each block, shared memory holds the
products, then a tree reduction adds pairs in stages: 256 → 128 → … → 1.
Every stage uses a barrier so threads see the preceding stage's writes.
Threads beyond the vector's end contribute zero but must still reach barriers.

The GPU returns one partial sum per block; Zig adds these to get the dot product.
This is intentionally a hybrid reduction, not yet a fully GPU-resident one.
The example checks 4099 elements, exercising multiple blocks and a partial block.
The CPU tests do not require CUDA or a GPU.

The small integer-valued inputs give exact sums in `f32`. With general floating
inputs, compare using a tolerance: parallel addition changes rounding order.
This example is for correctness and learning, not benchmarking: allocating and
copying memory will dominate such a small computation.

## Learning note: from GPU blocks to HPC clusters

A dot product is a reduction: `sum(a[i] * b[i])`. Each GPU block computes a
local sum, and Zig combines those sums. Across a cluster, the same pattern
applies: each process computes a local dot product, then an MPI reduction
combines the results (`MPI_Reduce` for one recipient, `MPI_Allreduce` for all).
GPU barriers synchronize only threads within one block, not the whole GPU or
cluster; each level needs its own coordination.

For `n` elements, the dot product does about `2n` floating-point operations
while reading `8n` bytes of `f32` input: roughly 0.25 FLOP per byte, excluding
partial sums and transfers. This low arithmetic intensity makes large dot
products typically memory-bandwidth-bound. Keeping inputs on the GPU and
reusing allocations is important before measuring kernel performance.

Next exercise: reduce the partial sums with a second GPU kernel, then compare
results and timings with the current CPU final reduction. Use a floating-point
tolerance when trying non-integer inputs.
