const std = @import("std");

// game-oriented math library

// explicit types as a first argument
// preferably no error unions as return types
// preferably no optional return types
// minimize reliance on std.math
// where possible functions should be inline
// where possible, avoid bit manipulation

// TODO: "don't care" casting
// TODO: mod
// TODO: min / max (with slices/vectors ?)
// TODO: sign / abs
// TODO: absmin / absmax (absmax(3, -5) -> -5)
// TODO: pow / powi (possibly as one function)
// TODO: sqrt / cbrt
// TODO: sin / cos / tan
// TODO: asin / acos / atan / atan2
// TODO: hypot
// TODO: log / log2 / log10 / ln
// TODO: exp / exp2
// TODO: floor / ceil / round (maybe with int returns)
// TODO: fract
// TODO: wrap
// TODO: clamp
// TODO: lerp (@mulAdd?) / moveTowards
// TODO: degrees <-> radians conversion
// TODO: easing     https://easings.net/
// TODO: noise (white / value) with easing
// TODO: rng (default prng is probably good enough for now, test other hashes later)
// TODO: max / min values for types

// TODO! should vectors be structs or @Vectors?
// pros of struct: component acces
// pros of @Vector: reuse of code, SIMD

// TODO: all vec types: random / noise

pub fn Vec2(T: type) type {
    return @Vector(2, T);
}
// TODO: "don't" care casting
// TODO: constants for vectors (zero / one / directions)
// TODO: equality (maybe with optionals)
// TODO: negate
// TODO: clamp
// TODO: aspect calc
// TODO: sum / diff
// TODO: mul / div by scalar
// TODO: mul / div by vector
// TODO: magnitude / magnitudeSq
// TODO: normalized
// TODO: withMagnitude
// TODO: dot / cross
// TODO: rotated / rotatedAround
// TODO: angle / angleTo / absAngleTo
// TODO: withAngle
// TODO: absed / floored / ceiled / rounded
// TODO: lerped / movedTowards
// TODO: lineInterection (optional return with intersection point)

// TODO: Vec3: research operations

pub fn Col3(T: type) type {
    return @Vector(3, T);
}
// TODO: Col3: research operations 
// TODO: Col4: research operations
// TODO: Col3 <-> Col4 conversions (stripAlpha / withAlpha)
// TODO: Col*: lerp / moveTowards
// TODO: Col3: rgb <-> hsv
// TODO: Col*: color constants

// TODO: Mat3: research operations (if even needed)
// TODO: Mat4: research operations
// TODO: Mat*: add / mul
// TODO: Mat*: projections
// TODO: Mat*: translation / rotation / scale

pub const e     = 2.71828182845904523536028747135266249775724709369995;
pub const pi    = 3.14159265358979323846264338327950288419716939937510;
pub const phi   = 1.6180339887498948482045868343656381177203091798057628621;
pub const tau   = 2 * pi;