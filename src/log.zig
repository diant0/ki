const Log = @import("Log.zig").Log;

pub var instance: Log = .{};

pub inline fn print(severity: Log.Severity, comptime fmt: []const u8, args: anytype) void {
    instance.print(severity, fmt, args);
}