// TODO: Mat3: research operations (if even needed)
// TODO: Mat4: research operations
// TODO: Mat*: add / mul
// TODO: Mat*: projections
// TODO: Mat*: translation / rotation / scale

pub inline fn m4Ortho(T: type, l : T, r : T, b : T, t : T, n : T, f : T) @Vector(16, T) {
    return .{
        2 / (r - l),  0,             0,            -(r + l) / (r - l),
        0,            2 / (t - b),   0,            -(t + b) / (t - b),
        0,            0,            -2 / (f - n),  -(f + n) / (f - n),
        0,            0,             0,              1,
    };
}