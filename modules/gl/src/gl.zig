pub const raw = @import("raw.zig");

// --------------------------------

pub const gl_bitfield   = raw.GLbitfield;
pub const gl_enum       = raw.GLenum;

pub const gl_i8         = raw.GLbyte;
pub const gl_u8         = raw.GLubyte;

pub const gl_i32        = raw.GLint;
pub const gl_u32        = raw.GLuint;

pub const gl_sizei      = raw.GLsizei;

pub const gl_f32        = raw.GLfloat;

// --------------------------------

pub const InternalFormat = enum(gl_i32) {
    R8      = raw.GL_R8,
    RG8     = raw.GL_RG8,
    RGB8    = raw.GL_RGB8,
    RGBA8   = raw.GL_RGBA8,
    R32F    = raw.GL_R32F,
    RG32F   = raw.GL_RG32F,
    RGB32F  = raw.GL_RGB32F,
    RGBA32F = raw.GL_RGBA32F,
};

pub const Format = enum(gl_enum) {
    R       = raw.GL_RED,
    RG      = raw.GL_RG,
    RGB     = raw.GL_RGB,
    RGBA    = raw.GL_RGBA,
};

pub const NumericType = enum(gl_enum) {
    U8  = raw.GL_UNSIGNED_BYTE,
    I8  = raw.GL_BYTE,
    U16 = raw.GL_UNSIGNED_SHORT,
    I16 = raw.GL_SHORT,
    U32 = raw.GL_UNSIGNED_INT,
    I32 = raw.GL_INT,
    F32 = raw.GL_FLOAT,
};

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

pub inline fn activeTexture(unit: gl_enum) void {
    raw.glActiveTexture(@as(gl_enum, @intCast(raw.GL_TEXTURE0)) + unit);
}

pub const TextureID = extern struct {
    id: gl_u32,
};

/// requires count to be comptime known, hopefully not a problem in most cases
pub inline fn genTextures(comptime n: usize) [n]TextureID {
    var buffer: [n]TextureID = undefined;
    raw.glGenTextures(@intCast(buffer.len), @ptrCast(&buffer));
    return buffer;
}

pub inline fn genTexture() TextureID {
    return genTextures(1)[0];
}

pub inline fn deleteTextures(ids: []const TextureID) void {
    raw.glDeleteTextures(@intCast(ids.len), @ptrCast(ids.ptr));
}

pub inline fn deleteTexture(id: TextureID) void {
    deleteTextures(&[_]TextureID{id});
}

pub const TextureBindTarget = enum(gl_enum) {

Texture1D                   = raw.GL_TEXTURE_1D,
Texture2D                   = raw.GL_TEXTURE_2D,
Texture3D                   = raw.GL_TEXTURE_3D,
Texture1DArray              = raw.GL_TEXTURE_1D_ARRAY,
Texture2DArray              = raw.GL_TEXTURE_2D_ARRAY,
TextureRectangle            = raw.GL_TEXTURE_RECTANGLE,
TextureCubeMap              = raw.GL_TEXTURE_CUBE_MAP,
TextureCubeMapArray         = raw.GL_TEXTURE_CUBE_MAP_ARRAY,
TextureBuffer               = raw.GL_TEXTURE_BUFFER,
Texture2DMultisample        = raw.GL_TEXTURE_2D_MULTISAMPLE,
Texture2DMultisampleArray   = raw.GL_TEXTURE_2D_MULTISAMPLE_ARRAY,

};

pub inline fn bindTexture(target: TextureBindTarget, id: TextureID) void {
    raw.glBindTexture(@intFromEnum(target), id.id);
}

pub inline fn texImage2D(target: TextureBindTarget, level: gl_i32, internal_format: InternalFormat,
    w: u32, h: u32, format: Format, ctype: NumericType, data: *const anyopaque) void {
    raw.glTexImage2D(@intFromEnum(target), level, @intFromEnum(internal_format),
        @intCast(w), @intCast(h), 0, @intFromEnum(format), @intFromEnum(ctype), data);
}

pub const TexParameter = enum(gl_enum) {

    WrapHor     = raw.GL_TEXTURE_WRAP_S,
    WrapVer     = raw.GL_TEXTURE_WRAP_T,
    FilterMin   = raw.GL_TEXTURE_MIN_FILTER,
    FilterMag   = raw.GL_TEXTURE_MAG_FILTER,

    pub fn Value(self: @This()) type {

        return switch(self) {
            .WrapHor, .WrapVer => Wrap,
            .FilterMin => FilterMin,
            .FilterMag => FilterMag,
        };

    }

};

pub const Wrap = enum(gl_i32) {
    ClampToEdge         = raw.GL_CLAMP_TO_EDGE,
    ClampToBorder       = raw.GL_CLAMP_TO_BORDER,
    Repat               = raw.GL_REPEAT,
    MirroredRepeat      = raw.GL_MIRRORED_REPEAT,
    MirrorClampToEdge   = raw.GL_MIRROR_CLAMP_TO_EDGE,
};

pub const FilterMin = enum(gl_i32) {
    Nearest                 = raw.GL_NEAREST,
    Linear                  = raw.GL_LINEAR,
    NearestMipmapNearest    = raw.GL_NEAREST_MIPMAP_NEAREST,
    LinearMipmapNearest     = raw.GL_LINEAR_MIPMAP_NEAREST,
    NearestMipmapLinear     = raw.GL_NEAREST_MIPMAP_LINEAR,
    LinearMipmapLinear      = raw.GL_LINEAR_MIPMAP_LINEAR,
};

pub const FilterMag = enum(gl_i32) {
    Nearest     = raw.GL_NEAREST,
    Linear      = raw.GL_LINEAR,
};

pub fn texParameter(target: TextureBindTarget, comptime parameter: TexParameter, value: parameter.Value()) void {
    raw.glTexParameteri(@intFromEnum(target), @intFromEnum(parameter), @intFromEnum(value));
}