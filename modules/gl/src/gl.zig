pub const raw = @import("raw.zig");

// --------------------------------

pub const gl_bitfield   = raw.GLbitfield;
pub const gl_enum       = raw.GLenum;

pub const gl_i8         = raw.GLbyte;
pub const gl_u8         = raw.GLubyte;

pub const gl_f32        = raw.GLfloat;

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

pub inline fn getString(name: GetStringTarget) [*:0]const gl_u8 {
    return raw.glGetString(@intFromEnum(name));
}

pub const GetStringTarget = enum(gl_enum) {

    Vendor          = raw.GL_VENDOR,
    Renderer        = raw.GL_RENDERER,
    Version         = raw.GL_VERSION,
    GLSLVersion     = raw.GL_SHADING_LANGUAGE_VERSION,

};

// --------------------------------
