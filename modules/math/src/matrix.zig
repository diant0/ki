// TODO: Mat*: research operations
// TODO: Mat*: add
// TODO: Mat*: projections
// TODO: Mat*: rotation

pub fn m4Identity(T: type) @Vector(16, T) {
    return .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
}

pub fn m4Translation(T: type, t: @Vector(3, T)) @Vector(16, T) {
    return .{
        1, 0, 0, t[0],
        0, 1, 0, t[1],
        0, 0, 1, t[2],
        0, 0, 0, 1,
    };
}

pub fn m4Scale(T: type, s: @Vector(3, T)) @Vector(16, T) {
    return .{
        s[0], 0,    0,    0,
        0,    s[1], 0,    0,
        0,    0,    s[2], 0,
        0,    0,    0,    1,
    };
}

pub fn m4Ortho(T: type, l: T, r: T, b: T, t: T, n: T, f: T) @Vector(16, T) {
    return .{
        2 / (r - l),  0,             0,            -(r + l) / (r - l),
        0,            2 / (t - b),   0,            -(t + b) / (t - b),
        0,            0,            -2 / (f - n),  -(f + n) / (f - n),
        0,            0,             0,              1,
    };
}

pub fn m4Mult(T: type, a: @Vector(16, T), b: @Vector(16, T)) @Vector(16, T) {
            
    return .{
        
            a[0]  * b[0]  +  a[1]  * b[4]  +  a[2]  * b[8]   +  a[3]  * b[12],
            a[0]  * b[1]  +  a[1]  * b[5]  +  a[2]  * b[9]   +  a[3]  * b[13],
            a[0]  * b[2]  +  a[1]  * b[6]  +  a[2]  * b[10]  +  a[3]  * b[14],
            a[0]  * b[3]  +  a[1]  * b[7]  +  a[2]  * b[11]  +  a[3]  * b[15],

            a[4]  * b[0]  +  a[5]  * b[4]  +  a[6]  * b[8]   +  a[7]  * b[12],
            a[4]  * b[1]  +  a[5]  * b[5]  +  a[6]  * b[9]   +  a[7]  * b[13],
            a[4]  * b[2]  +  a[5]  * b[6]  +  a[6]  * b[10]  +  a[7]  * b[14],
            a[4]  * b[3]  +  a[5]  * b[7]  +  a[6]  * b[11]  +  a[7]  * b[15],
        
            a[8]  * b[0]  +  a[9]  * b[4]  +  a[10] * b[8]   +  a[11] * b[12],
            a[8]  * b[1]  +  a[9]  * b[5]  +  a[10] * b[9]   +  a[11] * b[13],
            a[8]  * b[2]  +  a[9]  * b[6]  +  a[10] * b[10]  +  a[11] * b[14],
            a[8]  * b[3]  +  a[9]  * b[7]  +  a[10] * b[11]  +  a[11] * b[15],

            a[12] * b[0]  +  a[13] * b[4]  +  a[14] * b[8]   +  a[15] * b[12],
            a[12] * b[1]  +  a[13] * b[5]  +  a[14] * b[9]   +  a[15] * b[13],
            a[12] * b[2]  +  a[13] * b[6]  +  a[14] * b[10]  +  a[15] * b[14],
            a[12] * b[3]  +  a[13] * b[7]  +  a[14] * b[11]  +  a[15] * b[15],

    };

}