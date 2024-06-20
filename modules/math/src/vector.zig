const std = @import("std");
const math = @import("module.zig");

// TODO: vrandom
// TODO: vnoise

// --------------------------------

const vector2 = @import("vector2.zig");
pub usingnamespace vector2;

const vector3 = @import("vector3.zig");
pub usingnamespace vector3;

test "math.vector.imports" {
    _ = vector2;
    _ = vector3;
}

// --------------------------------

pub inline fn vcast(T: type, v: anytype) @Vector(@typeInfo(@TypeOf(v)).Vector.len, T) {

    const vlen = @typeInfo(@TypeOf(v)).Vector.len;
    var result: @Vector(vlen, T) = undefined;
    for (0..vlen) | i | {
        result[i] = math.cast(T, v[i]);
    }
    return result;

}

test "math.vector.vcast" {

    try std.testing.expectEqual(@Vector(3, f32), @TypeOf(vcast(f32, @as(@Vector(3, u32), @splat(3)))));

}

// --------------------------------

pub inline fn vEq(a: anytype, b: @TypeOf(a)) bool {
    return @reduce(.And, a == b);
}

test "math.vector.vEq" {

    try std.testing.expect(vEq(@Vector(2, f32) { 1, 1 }, @Vector(2, f32) { 1, 1 }));
    try std.testing.expect(!vEq(@Vector(2, f32) { 1, 1 }, @Vector(2, f32) { -2, 4 }));

}

// --------------------------------

pub inline fn vMagnitudeSq(v: anytype) @typeInfo(@TypeOf(v)).Vector.child {
    return @reduce(.Add, v * v);
}

pub inline fn vMagnitude(v: anytype) @typeInfo(@TypeOf(v)).Vector.child {
    return math.sqrt(vMagnitudeSq(v));
}

test "math.vector.vMagnitude" {
    try std.testing.expectApproxEqAbs(@as(f32, 5), vMagnitude(@Vector(2, f32) { 3, 4 }), math.sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqAbs(@as(f64, 3.74165738677), vMagnitude(@Vector(3, f32) { -1, 2, -3 }), math.sqrt(std.math.floatEps(f32)));
}

// --------------------------------

pub inline fn vNormalized(v: anytype) @TypeOf(v) {
    return v / @as(@TypeOf(v), @splat(vMagnitude(v)));
}

test "math.vector.vNormalized" {
    try std.testing.expectEqual(@as(f64, 1), vMagnitude(vNormalized(@Vector(2, f64) { 3, -2 })));
}

// --------------------------------

pub inline fn vWithMagnitude(v: anytype, magnitude: @typeInfo(@TypeOf(v)).Vector.child) @TypeOf(v) {
    return vNormalized(v) * @as(@TypeOf(v), @splat(magnitude));
}

test "math.vector.vWithMagnitude" {
    try std.testing.expectEqual(@as(f64, 4.0), vMagnitude(vWithMagnitude(@Vector(3, f64) { 1.0, 2.0, 3.0 }, 4.0)));
}

// --------------------------------

pub inline fn vDot(a: anytype, b: @TypeOf(a)) @typeInfo(@TypeOf(a)).Vector.child {
    return @reduce(.Add, a * b);
}

test "math.vector.vDot" {
    try std.testing.expectEqual(@as(i32, -28), vDot(@Vector(3, i32) { -1, -2, 3 }, .{ 4, 0, -8 }));
}

// --------------------------------

// TODO: probably optimizable
pub inline fn vLerp(lower: anytype, upper: @TypeOf(lower), t: anytype) @TypeOf(lower) {
    
    var result: @TypeOf(lower) = undefined;
    for (0..@typeInfo(@TypeOf(result)).Vector.len) | i | {
        result[i] = math.lerp(lower[i], upper[i], t);
    }

    return result;

}

test "math.vector.vLerp" {

    const a = vLerp(@Vector(4, f64) { 0, -3, 10, 0 }, .{ 2, 3, 20, 4 }, @as(f32, 0.5));
    try std.testing.expectEqual(@Vector(4, f64) { 1, 0, 15, 2 }, a);

}

// --------------------------------

pub inline fn vMoveTowards(from: anytype, to: @TypeOf(from), max_delta_magnitude: @typeInfo(@TypeOf(from)).Vector.child) @TypeOf(from) {

    const range = to - from;
    if (vMagnitudeSq(range) < max_delta_magnitude * max_delta_magnitude) {
        return to;
    }
    return from + vWithMagnitude(range, max_delta_magnitude);

}

test "math.vector.vMoveTowards" {
    try std.testing.expectEqual(@Vector(2, f32) { 1.0, 0.5 }, vMoveTowards(@Vector(2, f32) { 1.0, 1.0 }, .{ 1.0, 0.0 }, 0.5));
}

// --------------------------------

/// component-by-component, not respecting resulting magnitude of motion
pub inline fn vMoveTowardsC(from: anytype, to: @TypeOf(from), max_delta_component: @typeInfo(@TypeOf(from)).Vector.child) @TypeOf(from) {
    var result: @TypeOf(from) = undefined;
    inline for (0..@typeInfo(@TypeOf(from)).Vector.len) | i | {
        result[i] = math.moveTowards(from[i], to[i], max_delta_component);
    }
    return result;
}

// TODO: test vMoveTowardsC

// --------------------------------