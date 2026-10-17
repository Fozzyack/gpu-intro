const std = @import("std");

const threads_per_block = 256;

extern fn gpu_dot_partials(a: [*]const f32, b: [*]const f32, n: usize, partials: [*]f32, block_count: usize) c_int;
extern fn gpu_dot_error_string(status: c_int) [*:0]const u8;

fn dot(a: []const f32, b: []const f32) f32 {
    std.debug.assert(a.len == b.len);

    var sum: f32 = 0;
    for (a, b) |x, y| {
        sum += x * y;
    }
    return sum;
}

pub fn main() !void {
    // More than one block, and deliberately not a multiple of 256.
    const n = 4099;
    var a: [n]f32 = undefined;
    var b: [n]f32 = undefined;
    for (&a, &b, 0..) |*x, *y, i| {
        x.* = @as(f32, @floatFromInt(i % 7)) - 3;
        y.* = @as(f32, @floatFromInt(i % 5)) - 2;
    }

    const block_count = (n + threads_per_block - 1) / threads_per_block;
    var partials: [block_count]f32 = undefined;
    const status = gpu_dot_partials(&a, &b, n, &partials, block_count);
    if (status != 0) {
        std.debug.print("CUDA error: {s}\n", .{gpu_dot_error_string(status)});
        return error.CudaFailed;
    }

    // Finish the reduction on the CPU for this first example.
    var gpu_result: f32 = 0;
    for (partials) |partial| gpu_result += partial;
    const cpu_result = dot(&a, &b);
    std.debug.print("Elements: {d}, GPU blocks: {d}\nCPU: {d}\nGPU: {d}\n", .{
        n, block_count, cpu_result, gpu_result,
    });
    // These small integer-valued inputs sum exactly in f32. General floating
    // inputs need a tolerance because reduction orders differ.
    if (gpu_result != cpu_result) return error.ResultMismatch;
}

test "dot product" {
    const a = [_]f32{ 1, 2, 3 };
    const b = [_]f32{ 4, 5, 6 };

    try std.testing.expectEqual(@as(f32, 32), dot(&a, &b));
}

test "empty vectors" {
    const empty = [_]f32{};
    try std.testing.expectEqual(@as(f32, 0), dot(&empty, &empty));
}
