const math = @import("math.zig");

// TODO: multidimensional
// TODO: voronoi/worley

pub fn white(v: anytype) @TypeOf(v) {

    if (@typeInfo(@TypeOf(v)) != .Float and @typeInfo(@TypeOf(v)) != .ComptimeFloat)
        @compileError("math.noise.white: only float types allowed");

    return math.fract(math.sin(v) * 987654.321);

}

pub fn value(v: anytype, octaves: usize, scale: @TypeOf(v), pscroll: @TypeOf(v), comptime interpolation_easing: math.Easing) @TypeOf(v) {

    var coord = (v + pscroll) * scale;

    var value_scale: @TypeOf(v) = 1.0;
    var value_max: @TypeOf(v) = 0.0;
    var i: usize = 0;

    var result: @TypeOf(v) = 0.0;
    while (i < octaves) : (i += 1) {
        value_max += value_scale;
        result += math.lerp(white(math.floor(coord)), white(math.ceil(coord)), math.ease(math.fract(coord), interpolation_easing)) * value_scale;
        value_scale *= 0.5;
        coord *= 2.0;
    }

    return result / value_max;

}

test "math.noise" {

    _ = white(3.3);
    _ = white(@as(f32, 4.2));
    
    _ = value(4.4, 4, 2.0, 420.0, .None);
    _ = value(@as(f64, 4.4), 4, 2.0, 420.0, .CubicInOut);

}