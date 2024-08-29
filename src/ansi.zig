const std = @import("std");
const math = @import("math");

// https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797

// TODO? runtime mechanism for arguments

pub const escape = "\x1b";

pub const cursor = struct {
    pub const home = escape ++ "[H";

    pub fn to(comptime line_opt: ?usize, comptime col: usize) []const u8 {
        if (line_opt) |line| {
            return escape ++ std.fmt.comptimePrint("[{};{}H", .{ line, col });
        }

        return escape ++ std.fmt.comptimePrint("[{}G", .{col});
    }

    pub fn move(comptime amount: @Vector(2, isize)) []const u8 {
        comptime var sequence: []const u8 = "";

        if (amount[0] != 0) {
            if (amount[0] < 0) {
                sequence = sequence ++ escape ++ std.fmt.comptimePrint("[{}D", .{-amount[0]});
            } else {
                sequence = sequence ++ escape ++ std.fmt.comptimePrint("[{}C", .{amount[0]});
            }
        }

        if (amount[1] != 0) {
            if (amount[1] < 0) {
                sequence = sequence ++ escape ++ std.fmt.comptimePrint("[{}B", .{-amount[1]});
            } else {
                sequence = sequence ++ escape ++ std.fmt.comptimePrint("[{}A", .{amount[1]});
            }
        }

        return sequence;
    }

    pub const save_dec = escape ++ " 7";
    pub const restore_dec = escape ++ " 8";

    pub const save_sco = escape ++ "[s";
    pub const restore_sco = escape ++ "[u";
};

pub const erase = struct {
    pub const in_display = escape ++ "[J";
    pub const from_cursor_to_end_of_screen = escape ++ "[0J";
    pub const from_start_of_screen_to_cursor = escape ++ "[1J";
    pub const entire_screen = escape ++ "[2J";
    pub const saved_lines = escape ++ "[3J";
    pub const in_line = escape ++ "[K";
    pub const from_cursor_to_end_of_line = escape ++ "[0K";
    pub const from_start_of_line_to_cursor = escape ++ "[1K";
    pub const entire_line = escape ++ "[2K";
};

pub const style = struct {
    pub const Mode = enum {
        Bold,
        Dim,
        Italic,
        Underline,
        Blinking,
        Reverse,
        Invisible,
        Strikethrough,
    };

    pub const reset_all = escape ++ "[0m";

    pub fn mode(comptime m: Mode) []const u8 {
        return switch (m) {
            .Bold => escape ++ "[1m",
            .Dim => escape ++ "[2m",
            .Italic => escape ++ "[3m",
            .Underline => escape ++ "[4m",
            .Blinking => escape ++ "[5m",
            .Reverse => escape ++ "[7m",
            .Invisible => escape ++ "[8m",
            .Strikethrough => escape ++ "[9m",
        };
    }

    pub fn reset(comptime m: Mode) []const u8 {
        return switch (m) {
            .Bold => escape ++ "[22m",
            .Dim => escape ++ "[22m",
            .Italic => escape ++ "[23m",
            .Underline => escape ++ "[24m",
            .Blinking => escape ++ "[25m",
            .Reverse => escape ++ "[27m",
            .Invisible => escape ++ "[28m",
            .Strikethrough => escape ++ "[29m",
        };
    }
};

pub const color = struct {
    pub const Color = enum {
        Black,
        Red,
        Green,
        Yellow,
        Blue,
        Magenta,
        Cyan,
        White,
        Default,
    };

    pub fn foreground(comptime c: Color) []const u8 {
        return switch (c) {
            .Black => escape ++ "[30m",
            .Red => escape ++ "[31m",
            .Green => escape ++ "[32m",
            .Yellow => escape ++ "[33m",
            .Blue => escape ++ "[34m",
            .Magenta => escape ++ "[35m",
            .Cyan => escape ++ "[36m",
            .White => escape ++ "[37m",
            .Default => escape ++ "[39m",
        };
    }

    pub fn background(comptime c: Color) []const u8 {
        return switch (c) {
            .Black => escape ++ "[40m",
            .Red => escape ++ "[41m",
            .Green => escape ++ "[42m",
            .Yellow => escape ++ "[43m",
            .Blue => escape ++ "[44m",
            .Magenta => escape ++ "[45m",
            .Cyan => escape ++ "[46m",
            .White => escape ++ "[47m",
            .Default => escape ++ "[49m",
        };
    }

    pub fn foreground256(comptime c: u8) []const u8 {
        return escape ++ std.fmt.comptimePrint("[38;5;{}m", .{c});
    }

    pub fn background256(comptime c: u8) []const u8 {
        return escape ++ std.fmt.comptimePrint("[48;5;{}m", .{c});
    }

    pub fn foregroundRGB(comptime c: @Vector(3, u8)) []const u8 {
        return escape ++ std.fmt.comptimePrint("[38;2;{};{};{}m", .{ c[0], c[1], c[2] });
    }

    pub fn backgroundRGB(comptime c: @Vector(3, u8)) []const u8 {
        return escape ++ std.fmt.comptimePrint("[48;2;{};{};{}m", .{ c[0], c[1], c[2] });
    }
};

test "comptime ki.ansi.*" {

    // just ref everything

    _ = comptime cursor.to(null, 3);
    _ = comptime cursor.to(5, 4);

    _ = comptime cursor.move(.{ 3, -3 });

    _ = comptime style.mode(.Strikethrough);
    _ = comptime style.reset(.Strikethrough);

    _ = comptime color.foreground(.Black);
    _ = comptime color.background(.Red);

    _ = comptime color.foreground256(33);
    _ = comptime color.background256(200);

    _ = comptime color.foregroundRGB(.{ 33, 66, 99 });
    _ = comptime color.backgroundRGB(.{ 99, 66, 33 });
}
