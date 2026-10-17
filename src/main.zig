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

    const a = [_]f32{1, 2, 3};
    const b = [_]f32{4, 5, 6};

    const result = dot(&a, &b);
    std.debug.print("result: {d}\n", .{result});
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
