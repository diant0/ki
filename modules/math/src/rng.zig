const std = @import("std");

const RandT = std.rand.DefaultPrng;

var rng: RandT = RandT.init(123456789);

pub fn seed(s: u64) void {
    rng = RandT.init(s);
}

pub fn random(comptime T: type) T {

    return switch(@typeInfo(T)) {

        .Bool  => rng.random().boolean(),
        .Int   => rng.random().int(T),
        .Float => rng.random().float(T),

        else => @compileError("no random generation for type " ++ @typeName(T)),

    };

}

test "math.rng" {

    seed(987654321);

    _ = random(bool);
    _ = random(u32);
    _ = random(f64);

}