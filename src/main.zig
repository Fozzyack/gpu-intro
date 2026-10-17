const std = @import("std");

fn dot(a: []const f32, b: []const f32) f32 {
    std.debug.assert(a.len == b.len);

    var sum: f32 = 0;
    for (a, b) | x, y | {
        sum += x * y;
    }
    return sum;
}

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});
}
