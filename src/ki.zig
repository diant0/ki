const std = @import("std");

pub const c = struct {

    pub const glfw  = @import("glfw");
    pub const stb   = @import("stb");
    pub const qoi   = @import("qoi");
    pub const glad  = @import("glad");
    pub const miniaudio = @import("miniaudio");

};

pub const DynArr = @import("DynArr.zig").DynArr;

pub const math  = @import("math");

pub const Time = @import("time/Time.zig").Time;

pub const ansi  = @import("ansi.zig");
pub const utf   = @import("utf.zig");
pub const log   = @import("log.zig");

pub const Window = @import("Window.zig").Window;
pub const gl     = c.glad;

pub const Gamepad       = @import("Gamepad.zig").Gamepad;

pub const Image         = @import("rendering/Image.zig").Image;
pub const Texture       = @import("rendering/Texture.zig").Texture;
pub const Font          = @import("rendering/Font.zig").Font;
pub const SpriteBatch   = @import("rendering/SpriteBatch.zig").SpriteBatch;
pub const RenderTarget  = @import("rendering/RenderTarget.zig").RenderTarget;

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