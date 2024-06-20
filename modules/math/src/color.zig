// TODO: Col3: research operations 
// TODO: Col4: research operations
// TODO: Col3 <-> Col4 conversions (stripAlpha / withAlpha)
// TODO: Col*: lerp / moveTowards
// TODO: Col3: rgb <-> hsv
// TODO: Col*: color constants
// pub inline fn v2Cross(a: anytype, b: @TypeOf(a)) @typeInfo(@TypeOf(a)).Vector.child {
//     return a[0] * b[1] - a[1] * b[0];
// }
pub inline fn c4ReplaceAlpha(col: anytype, alpha: @typeInfo(@TypeOf(col)).Vector.child) @Vector(4, @TypeOf(alpha)) {
    return .{ col[0], col[1], col[2], alpha };
}

pub inline fn c4AlphaMult(col: anytype, mult: @typeInfo(@TypeOf(col)).Vector.child) @Vector(4, @TypeOf(mult)) {
    return .{ col[0], col[1], col[2], col[3] * mult };
}