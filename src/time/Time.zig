const std = @import("std");

pub fn Time(comptime T: type) type {

    if (@typeInfo(T) != .Float) {
        @compileError("ki.time.Time: only runtime floats make sense as a subtype");
    }

    return struct {

        const TimestampT = @typeInfo(@TypeOf(std.time.nanoTimestamp)).Fn.return_type.?;

        prev_ts: TimestampT = undefined,

        scale: T = 1.0,

        dt:  T = 0.0,
        t:   T = 0.0,

        sdt: T = 0.0,
        st:  T = 0.0,

        pub fn init(self: *@This()) void {

            self.dt  = 0.0;
            self.t   = 0.0;
            self.sdt = 0.0;
            self.st  = 0.0;

            self.prev_ts = std.time.nanoTimestamp();

        }

        pub fn update(self: *@This()) void {

            const current_ts = std.time.nanoTimestamp();

            self.dt  = @as(T, @floatFromInt(current_ts - self.prev_ts)) / std.time.ns_per_s;
            self.t  += self.dt;

            self.sdt = self.dt * self.scale;
            self.st += self.sdt;

            self.prev_ts = current_ts;

        }

    };

}