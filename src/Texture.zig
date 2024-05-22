const std   = @import("std");
const math  = @import("math");
const gl    = @import("glad");
const Image = @import("Image.zig").Image;

pub const Texture = struct {

    id: gl.GLuint           = math.maxValue(gl.GLuint),
    size: @Vector(2, u32)   = @splat(0),
    channels: u32           = 0,

    pub const Parameters = struct {
        wrap_hor: Wrap = .ClampToEdge,
        wrap_ver: Wrap = .ClampToEdge,
        filter_min: FilterMin = .Nearest,
        filter_mag: FilterMag = .Nearest,
        generate_mipmaps: bool = false,
    };

    /// image argument should be either Image(u8) or Image(f32)
    pub fn fromImage(image: anytype, parameters: Parameters) !@This() {

        const ImageT = @TypeOf(image);
        switch (ImageT) {
            Image(u8), Image(f32) => {},
            else => @compileError("Texture.fromImage(): unsupported type of image argument"),
        }
        const ImageComponentT = @TypeOf(image.data[0]);

        var texture: @This() = undefined;
        texture.size = image.size;

        gl.glGenTextures(1, &texture.id);
        errdefer texture.free();
        gl.glActiveTexture(gl.GL_TEXTURE0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture.id);

        const internal_format: gl.GLint = switch(ImageComponentT) {

            u8 => switch(image.components_per_pixel) {
                1 => gl.GL_R8,
                2 => gl.GL_RG8,
                3 => gl.GL_RGB8,
                4 => gl.GL_RGBA8,
                else => return error.UnsupportedImagePixelComponentCount,
            },

            f32 => switch (image.components_per_pixel) {
                1 => gl.GL_R32F,
                2 => gl.GL_RG32F,
                3 => gl.GL_RGB32F,
                4 => gl.GL_RGBA32F,
                else => return error.UnsupportedImagePixelComponentCount,
            },

            else => return error.UnsupportedImagePixelComponentType,

        };

        const format: gl.GLenum = switch(image.components_per_pixel) {
            1 => gl.GL_RED,
            2 => gl.GL_RG,
            3 => gl.GL_RGB,
            4 => gl.GL_RGBA,
            else => return error.UnsupportedImagePixelComponentCount,
        };

        const component_type = switch(ImageComponentT) {
            u8  => gl.GL_UNSIGNED_BYTE,
            f32 => gl.GL_FLOAT,
            else => return error.UnsupportedImagePixelComponentType,
        };

        gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, internal_format, @intCast(texture.size[0]), @intCast(texture.size[1]),
            0, format, component_type, @ptrCast(image.data));

        texture.setWrap(parameters.wrap_hor, parameters.wrap_ver);
        texture.setFilterMin(parameters.filter_min);
        texture.setFilterMag(parameters.filter_mag);
        
        if (parameters.generate_mipmaps) {
            texture.generateMipmaps();
        }
        
        return texture;

    }

    pub fn free(self: *const @This()) void {
        gl.glDeleteTextures(1, &self.id);
    }

    pub const Wrap = enum(gl.GLint) {
        ClampToEdge         = gl.GL_CLAMP_TO_EDGE,
        ClampToBorder       = gl.GL_CLAMP_TO_BORDER,
        MirroredRepeat      = gl.GL_MIRRORED_REPEAT,
        Repeat              = gl.GL_REPEAT,
        MirrorClampToEdge   = gl.GL_MIRROR_CLAMP_TO_EDGE,
    };

    pub fn setWrap(self: *const @This(), wrap_hor: Wrap, wrap_ver: Wrap) void {
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.id);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, @intFromEnum(wrap_hor));
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, @intFromEnum(wrap_ver));
    }

    pub const FilterMin = enum(gl.GLint) {
        Nearest                 = gl.GL_NEAREST,
        Linear                  = gl.GL_LINEAR,
        NearestMipmapNearest    = gl.GL_NEAREST_MIPMAP_NEAREST,
        LinearMipmapNearest     = gl.GL_LINEAR_MIPMAP_NEAREST,
        NearestMipmapLinear     = gl.GL_NEAREST_MIPMAP_LINEAR,
        LinearMipmapLinear      = gl.GL_LINEAR_MIPMAP_LINEAR, 
    };

    pub fn setFilterMin(self: *const @This(), filter: FilterMin) void {
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.id);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, @intFromEnum(filter));
    }

    pub const FilterMag = enum(gl.GLint) {
        Nearest = gl.GL_NEAREST,
        Linear  = gl.GL_LINEAR,
    };

    pub fn setFilterMag(self: *const @This(), filter: FilterMag) void {
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.id);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, @intFromEnum(filter));
    }
    
    pub fn generateMipmaps(self: *const @This()) void {
        gl.glGenerateTextureMipmap(self.id);
    }

};