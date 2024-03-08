const std   = @import("std");
const gl    = @import("gl");
const Image = @import("Image.zig").Image;

pub const Texture = struct {

    id: gl.TextureID,
    size: @Vector(2, u32),
    channels: u32,

    pub const Parameters = struct {
        wrap_hor: gl.Wrap = .ClampToEdge,
        wrap_ver: gl.Wrap = .ClampToEdge,
        filter_min: gl.FilterMin = .Nearest,
        filter_mag: gl.FilterMag = .Nearest,
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

        gl.activeTexture(0);
        texture.id = gl.genTexture();
        errdefer texture.delete();
        gl.bindTexture(.Texture2D, texture.id);

        texture.setWrap(parameters.wrap_hor, parameters.wrap_ver);
        texture.setFilterMin(parameters.filter_min);
        texture.setFilterMag(parameters.filter_mag);

        const internal_format: gl.InternalFormat = switch(ImageComponentT) {

            u8 => switch(image.components_per_pixel) {
                1 => .R8,
                2 => .RG8,
                3 => .RGB8,
                4 => .RGBA8,
                else => return error.UnsupportedImagePixelComponentCount,
            },

            f32 => switch (image.components_per_pixel) {
                1 => .R32F,
                2 => .RG32F,
                3 => .RGB32F,
                4 => .RGBA32F,
                else => return error.UnsupportedImagePixelComponentCount,
            },

            else => return error.UnsupportedImagePixelComponentType,

        };

        const format: gl.Format = switch(image.components_per_pixel) {
            1 => .R,
            2 => .RG,
            3 => .RGB,
            4 => .RGBA,
            else => return error.UnsupportedImagePixelComponentCount,
        };

        const component_type = switch(ImageComponentT) {
            u8  => .U8,
            f32 => .F32,
            else => return error.UnsupportedImagePixelComponentType,
        };

        gl.texImage2D(.Texture2D, 0, internal_format, texture.size[0], texture.size[1],
            format, component_type, @ptrCast(image.data.ptr));

        return texture;

    }

    pub fn delete(self: *const @This()) void {
        gl.deleteTexture(self.id);
    }

    pub fn setWrap(self: *const @This(), wrap_hor: gl.Wrap, wrap_ver: gl.Wrap) void {
        gl.activeTexture(0);
        gl.bindTexture(.Texture2D, self.id);
        gl.texParameter(.Texture2D, .WrapHor, wrap_hor);
        gl.texParameter(.Texture2D, .WrapVer, wrap_ver);
    }

    pub fn setFilterMin(self: *const @This(), filter: gl.FilterMin) void {
        gl.activeTexture(0);
        gl.bindTexture(.Texture2D, self.id);
        gl.texParameter(.Texture2D, .FilterMin, filter);
    }

    pub fn setFilterMag(self: *const @This(), filter: gl.FilterMag) void {
        gl.activeTexture(0);
        gl.bindTexture(.Texture2D, self.id);
        gl.texParameter(.Texture2D, .FilterMag, filter);
    }

};