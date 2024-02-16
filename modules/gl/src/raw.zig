pub const h = @cImport({
    @cInclude("GL/gl.h");
});

// --------------------------------

pub const GLbitfield    = h.GLbitfield;
pub const GLenum        = h.GLenum;

pub const GLbyte        = h.GLbyte;
pub const GLubyte       = h.GLubyte;

pub const GLfloat       = h.GLfloat;

// --------------------------------

pub var glClear: *const fn(mask: GLbitfield) callconv(.C) void = undefined;

// mask
pub const GL_COLOR_BUFFER_BIT   = h.GL_COLOR_BUFFER_BIT;
pub const GL_DEPTH_BUFFER_BIT   = h.GL_DEPTH_BUFFER_BIT;
pub const GL_STENCIL_BUFFER_BIT = h.GL_STENCIL_BUFFER_BIT;


pub var glClearColor: *const fn(r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat) callconv(.C) void = undefined;

// --------------------------------

pub var glGetString: *const fn(name: GLenum) [*:0]const GLubyte = undefined;

pub const GL_VENDOR                     = h.GL_VENDOR;
pub const GL_RENDERER                   = h.GL_RENDERER;
pub const GL_VERSION                    = h.GL_VERSION;
pub const GL_SHADING_LANGUAGE_VERSION   = h.GL_SHADING_LANGUAGE_VERSION;

// --------------------------------

pub inline fn load(getProcAddress: *const fn(name: [*:0]const u8) ?*const fn() callconv(.C) void) !void {

    glClear         = @ptrCast(getProcAddress("glClear")        orelse return error.getProcAddress_glClear);
    glClearColor    = @ptrCast(getProcAddress("glClearColor")   orelse return error.getProcAddress_glClearColor);
    glGetString     = @ptrCast(getProcAddress("glGetString")    orelse return error.getProcAddress_glGetString);

}