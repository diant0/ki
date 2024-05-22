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

pub const Time = @import("time/Time.zig").Time;

pub const ansi  = @import("ansi.zig");
pub const utf   = @import("utf.zig");
pub const Log   = @import("Log.zig").Log;

pub const Window = @import("Window.zig").Window;

pub const Gamepad       = @import("Gamepad.zig").Gamepad;

pub const Image         = @import("rendering/Image.zig").Image;
pub const Texture       = @import("rendering/Texture.zig").Texture;
pub const Font          = @import("rendering/Font.zig").Font;
pub const SpriteBatch   = @import("rendering/SpriteBatch.zig").SpriteBatch;
pub const RenderTarget  = @import("rendering/RenderTarget.zig").RenderTarget;

pub const AudioIO       = @import("audio/AudioIO.zig").AudioIO;
pub const AudioSource   = @import("audio/AudioSource.zig").AudioSource;

pub const log = @import("log.zig");

test "ki.*" {
    _ = ansi;
}
