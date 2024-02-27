const std = @import("std");

pub const c = struct {

    pub const glfw  = @import("glfw");
    pub const stb   = @import("stb");

};

pub const math  = @import("math");
pub const gl    = @import("gl");

pub const time = struct {
    pub const Time = @import("time/Time.zig").Time;
};

pub const ansi  = @import("ansi.zig");
pub const log   = @import("log.zig");

pub const Window = @import("window.zig").Window;

pub const Image = @import("rendering/Image.zig").Image;

pub const Version = struct {

    major: u32,
    minor: u32,
    patch: u32,

};

pub fn version() Version {

    return .{
        .major = 0,
        .minor = 0,
        .patch = 0,
    };

}

test "ki.*" {

    _ = ansi;

}