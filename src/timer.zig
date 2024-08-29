const math = @import("math");

pub fn Timer(T: type) type {
    return struct {
        timeout_time: T,
        time_left: T = 0,

        active: bool = false,
        looping: bool = false,

        timeouts_last_update: usize = 0,

        pub fn reset(self: *@This()) void {
            self.time_left = self.timeout_time;
        }

        pub fn update(self: *@This(), advance_time: T) void {
            self.timeouts_last_update = 0;
            self.time_left -= advance_time;
            while (self.time_left > 0) {
                self.time_left += self.timeout_time;
                self.timeouts_last_update += 1;
            }
        }

        pub fn progress(self: *const @This()) T {
            return math.clamp(self.timeout_time / self.time_left, 0, 1);
        }
    };
}
