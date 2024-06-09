const std = @import("std");
const ansi = @import("ansi.zig");
const builtin = @import("builtin");

pub const Severity = enum(u2) {
    Info    = 0,
    Warning = 1,
    Error   = 2,
};

const prefixes_ansi: std.EnumArray(Severity, []const u8) = .{
    .values = [@typeInfo(Severity).Enum.fields.len][]const u8 {
        ansi.color.foreground(.Green)  ++ ansi.style.mode(.Underline) ++ "info"    ++ ansi.style.reset_all ++ ": ",
        ansi.color.foreground(.Yellow) ++ ansi.style.mode(.Underline) ++ "warning" ++ ansi.style.reset_all ++ ": ",
        ansi.color.foreground(.Red)    ++ ansi.style.mode(.Underline) ++ "error"   ++ ansi.style.reset_all ++ ": ",
    },
};

const prefixes_plain: std.EnumArray(Severity, []const u8) = .{
    .values = [@typeInfo(Severity).Enum.fields.len][]const u8 {
        "info: ",
        "warning: ",
        "error: ",
    },
};

out_file: ?std.fs.File = null,
min_severity: Severity = .Info,

disable_ansi: bool = false,

pub fn print(self: *@This(), severity: Severity, comptime fmt: []const u8, args: anytype) void {

    if (self.out_file) | file | {

        if (@intFromEnum(severity) < @intFromEnum(self.min_severity)) {
            return;
        }
        
        const prefixes = if (file.getOrEnableAnsiEscapeSupport()) prefixes_ansi else prefixes_plain;
    
        // not sure if there is a good way to recover here, so just ignore errors
        file.writer().print("{s}", .{ prefixes.get(severity) }) catch {};
        file.writer().print(fmt, args) catch {};

    }

}