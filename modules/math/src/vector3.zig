const std = @import("std");
const math = @import("math.zig");

// TODO: many operations

// --------------------------------

pub inline fn v3Cross(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return .{
        a[1]*b[2] - a[2]*b[1],
        a[2]*b[0] - a[0]*b[2],
        a[0]*b[1] - a[1]*b[0],
    };
}

test "math.vector.v3Cross" {
    try std.testing.expectEqual(@Vector(3, i32) { 16, 4, 8 }, v3Cross(@Vector(3, i32) { -1, -2, 3 }, .{ 4, 0, -8 }));
}

// --------------------------------
