const std = @import("std");

pub fn Time(comptime T: type) type {
    if (@typeInfo(T) != .Float) {
        @compileError("ki.time.Time: only runtime floats make sense as a subtype");
    }

    return struct {
        const TimestampT = @typeInfo(@TypeOf(std.time.nanoTimestamp)).Fn.return_type.?;

        prev_ts: TimestampT = undefined,

        total: T = 0.0,
        delta: T = 0.0,

        scaled: struct {
            paused: bool = false,
            scale: T = 1.0,

            total: T = 0.0,
            delta: T = 0.0,
        } = .{},

        pub fn init(self: *@This()) void {
            self.delta = 0.0;
            self.total = 0.0;
            self.scaled.delta = 0.0;
            self.scaled.total = 0.0;

            self.prev_ts = std.time.nanoTimestamp();
        }

        pub fn update(self: *@This()) void {
            const current_ts = std.time.nanoTimestamp();

            self.delta = @as(T, @floatFromInt(current_ts - self.prev_ts)) / std.time.ns_per_s;
            self.total += self.delta;

            if (!self.scaled.paused) {
                self.scaled.delta = self.delta * self.scaled.scale;
                self.scaled.total += self.scaled.delta;
            }

            self.prev_ts = current_ts;
        }
    };
}
