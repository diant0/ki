const std = @import("std");

// game-oriented math library

// inferred types where possible
// preferably working on comptime types
// preferably no error unions as return types
// preferably no optional return types
// minimize reliance on std.math
// where possible functions should be inline
// where possible, avoid bit manipulation

// --------------------------------

pub const e = std.math.e;
pub const pi = std.math.pi;
pub const phi = std.math.phi;
pub const tau = 2 * pi;

pub const deg2rad = std.math.degreesToRadians(comptime_float, 1);
pub const rad2deg = std.math.radiansToDegrees(comptime_float, 1);

// --------------------------------

const easing = @import("easing.zig");
pub const Easing = easing.Easing;
pub const ease = easing.ease;

pub const noise = @import("noise.zig");
pub const rng = @import("rng.zig");

const vector = @import("vector.zig");
pub usingnamespace vector;

const matrix = @import("matrix.zig");
pub usingnamespace matrix;

const rect = @import("rect.zig");
pub usingnamespace rect;

const color = @import("color.zig");
pub usingnamespace color;

test "math.*" {
    _ = easing;
    _ = noise;
    _ = rng;
    _ = vector;
}

// --------------------------------

pub inline fn minValue(T: type) T {
    return switch (@typeInfo(T)) {
        .Float => std.math.floatMin(T),
        .Int => std.math.minInt(T),
        else => @compileError("math.minValue: only runtime numeric types supported"),
    };
}

pub inline fn maxValue(T: type) T {
    return switch (@typeInfo(T)) {
        .Float => std.math.floatMax(T),
        .Int => std.math.maxInt(T),
        else => @compileError("math.minValue: only runtime numeric types supported"),
    };
}

test "math.[minValue, maxValue]" {
    _ = minValue(f32);
    _ = maxValue(f64);

    _ = minValue(i64);
    _ = maxValue(u32);
}

// --------------------------------

/// NOTE: rounds when casting from float to int
pub inline fn cast(DestT: type, v: anytype) DestT {
    const SourceT = @TypeOf(v);

    return switch (@typeInfo(SourceT)) {
        .Int, .ComptimeInt => blk: {
            break :blk switch (@typeInfo(DestT)) {
                .Int, .ComptimeInt => @intCast(v),
                .Float, .ComptimeFloat => @floatFromInt(v),
                else => @compileError("math.cast: unexpected destination type " ++ @typeName(DestT)),
            };
        },

        .Float, .ComptimeFloat => blk: {
            break :blk switch (@typeInfo(DestT)) {
                .Int, .ComptimeInt => @intFromFloat(round(v)),
                .Float, .ComptimeFloat => @floatCast(v),
                else => @compileError("math.cast: unexpected destination type " ++ @typeName(DestT)),
            };
        },

        else => @compileError("math.cast: unsupported source type " ++ @typeName(SourceT)),
    };
}

test "math.cast" {
    try std.testing.expectEqual(i32, @TypeOf(cast(i32, @as(u64, 444))));
    try std.testing.expectEqual(u32, @TypeOf(cast(u32, @as(f32, 3.4))));
    try std.testing.expectEqual(f64, @TypeOf(cast(f64, @as(f32, -22))));
    try std.testing.expectEqual(f16, @TypeOf(cast(f16, @as(i16, -12))));

    try std.testing.expectEqual(comptime_int, @TypeOf(cast(comptime_int, @as(comptime_float, 3.3))));
    try std.testing.expectEqual(comptime_float, @TypeOf(cast(comptime_float, @as(comptime_int, 3))));
}

// --------------------------------

pub inline fn mod(n: anytype, denom: @TypeOf(n)) @TypeOf(n) {
    std.debug.assert(denom > 0);
    return @mod(n, denom);
}

// --------------------------------

pub inline fn rem(n: anytype, denom: @TypeOf(n)) @TypeOf(n) {
    std.debug.assert(denom > 0);
    return @rem(n, denom);
}

// --------------------------------

pub inline fn min(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return @min(a, b);
}

pub inline fn max(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return @max(a, b);
}

// --------------------------------

pub inline fn sign(n: anytype) @TypeOf(n) {
    return if (n < 0) -1 else 1;
}

test "math.sign" {
    try std.testing.expectEqual(@as(u32, 1), sign(@as(u32, 4)));
    try std.testing.expectEqual(@as(i32, -1), sign(@as(i32, -4)));
    try std.testing.expectEqual(@as(f32, 1), sign(@as(f32, 0.0000001)));
    try std.testing.expectEqual(@as(f64, -1), sign(@as(f64, -55555555)));

    try std.testing.expectEqual(-1, sign(@as(comptime_int, -4)));
    try std.testing.expectEqual(1, sign(@as(comptime_float, 0.0000001)));
}

// --------------------------------

pub inline fn abs(n: anytype) @TypeOf(n) {
    return n * sign(n);
}

test "math.abs" {
    try std.testing.expectEqual(@as(u32, 4), abs(@as(u32, 4)));
    try std.testing.expectEqual(@as(i32, 4), abs(@as(i32, -4)));
    try std.testing.expectEqual(@as(f32, 0.25), abs(@as(f32, 0.25)));
    try std.testing.expectEqual(@as(f64, 2), abs(@as(f64, -2)));

    try std.testing.expectEqual(4, abs(@as(comptime_int, -4)));
    try std.testing.expectEqual(0.25, abs(@as(comptime_float, -0.25)));
}

// --------------------------------

pub inline fn absmin(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return if (abs(a) < abs(b)) a else b;
}

pub inline fn absmax(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return if (abs(a) > abs(b)) a else b;
}

test "math.[absmin, absmax]" {
    try std.testing.expectEqual(@as(f32, 0.25), absmin(@as(f32, -2.0), 0.25));
    try std.testing.expectEqual(@as(i32, -2222), absmax(@as(f32, -2222), 22));

    try std.testing.expectEqual(0.25, absmin(@as(comptime_float, -2.0), 0.25));
    try std.testing.expectEqual(-2222, absmax(@as(comptime_int, -2222), 22));
}

// --------------------------------

// TODO: non-integer powers and tests
pub inline fn pow(n: anytype, p: anytype) @TypeOf(n) {
    const T = @TypeOf(n);
    const E = blk: {
        const P = @TypeOf(p);
        break :blk if (P == comptime_int) isize else P;
    };

    return switch (@typeInfo(E)) {
        .Int => blk: {
            var i: E = p;
            var r: T = 1;

            while (i != 0) {
                if (i > 0) {
                    r *= n;
                    i -= 1;
                } else if (i < 0) {
                    r /= n;
                    i += 1;
                }
            }

            break :blk r;
        },

        .Float => std.math.pow(T, n, cast(T, p)),

        else => @compileError("math.pow: unexpected power type " ++ @typeName(E)),
    };
}

test "math.pow" {
    try std.testing.expectEqual(@as(f32, 0.125), pow(@as(f32, 2), -3));
    try std.testing.expectEqual(@as(u32, 81), pow(@as(u32, 3), @as(i32, 4)));
}

// --------------------------------

pub inline fn floor(n: anytype) @TypeOf(n) {
    return @floor(n);
}

pub inline fn ceil(n: anytype) @TypeOf(n) {
    return @ceil(n);
}

pub inline fn trunc(n: anytype) @TypeOf(n) {
    return @trunc(n);
}

pub inline fn round(n: anytype) @TypeOf(n) {
    return @round(n);
}

// --------------------------------

pub inline fn fract(n: anytype) @TypeOf(n) {
    return rem(n, 1);
}

test "math.fract" {
    try std.testing.expectEqual(@as(f32, 0.5), fract(@as(f32, 5.5)));
    try std.testing.expectEqual(@as(f64, -0.25), fract(@as(f32, -5.25)));
}

// --------------------------------

pub inline fn clamp(n: anytype, lower_bound: @TypeOf(n), upper_bound: @TypeOf(n)) @TypeOf(n) {
    if (n < lower_bound) return lower_bound;
    if (n > upper_bound) return upper_bound;
    return n;
}

test "math.clamp" {
    try std.testing.expectEqual(@as(f32, 2.0), clamp(@as(f32, 1.5), 2.0, 3.0));
    try std.testing.expectEqual(@as(i32, 3), clamp(@as(i32, 5), 2, 3));
    try std.testing.expectEqual(@as(u32, 5), clamp(@as(u32, 5), 3, 6));
}

// --------------------------------

pub inline fn wrap(n: anytype, lower_bound: @TypeOf(n), upper_bound: @TypeOf(n)) @TypeOf(n) {
    const window = upper_bound - lower_bound;
    return mod(n - lower_bound, window) + lower_bound;
}

test "math.wrap" {
    try std.testing.expectApproxEqRel(@as(f32, 0.5), wrap(@as(f32, 0.0), 0.2, 0.7), sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqRel(@as(f64, 0.3), wrap(@as(f64, 0.3), 0.2, 0.7), sqrt(std.math.floatEps(f64)));
    try std.testing.expectApproxEqRel(@as(f128, 0.3), wrap(@as(f128, 0.8), 0.2, 0.7), sqrt(std.math.floatEps(f64)));

    try std.testing.expectEqual(@as(comptime_int, 3), wrap(@as(comptime_int, 7), 0, 4));
    try std.testing.expectEqual(@as(usize, 2), wrap(@as(usize, 2), 0, 4));
    try std.testing.expectEqual(@as(i32, 1), wrap(@as(i32, -3), 0, 4));
}

// --------------------------------

/// gives closest multiple of step to n when using floats.
/// gives biggest multiple of step that hast smaller magnitude than n.
/// expects positive step.
pub inline fn quantize(n: anytype, step: @TypeOf(n)) @TypeOf(n) {
    return switch (@typeInfo(@TypeOf(n))) {
        .Int, .ComptimeInt => (n / step) * step,
        .Float, .ComptimeFloat => round(n / step) * step,
        else => @compileError("math.quantize: only numeric types allowed"),
    };
}

test "math.quantize" {
    try std.testing.expectEqual(@as(f32, 0.75), quantize(@as(f32, 0.8), 0.25));
    try std.testing.expectEqual(@as(i32, -3), quantize(@as(i32, -5), 3));
    try std.testing.expectEqual(@as(u32, 8), quantize(@as(u32, 11), 4));
}

// --------------------------------

pub inline fn sqrt(n: anytype) @TypeOf(n) {
    return @sqrt(n);
}

// --------------------------------

pub inline fn sin(n: anytype) @TypeOf(n) {
    return @sin(n);
}

pub inline fn cos(n: anytype) @TypeOf(n) {
    return @cos(n);
}

pub inline fn tan(n: anytype) @TypeOf(n) {
    return @tan(n);
}

// --------------------------------

pub const asin = std.math.asin;
pub const acos = std.math.acos;
pub const atan = std.math.atan;
pub const atan2 = std.math.atan2;

// --------------------------------

pub inline fn hypotSq(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return a * a + b * b;
}

pub inline fn hypot(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return sqrt(hypotSq(a, b));
}

test "math.hypot" {
    try std.testing.expectEqual(@as(f64, 5), hypot(@as(f64, 3), 4));
}

// --------------------------------

pub inline fn lerp(lower: anytype, upper: @TypeOf(lower), t: anytype) @TypeOf(lower) {
    const T = @TypeOf(lower);
    const C = @TypeOf(t);

    const range = upper - lower;
    const rc = cast(C, lower) + cast(C, range) * t;

    return cast(T, rc);
}

test "math.lerp" {
    try std.testing.expectApproxEqRel(@as(f32, 0.5), lerp(@as(f32, 0.0), 1.0, 0.5), sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqRel(@as(f64, 77.5), lerp(@as(f64, 10.0), 100.0, 0.75), sqrt(std.math.floatEps(f64)));

    try std.testing.expectEqual(@as(i32, 0), lerp(@as(i32, -10.0), 10.0, 1.0 / 2.0));
}

// --------------------------------

pub fn ilerp(n: anytype, lower: @TypeOf(n), upper: @TypeOf(n), TT: type) TT {
    const range = upper - lower;
    const offset = n - lower;
    return cast(TT, offset) / cast(TT, range);
}

test "math.ilerp" {
    try std.testing.expectApproxEqRel(@as(f32, 0.5), ilerp(@as(f32, 0.5), 0.0, 1.0, f32), sqrt(std.math.floatEps(f32)));
    try std.testing.expectApproxEqRel(@as(f64, 0.75), ilerp(@as(f64, 77.5), 10.0, 100.0, f64), sqrt(std.math.floatEps(f64)));
}

// --------------------------------

/// uses f64 as transitional t
pub inline fn remap(n: anytype, in_lower: @TypeOf(n), in_upper: @TypeOf(n), out_lower: @TypeOf(n), out_upper: @TypeOf(n)) @TypeOf(n) {
    return lerp(out_lower, out_upper, ilerp(n, in_lower, in_upper, f64));
}

test "math.remap" {
    try std.testing.expectEqual(@as(f32, 10.0), remap(@as(f32, 4.0), 2, 6, 0, 20));
}

// --------------------------------

pub inline fn moveTowards(from: anytype, to: @TypeOf(from), max_delta: @TypeOf(from)) @TypeOf(from) {
    const range = to - from;
    if (abs(range) < max_delta) {
        return to;
    }
    return from + sign(range) * max_delta;
}

test "math.moveTowards" {
    try std.testing.expectEqual(@as(u32, 4), moveTowards(@as(u32, 1), 10, 3));
    try std.testing.expectEqual(@as(i32, -10), moveTowards(@as(i32, -9), -10, 3));

    try std.testing.expectEqual(@as(f64, 1.25), moveTowards(@as(f64, 1), 2, 0.25));

    try std.testing.expectEqual(@as(comptime_float, 4), moveTowards(@as(comptime_float, 3.5), 5, 0.5));
}

// --------------------------------
