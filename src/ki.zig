const std = @import("std");

pub const c = struct {
    pub const glfw = @import("glfw");
    pub const stb = @import("stb");
    pub const qoi = @import("qoi");
    pub const glad = @import("glad");
    pub const miniaudio = @import("miniaudio");
};

pub const gl = c.glad;

pub const DynArr = @import("dyn_arr.zig").DynArr;

pub const math = @import("math");

pub const Time = @import("time.zig").Time;
pub const Timer = @import("timer.zig").Timer;

pub const ansi = @import("ansi.zig");
pub const utf = @import("utf.zig");
pub const Log = @import("Log.zig");

pub const Window = @import("Window.zig");

pub const Gamepad = @import("Gamepad.zig");

pub const Image = @import("image.zig").Image;
pub const Texture = @import("Texture.zig");
pub const Font = @import("Font.zig");
pub const SpriteBatch = @import("SpriteBatch.zig");
pub const RenderTarget = @import("RenderTarget.zig");

pub const AudioIO = @import("AudioIO.zig").AudioIO;
pub const AudioSource = @import("AudioSource.zig").AudioSource;

pub var log: Log = .{};

test "ki.*" {
    _ = ansi;
}
