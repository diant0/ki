const std = @import("std");

pub const c = struct {
    pub const glfw = @import("glfw");
    pub const stb = @import("stb");
    pub const qoi = @import("qoi");
    pub const glad = @import("glad");
    pub const miniaudio = @import("miniaudio");
};

pub const gl = c.glad;

pub const DynArr = @import("DynArr.zig").DynArr;

pub const math  = @import("math");

pub const Time = @import("Time.zig").Time;

pub const ansi  = @import("ansi.zig");
pub const utf   = @import("utf.zig");
pub const Log   = @import("Log.zig").Log;

pub const Window = @import("Window.zig").Window;

pub const Gamepad       = @import("Gamepad.zig").Gamepad;

pub const Image         = @import("Image.zig").Image;
pub const Texture       = @import("Texture.zig").Texture;
pub const Font          = @import("Font.zig").Font;
pub const SpriteBatch   = @import("SpriteBatch.zig").SpriteBatch;
pub const RenderTarget  = @import("RenderTarget.zig").RenderTarget;

pub const AudioIO       = @import("AudioIO.zig").AudioIO;
pub const AudioSource   = @import("AudioSource.zig").AudioSource;

pub const log = @import("log.zig");

test "ki.*" {
    _ = ansi;
}
