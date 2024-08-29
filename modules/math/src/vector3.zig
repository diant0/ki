const std = @import("std");
const math = @import("module.zig");

// TODO: many operations

// --------------------------------

pub inline fn v3Cross(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

test "math.vector.v3Cross" {
    try std.testing.expectEqual(@Vector(3, i32){ 16, 4, 8 }, v3Cross(@Vector(3, i32){ -1, -2, 3 }, .{ 4, 0, -8 }));
}

// --------------------------------

pub inline fn v3Fromv2(v: anytype, z: @typeInfo(@TypeOf(v)).Vector.child) @Vector(3, @typeInfo(@TypeOf(v)).Vector.child) {
    if (@typeInfo(@TypeOf(v)).Vector.len != 2) {
        @compileError("v3Fromv2 expects @Vector(2, T) as an argument");
    }
    return .{ v[0], v[1], z };
}
