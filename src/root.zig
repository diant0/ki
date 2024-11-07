const std = @import("std");

pub fn printMessage(message: []const u8) void {
    std.debug.print("{s}\n", .{message});
}
