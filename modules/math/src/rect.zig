const math = @import("module.zig");

pub inline fn rBottomLeft(rect: anytype) @Vector(2, @typeInfo(@TypeOf(rect)).Vector.child) {
    return .{ rect[0], rect[1] };
}

pub inline fn rBottomRight(rect: anytype) @Vector(2, @typeInfo(@TypeOf(rect)).Vector.child) {
    return .{ rect[0] + rect[2], rect[1] };
}

pub inline fn rTopLeft(rect: anytype) @Vector(2, @typeInfo(@TypeOf(rect)).Vector.child) {
    return .{ rect[0], rect[1] + rect[3] };
}

pub inline fn rTopRight(rect: anytype) @Vector(2, @typeInfo(@TypeOf(rect)).Vector.child) {
    return .{ rect[0] + rect[2], rect[1] + rect[3] };
}

pub inline fn rLeft(rect: anytype) @typeInfo(@TypeOf(rect)).Vector.child {
    return rect[0];
}

pub inline fn rRight(rect: anytype) @typeInfo(@TypeOf(rect)).Vector.child {
    return rect[0] + rect[2];
}

pub inline fn rBottom(rect: anytype) @typeInfo(@TypeOf(rect)).Vector.child {
    return rect[1];
}

pub inline fn rTop(rect: anytype) @typeInfo(@TypeOf(rect)).Vector.child {
    return rect[1] + rect[3];
}

pub inline fn rPos(rect: anytype) @Vector(2, @typeInfo(@TypeOf(rect)).Vector.child) {
    return .{ rect[0], rect[1] };
}

pub inline fn rSize(rect: anytype) @Vector(2, @typeInfo(@TypeOf(rect)).Vector.child) {
    return .{ rect[2], rect[3] };
}

pub inline fn rFromPosAndSize(pos: anytype, size: @TypeOf(pos)) @Vector(4, @typeInfo(@TypeOf(pos)).Vector.child) {
    return .{ pos[0], pos[1], size[0], size[1] };
}

pub inline fn rMoved(rect: anytype, pos_delta: @Vector(2, @typeInfo(@TypeOf(rect)).Vector.child)) @TypeOf(rect) {
    return rFromPosAndSize(rPos(rect) + pos_delta, rSize(rect));
}

pub inline fn rUnit(T: type) @Vector(4, T) {
    return .{ 0, 0, 1, 1 };
}

pub inline fn rCenter(rect: anytype) @Vector(2, @typeInfo(@TypeOf(rect)).Vector.child) {
    return .{ rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0 };
}

pub inline fn rLerpV2(rect: anytype, t: @Vector(2, @typeInfo(@TypeOf(rect)).Vector.child)) @TypeOf(t) {
    return .{
        math.lerp(rect[0], rect[0] + rect[2], t[0]),
        math.lerp(rect[1], rect[1] + rect[3], t[1]),
    };
}

pub inline fn rInset(rect: anytype, amount: @typeInfo(@TypeOf(rect)).Vector.child) @TypeOf(rect) {
    return .{
        rect[0] + amount,
        rect[1] + amount,
        rect[2] - amount * 2,
        rect[3] - amount * 2,
    };
}
