pub const raw = @import("raw.zig");

// --------------------------------

const gl_bitfield = raw.GLbitfield;

const gl_f32      = raw.GLfloat;

// --------------------------------

pub inline fn load(getProcAddress: *const fn(name: [*:0]const u8) ?*const fn() callconv(.C) void) !void {
    try raw.load(getProcAddress);
}

// --------------------------------

pub inline fn clear(target: ClearTarget) void {
    raw.glClear(@intFromEnum(target));
}

pub const ClearTarget = enum(gl_bitfield) {

    ColorBuffer     = raw.GL_COLOR_BUFFER_BIT,
    DepthBuffer     = raw.GL_DEPTH_BUFFER_BIT,
    StencilBuffer   = raw.GL_STENCIL_BUFFER_BIT,

};

pub inline fn clearColor(color: @Vector(4, gl_f32)) void {
    raw.glClearColor(color[0], color[1], color[2], color[3]);
}

// --------------------------------
