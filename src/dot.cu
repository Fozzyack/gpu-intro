#include <cuda_runtime.h>
#include <stddef.h>

// Keep this in sync with threads_per_block in main.zig.
static constexpr unsigned int threads_per_block = 256;

__global__ void dot_partials(const float *a, const float *b, size_t n,
                             float *partials) {
    __shared__ float sums[threads_per_block];
    const unsigned int lane = threadIdx.x;
    const size_t i = size_t(blockIdx.x) * blockDim.x + lane;

    // Out-of-bounds threads still participate in every barrier.
    sums[lane] = i < n ? a[i] * b[i] : 0.0f;
    __syncthreads();

    // A tree reduction: 256 values -> 128 -> ... -> 1.
    for (unsigned int stride = blockDim.x / 2; stride > 0; stride /= 2) {
        if (lane < stride) sums[lane] += sums[lane + stride];
        __syncthreads();
    }
    if (lane == 0) partials[blockIdx.x] = sums[0];
}

// A plain C ABI lets Zig call this without understanding CUDA syntax.
extern "C" int gpu_dot_partials(const float *a, const float *b, size_t n,
                                 float *partials, size_t block_count) {
    if (n == 0) return int(cudaSuccess);
    if (block_count != n / threads_per_block + (n % threads_per_block != 0))
        return int(cudaErrorInvalidValue);

    float *device_a = nullptr;
    float *device_b = nullptr;
    float *device_partials = nullptr;
    cudaError_t status = cudaSuccess;

    // A single cleanup path also frees earlier allocations after an error.
#define CUDA_TRY(call) do { status = (call); if (status != cudaSuccess) goto cleanup; } while (0)
    CUDA_TRY(cudaMalloc(&device_a, n * sizeof(float)));
    CUDA_TRY(cudaMalloc(&device_b, n * sizeof(float)));
    CUDA_TRY(cudaMalloc(&device_partials, block_count * sizeof(float)));
    CUDA_TRY(cudaMemcpy(device_a, a, n * sizeof(float), cudaMemcpyHostToDevice));
    CUDA_TRY(cudaMemcpy(device_b, b, n * sizeof(float), cudaMemcpyHostToDevice));

    dot_partials<<<static_cast<unsigned int>(block_count), threads_per_block>>>(
        device_a, device_b, n, device_partials);
    CUDA_TRY(cudaGetLastError());
    CUDA_TRY(cudaDeviceSynchronize());
    CUDA_TRY(cudaMemcpy(partials, device_partials, block_count * sizeof(float),
                        cudaMemcpyDeviceToHost));

cleanup:
    cudaFree(device_partials);
    cudaFree(device_b);
    cudaFree(device_a);
    return int(status);
#undef CUDA_TRY
}

extern "C" const char *gpu_dot_error_string(int status) {
    return cudaGetErrorString(static_cast<cudaError_t>(status));
}
