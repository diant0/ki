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

pub inline fn rUnit(T: type) @Vector(4, T) {
    return .{ 0, 0, 1, 1 };
}