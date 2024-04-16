const std = @import("std");
const ansi = @import("ansi.zig");

pub const Severity = enum(u2) {
    Info    = 0,
    Warning = 1,
    Error   = 2,
};

const prefixes_tty: std.EnumArray(Severity, []const u8) = .{
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

pub var out_file: ?std.fs.File = null;
pub var min_severity: Severity = .Info;

pub fn print(severity: Severity, comptime fmt: []const u8, args: anytype) void {

    if (@intFromEnum(severity) < @intFromEnum(min_severity)) {
        return;
    }

    if (out_file) | file | {
        
        const prefixes = if (file.isTty()) prefixes_tty else prefixes_plain;
    
        file.writer().print("{s}", .{ prefixes.get(severity) }) catch | e | {
            std.debug.print("log.print failed with {s}\n", .{ @errorName(e) });
        };

        file.writer().print(fmt, args) catch {
            std.debug.print("\t{s}: ", .{ @tagName(severity) });
            std.debug.print(fmt, args);
        };

    } else {

        std.debug.print("{s}", .{ prefixes_tty.get(severity) });
        std.debug.print(fmt, args);

    }

}