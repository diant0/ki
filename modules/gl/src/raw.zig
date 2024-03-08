pub const h = @cImport({
    @cInclude("GL/gl.h");
});

// --------------------------------

pub const GLbitfield    = h.GLbitfield;
pub const GLenum        = h.GLenum;

pub const GLbyte        = h.GLbyte;
pub const GLubyte       = h.GLubyte;

pub const GLint         = h.GLint;
pub const GLuint        = h.GLuint;

pub const GLsizei       = h.GLsizei;

pub const GLfloat       = h.GLfloat;

// --------------------------------

pub const GL_R8         = h.GL_R8;
pub const GL_RG8        = h.GL_RG8;
pub const GL_RGB8       = h.GL_RGB8;
pub const GL_RGBA8      = h.GL_RGBA8;
pub const GL_R32F       = h.GL_R32F;
pub const GL_RG32F      = h.GL_RG32F;
pub const GL_RGB32F     = h.GL_RGB32F;
pub const GL_RGBA32F    = h.GL_RGBA32F;

pub const GL_RED        = h.GL_RED;
pub const GL_RG         = h.GL_RG;
pub const GL_RGB        = h.GL_RGB;
pub const GL_RGBA       = h.GL_RGBA;

pub const GL_UNSIGNED_BYTE  = h.GL_UNSIGNED_BYTE;
pub const GL_BYTE           = h.GL_BYTE;
pub const GL_UNSIGNED_SHORT = h.GL_UNSIGNED_SHORT;
pub const GL_SHORT          = h.GL_SHORT;
pub const GL_UNSIGNED_INT   = h.GL_UNSIGNED_INT;
pub const GL_INT            = h.GL_INT;
pub const GL_FLOAT          = h.GL_FLOAT;

// --------------------------------

pub var glClear: *const fn(mask: GLbitfield) callconv(.C) void = undefined;

// mask
pub const GL_COLOR_BUFFER_BIT   = h.GL_COLOR_BUFFER_BIT;
pub const GL_DEPTH_BUFFER_BIT   = h.GL_DEPTH_BUFFER_BIT;
pub const GL_STENCIL_BUFFER_BIT = h.GL_STENCIL_BUFFER_BIT;


pub var glClearColor: *const fn(r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat) callconv(.C) void = undefined;

// --------------------------------

pub const GL_TEXTURE0               = h.GL_TEXTURE0;

pub var glActiveTexture: *const fn(texture: GLenum) callconv(.C) void = undefined;
pub var glGenTextures: *const fn(n: GLsizei, textures: [*c]const GLuint) callconv(.C) void = undefined;
pub var glDeleteTextures: *const fn(n: GLsizei, textures: [*c]const GLuint) callconv(.C) void = undefined;

pub const GL_TEXTURE_1D                     = h.GL_TEXTURE_1D;
pub const GL_TEXTURE_2D                     = h.GL_TEXTURE_2D;
pub const GL_TEXTURE_3D                     = h.GL_TEXTURE_3D;
pub const GL_TEXTURE_1D_ARRAY               = h.GL_TEXTURE_1D_ARRAY;
pub const GL_TEXTURE_2D_ARRAY               = h.GL_TEXTURE_2D_ARRAY;
pub const GL_TEXTURE_RECTANGLE              = h.GL_TEXTURE_RECTANGLE;
pub const GL_TEXTURE_CUBE_MAP               = h.GL_TEXTURE_CUBE_MAP;
pub const GL_TEXTURE_CUBE_MAP_ARRAY         = h.GL_TEXTURE_CUBE_MAP_ARRAY;
pub const GL_TEXTURE_BUFFER                 = h.GL_TEXTURE_BUFFER;
pub const GL_TEXTURE_2D_MULTISAMPLE         = h.GL_TEXTURE_2D_MULTISAMPLE;
pub const GL_TEXTURE_2D_MULTISAMPLE_ARRAY   = h.GL_TEXTURE_2D_MULTISAMPLE_ARRAY;

pub var glBindTexture: *const fn(target: GLenum, texture: GLuint) callconv(.C) void = undefined;
pub var glTexImage2D: *const fn(target: GLenum, level: GLint, internal_format: GLint,
    width: GLsizei, height: GLsizei, border: GLint, format: GLenum, ctype: GLenum, data: *const anyopaque)
    callconv(.C) void = undefined;

pub const GL_TEXTURE_WRAP_S         = h.GL_TEXTURE_WRAP_S;
pub const GL_TEXTURE_WRAP_T         = h.GL_TEXTURE_WRAP_T;
pub const GL_TEXTURE_MIN_FILTER     = h.GL_TEXTURE_MIN_FILTER;
pub const GL_TEXTURE_MAG_FILTER     = h.GL_TEXTURE_MAG_FILTER;

pub const GL_CLAMP_TO_EDGE          = h.GL_CLAMP_TO_EDGE;
pub const GL_CLAMP_TO_BORDER        = h.GL_CLAMP_TO_BORDER;
pub const GL_REPEAT                 = h.GL_REPEAT;
pub const GL_MIRRORED_REPEAT        = h.GL_MIRRORED_REPEAT;
pub const GL_MIRROR_CLAMP_TO_EDGE   = h.GL_MIRROR_CLAMP_TO_EDGE;

pub const GL_NEAREST                = h.GL_NEAREST;
pub const GL_LINEAR                 = h.GL_LINEAR;
pub const GL_NEAREST_MIPMAP_NEAREST = h.GL_NEAREST_MIPMAP_NEAREST;
pub const GL_LINEAR_MIPMAP_NEAREST  = h.GL_LINEAR_MIPMAP_NEAREST;
pub const GL_NEAREST_MIPMAP_LINEAR  = h.GL_NEAREST_MIPMAP_LINEAR;
pub const GL_LINEAR_MIPMAP_LINEAR   = h.GL_LINEAR_MIPMAP_LINEAR;

pub var glTexParameteri: *const fn(target: GLenum, pname: GLenum, value: GLint) callconv(.C) void = undefined;

// --------------------------------

pub var glGetString: *const fn(name: GLenum) [*:0]const GLubyte = undefined;

pub const GL_VENDOR                     = h.GL_VENDOR;
pub const GL_RENDERER                   = h.GL_RENDERER;
pub const GL_VERSION                    = h.GL_VERSION;
pub const GL_SHADING_LANGUAGE_VERSION   = h.GL_SHADING_LANGUAGE_VERSION;

// --------------------------------

pub inline fn load(getProcAddress: *const fn(name: [*:0]const u8) ?*const fn() callconv(.C) void) !void {

    glClear             = @ptrCast(getProcAddress("glClear")            orelse return error.getProcAddress_glClear);
    glClearColor        = @ptrCast(getProcAddress("glClearColor")       orelse return error.getProcAddress_glClearColor);
    glGetString         = @ptrCast(getProcAddress("glGetString")        orelse return error.getProcAddress_glGetString);

    glActiveTexture     = @ptrCast(getProcAddress("glActiveTexture")    orelse return error.getProcAddress_glActiveTexture);
    glGenTextures       = @ptrCast(getProcAddress("glGenTextures")      orelse return error.getProcAddress_glGenTextures);
    glDeleteTextures    = @ptrCast(getProcAddress("glDeleteTextures")   orelse return error.getProcAddress_glDeleteTextures);
    glBindTexture       = @ptrCast(getProcAddress("glBindTexture")      orelse return error.getProcAddress_glBindTexture);
    glTexImage2D        = @ptrCast(getProcAddress("glTexImage2D")       orelse return error.getProcAddress_glTexImage2D);
    glTexParameteri     = @ptrCast(getProcAddress("glTexParameteri")    orelse return error.getProcAddress_glTexParameteri);

}