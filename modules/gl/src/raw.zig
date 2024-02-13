pub const h = @cImport({
    @cInclude("GL/gl.h");
});

// --------------------------------

pub const GLbitfield    = h.GLbitfield;

pub const GLfloat       = h.GLfloat;

// --------------------------------

pub var glClear: *const fn(mask: GLbitfield) callconv(.C) void = undefined;

// mask
pub const GL_COLOR_BUFFER_BIT   = h.GL_COLOR_BUFFER_BIT;
pub const GL_DEPTH_BUFFER_BIT   = h.GL_DEPTH_BUFFER_BIT;
pub const GL_STENCIL_BUFFER_BIT = h.GL_STENCIL_BUFFER_BIT;


pub var glClearColor: *const fn(r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat) callconv(.C) void = undefined;

// --------------------------------

pub inline fn load(getProcAddress: *const fn(name: [*:0]const u8) ?*const fn() callconv(.C) void) !void {

    glClear         = @ptrCast(getProcAddress("glClear")        orelse return error.getProcAddress_glClear);
    glClearColor    = @ptrCast(getProcAddress("glClearColor")   orelse return error.getProcAddress_glClearColor);

}