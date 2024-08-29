const math = @import("module.zig");

// TODO: exponential easing

pub const Easing = enum {
    None,
    SineIn,
    SineOut,
    SineInOut,
    QuadIn,
    QuadOut,
    QuadInOut,
    CubicIn,
    CubicOut,
    CubicInOut,
    QuartIn,
    QuartOut,
    QuartInOut,
    QuintIn,
    QuintOut,
    QuintInOut,
    CircIn,
    CircOut,
    CircInOut,
};

pub fn ease(n: anytype, comptime easing: Easing) @TypeOf(n) {
    return switch (easing) {
        .None => n,

        .SineIn => 1.0 - math.cos((n * math.pi) / 2.0),
        .SineOut => math.sin((n * math.pi) / 2.0),
        .SineInOut => -(math.cos(n * math.pi) - 1.0) / 2.0,

        .QuadIn => math.pow(n, 2),
        .QuadOut => 1.0 - math.pow(1.0 - n, 2),
        .QuadInOut => if (n < 0.5) 2.0 * math.pow(n, 2) else 1.0 - math.pow(-2.0 * n + 2.0, 2) / 2.0,

        .CubicIn => math.pow(n, 3),
        .CubicOut => 1.0 - math.pow(1.0 - n, 3),
        .CubicInOut => if (n < 0.5) 4.0 * math.pow(n, 3) else 1.0 - math.pow(-2.0 * n + 2.0, 3) / 2.0,

        .QuartIn => math.pow(n, 4),
        .QuartOut => 1.0 - math.pow(1.0 - n, 4),
        .QuartInOut => if (n < 0.5) 8 * math.pow(n, 4) else 1.0 - math.pow(-2.0 * n + 2.0, 4) / 2.0,

        .QuintIn => math.pow(n, 5),
        .QuintOut => 1.0 - math.pow(1.0 - n, 5),
        .QuintInOut => if (n < 0.5) 16 * math.pow(n, 5) else 1.0 - math.pow(-2.0 * n + 2.0, 5) / 2.0,

        .CircIn => 1.0 - math.sqrt(1.0 - math.pow(n, 2)),
        .CircOut => math.sqrt(1.0 - math.pow(n - 1.0, 2)),
        .CircInOut => if (n < 0.5) (1.0 - math.sqrt(1.0 - math.pow(n * 2, 2))) / 2.0 else (math.sqrt(1.0 - math.pow(-2.0 * n + 2.0, 2)) + 1.0) / 2.0,
    };
}

test "math.easing.ease" {
    inline for (@typeInfo(Easing).Enum.fields) |enum_field| {
        const enum_value: Easing = @enumFromInt(enum_field.value);

        const values32 = [6]f32{ 0.0, 0.2, 0.4, 0.6, 0.8, 1.0 };
        const values64 = [6]f64{ 0.0, 0.2, 0.4, 0.6, 0.8, 1.0 };

        for (values32) |value| {
            _ = ease(value, enum_value);
        }

        for (values64) |value| {
            _ = ease(value, enum_value);
        }
    }
}
