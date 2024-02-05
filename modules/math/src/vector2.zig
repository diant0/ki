const std = @import("std");
const math = @import("math.zig");

const vector = @import("vector.zig");

// TODO: lineInterection (optional return with intersection point)

// --------------------------------

pub inline fn v2Cross(a: anytype, b: @TypeOf(a)) @typeInfo(@TypeOf(a)).Vector.child {
    return a[0] * b[1] - a[1] * b[0];
}

test "math.vector2.v2Cross" {
    try std.testing.expectEqual(@as(f32, 0), v2Cross(@Vector(2, f32) { 1.0, 1.0 }, @splat(-4)));
}

// --------------------------------

pub inline fn v2AbsAngleTo(a: anytype, b: @TypeOf(a)) @typeInfo(@TypeOf(a)).Vector.child {
    return math.acos(vector.vDot(a, b) / (vector.vMagnitude(a) * vector.vMagnitude(b)));
}

test "math.vector2.v2AbsAngleTo" {

    const up = @Vector(2, f32) { 0.0, 3.0 };
    const right = @Vector(2, f32) { 9.0, 0.0 };
    const left = @Vector(2, f32) { -0.2, 0.0 };

    try std.testing.expectApproxEqAbs(@as(f32, math.pi)/2, v2AbsAngleTo(up, right), math.sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, math.pi)/2, v2AbsAngleTo(right, up), math.sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, math.pi), v2AbsAngleTo(right, left), math.sqrt(std.math.floatEps(f32)));

}

// --------------------------------

pub inline fn v2AngleTo(a: anytype, b: anytype) @typeInfo(@TypeOf(a)).Vector.child {
    return v2AbsAngleTo(a, b) * math.sign(v2Cross(a, b));
}

test "math.vector2.v2AngleTo" {

    const up = @Vector(2, f32) { 0.0, 3.0 };
    const right = @Vector(2, f32) { 9.0, 0.0 };
    const left = @Vector(2, f32) { -0.2, 0.0 };

    try std.testing.expectApproxEqAbs(@as(f32, -math.pi)/2, v2AngleTo(up, right), math.sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, math.pi)/2, v2AngleTo(right, up), math.sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, math.pi), v2AngleTo(right, left), math.sqrt(std.math.floatEps(f32)));

}

// --------------------------------

pub inline fn v2Angle(a: anytype) @typeInfo(@TypeOf(a)).Vector.child {
    const right = @Vector(2, @typeInfo(@TypeOf(a)).Vector.child) { 1, 0 };
    return v2AngleTo(a, right);
}

test "math.vector2.v2Angle" {

    const up    = @Vector(2, f32) { 0.0, 3.0 };
    const right = @Vector(2, f32) { 9.0, 0.0 };
    const left  = @Vector(2, f32) { -0.2, 0.0 };

    try std.testing.expectApproxEqAbs(@as(f32, -math.pi)/2, v2Angle(up), math.sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, 0), v2Angle(right), math.sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, math.pi), v2Angle(left), math.sqrt(std.math.floatEps(f32)));

}

// --------------------------------

pub inline fn v2RotatedBy(v: anytype, a: @typeInfo(@TypeOf(v)).Vector.child) @TypeOf(v) {
    const sin_a = math.sin(a);
    const cos_a = math.cos(a);
    return .{
        v[0] * cos_a - v[1] * sin_a,
        v[0] * sin_a + v[1] * cos_a,
    };
}

test "math.vector2.v2RotatedBy" {
    
    const up    = @Vector(2, f64) { 0.0, 9.0 };
    const right = @Vector(2, f64) { 9.0, 0.0 };

    const right_rotated = v2RotatedBy(right, math.pi/2.0);

    try std.testing.expectApproxEqAbs(up[0], right_rotated[0], math.sqrt(std.math.floatEps(f64)));
    try std.testing.expectApproxEqAbs(up[1], right_rotated[1], math.sqrt(std.math.floatEps(f64)));

}

// --------------------------------

pub inline fn v2RotatedAround(v: anytype, anchor: @TypeOf(v), a: @typeInfo(@TypeOf(v)).Vector.child) @TypeOf(v) {
    return anchor + v2RotatedBy(v - anchor, a);
}

test "math.vector2.v2RotatedAround" {

    const a: @Vector(2, f64) = @splat(0);
    const right = @Vector(2, f64) { 9.0, 0.0 };
    const b = v2RotatedAround(a, right, math.pi/2.0);
    
    try std.testing.expectApproxEqAbs(@as(f32,  9), b[0], math.sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, -9), b[1], math.sqrt(std.math.floatEps(f32)));

}

// --------------------------------

pub inline fn v2WithAngle(v: anytype, a: @typeInfo(@TypeOf(v)).Vector.child) @TypeOf(v) {
    return v2RotatedBy(v, v2Angle(v) - a);
}

test "math.vector2.v2WithAngle" {

    const up = @Vector(2, f64) { 0.0, 3.0 };
    const a = v2WithAngle(up, 0);

    try std.testing.expectApproxEqAbs(up[1], a[0], math.sqrt(std.math.floatEps(f64)));
    try std.testing.expectApproxEqAbs(up[0], a[1], math.sqrt(std.math.floatEps(f64)));

}

