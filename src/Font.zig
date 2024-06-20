const std       = @import("std");
const stbtt     = @import("stb").truetype;
const utf       = @import("utf.zig");
const Image     = @import("image.zig").Image;
const Texture   = @import("Texture.zig");

pub const default_charset = " abcdefghijklmnopqrstuvxyzABCDEFGHIJKLMNOPQRSTUVXYZ1234567890<>{}[]()-_=+*/|\\*&^%$#@?.,:;!~`\"'";

pub const Parameters = struct {

    line_height: f32,

    charset: union(enum) {
        codepoints: []const utf.Codepoint,
        utf8: []const u8,
    } = .{ .utf8 = default_charset },

    atlas_width: i32 = 1024,
    atlas_padding: i32 = 8,

    make_texture_on_init: bool = true,
    free_image_after_init: bool = true,
    atlas_texture_parameters: Texture.Parameters = .{},

};

pub const Glyph = struct {

    pub const Kerning = struct { codepoint: utf.Codepoint, kerning: f32 };

    codepoint: utf.Codepoint,
    advance: f32,
    bearing: f32,
    y_offset: f32,
    kerning: []Kerning,

    uv_rect: @Vector(4, f32),
    pixel_rect: @Vector(4, i32),

    pub fn kerningTo(self: *const @This(), to_codepoint: utf.Codepoint) !f32 {
        for (self.kerning) | kerning | {
            if (kerning.codepoint == to_codepoint) {
                return kerning.kerning;
            }
        } else return error.KerningNotAvailable;
    }

};

line_height: f32,
ascent:      f32,
descent:     f32,
line_gap:    f32,

glyphs: []Glyph,

atlas_image: ?Image(u8),
atlas_texture: ?Texture,

pub fn stbttFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8, parameters: Parameters) !@This() {

    const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir_path);
    var exe_dir = try std.fs.openDirAbsolute(exe_dir_path, .{});

    const abs_path = try exe_dir.realpathAlloc(allocator, path);
    defer allocator.free(abs_path);

    return try stbttFromAbsPathAlloc(allocator, abs_path, parameters);

}

pub fn stbttFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8, parameters: Parameters) !@This() {

    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    return try stbttFromFileAlloc(allocator, file, parameters);

}

pub fn stbttFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File, parameters: Parameters) !@This() {

    const file_contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(file_contents);

    return try stbttFromMemAlloc(allocator, file_contents, parameters);

}

pub fn stbttFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8, parameters: Parameters) !@This() {

    const info = blk: {
        var x: stbtt.stbtt_fontinfo = undefined;
        const ret_code = stbtt.stbtt_InitFont(&x, bytes.ptr, 0);
        if (ret_code == 0) {
            return error.STBTTCouldNotInitFont;
        }
        break :blk x;
    };

    const scale = stbtt.stbtt_ScaleForPixelHeight(&info, parameters.line_height);

    const vertical_metrics = blk: {

        var ascent:   c_int = undefined;
        var descent:  c_int = undefined;
        var line_gap: c_int = undefined;

        stbtt.stbtt_GetFontVMetrics(&info, &ascent, &descent, &line_gap);

        break :blk .{
            .ascent   = @as(f32, @floatFromInt(ascent))   * scale,
            .descent  = @as(f32, @floatFromInt(descent))  * scale,
            .line_gap = @as(f32, @floatFromInt(line_gap)) * scale,
        };

    };

    const charset = switch (parameters.charset) {
        .codepoints => | x | try allocator.dupe(utf.Codepoint, x),
        .utf8 => | x |try utf.decodeAlloc(allocator, x),
    };
    defer allocator.free(charset);

    const glyphs = try allocator.alloc(Glyph, charset.len);

    var atlas_pixel_size: @Vector(2, i32) = .{ parameters.atlas_width, 0 };

    {

        var atlas_pos_cursor: @Vector(2, i32) = @splat(parameters.atlas_padding);
        var max_height_in_current_line: i32 = 0;

        for (charset, 0..) | codepoint, i | {

            const codepoint_c_int: c_int = @bitCast(@as(u32, codepoint));
            glyphs[i].codepoint = codepoint;

            {

                var advance: c_int = undefined;
                var bearing: c_int = undefined;
            
                stbtt.stbtt_GetCodepointHMetrics(&info, codepoint_c_int, &advance, &bearing);

                glyphs[i].advance = @as(f32, @floatFromInt(advance)) * scale;
                glyphs[i].bearing = @as(f32, @floatFromInt(bearing)) * scale;

            }
            
            {

                var coords: @Vector(4, i32) = undefined;
                stbtt.stbtt_GetCodepointBitmapBox(&info, codepoint_c_int, scale, scale,
                    &coords[0], &coords[1], &coords[2], &coords[3]);

                const pixel_size: @Vector(2, i32) = .{ coords[2] - coords[0],  coords[3] - coords[1] };

                if (atlas_pos_cursor[0] + pixel_size[0] + parameters.atlas_padding > atlas_pixel_size[0]) {
                    atlas_pos_cursor[0] = parameters.atlas_padding;
                    atlas_pos_cursor[1] += max_height_in_current_line + parameters.atlas_padding;
                    atlas_pixel_size[1] += max_height_in_current_line + parameters.atlas_padding;
                    max_height_in_current_line = 0;
                }

                glyphs[i].pixel_rect = .{
                    atlas_pos_cursor[0], atlas_pos_cursor[1],
                    pixel_size[0],       pixel_size[1],
                };
                glyphs[i].y_offset = @floatFromInt(-coords[3]);

                max_height_in_current_line = @max(max_height_in_current_line, pixel_size[1]);
                atlas_pos_cursor[0] += pixel_size[0] + parameters.atlas_padding;

            }

        }
        
        atlas_pixel_size[1] += max_height_in_current_line + parameters.atlas_padding;
        atlas_pixel_size[1] = @intCast(try std.math.ceilPowerOfTwo(u16, @as(u16, @intCast(atlas_pixel_size[1]))));

    }

    for (glyphs) | *glyph | {

        const pixel_rect_f32: @Vector(4, f32) = @floatFromInt(glyph.pixel_rect);
        const atlas_size_f32: @Vector(2, f32) = @floatFromInt(atlas_pixel_size);

        glyph.uv_rect = .{
            pixel_rect_f32[0] / atlas_size_f32[0],
            pixel_rect_f32[1] / atlas_size_f32[1],
            pixel_rect_f32[2] / atlas_size_f32[0],
            pixel_rect_f32[3] / atlas_size_f32[1],
        };

    }

    const alpha_component_buffer = try allocator.alloc(u8, @intCast(atlas_pixel_size[0] * atlas_pixel_size[1]));
    defer allocator.free(alpha_component_buffer);
    for (alpha_component_buffer, 0..) | _, i | {
        alpha_component_buffer[i] = 0;
    }

    for (charset, 0..) | codepoint, i | {

        const codepoint_c_int: c_int = @bitCast(@as(u32, codepoint));

        {

            glyphs[i].kerning = try allocator.alloc(Glyph.Kerning, charset.len);

            for (charset, 0..) | to_codepoint, j | {

                const to_codepoint_c_int: c_int = @bitCast(@as(u32, to_codepoint));
                const kerning = blk: {
                    const unscaled = stbtt.stbtt_GetCodepointKernAdvance(&info, codepoint_c_int, to_codepoint_c_int);
                    break :blk @as(f32, @floatFromInt(unscaled)) * scale;
                };

                glyphs[i].kerning[j] = .{
                    .codepoint = to_codepoint,
                    .kerning = kerning,
                };

            }

        }

        const byte_offset: usize = @intCast(glyphs[i].pixel_rect[0] + glyphs[i].pixel_rect[1] * atlas_pixel_size[0]);
        stbtt.stbtt_MakeCodepointBitmap(&info, &alpha_component_buffer[byte_offset],
            glyphs[i].pixel_rect[2], glyphs[i].pixel_rect[3], atlas_pixel_size[0], scale, scale, codepoint_c_int);

    }

    const atlas_image = try Image(u8).alloc(allocator, @intCast(atlas_pixel_size), 4, @splat(255));
    defer if (parameters.free_image_after_init) {
        atlas_image.free(allocator);
    };
    
    for (0..@intCast(atlas_pixel_size[1])) | y | {
        for (0..@intCast(atlas_pixel_size[0])) | x | {

            const atlas_pixel_size_usize: @Vector(2, usize) = @intCast(atlas_pixel_size);

            const src_i = x + y * atlas_pixel_size_usize[0];
            const target_i = src_i * 4 + 3;

            atlas_image.data[target_i] = alpha_component_buffer[src_i];

        }
    }

    return .{

        .line_height    = parameters.line_height,
        .ascent         = vertical_metrics.ascent,
        .descent        = vertical_metrics.descent,
        .line_gap       = vertical_metrics.line_gap,

        .glyphs         = glyphs,

        .atlas_image    = if (parameters.free_image_after_init) null else atlas_image,
        .atlas_texture  = if (parameters.make_texture_on_init) try Texture.fromImage(atlas_image, parameters.atlas_texture_parameters) else null,

    };

}

pub fn free(self: *const @This(), allocator: std.mem.Allocator) void {
    if (self.atlas_image) | image | {
        image.free(allocator);
    }
    if (self.atlas_texture) | texture | {
        texture.free();
    }
    for (self.glyphs) | *glyph | {
        allocator.free(glyph.kerning);
    }
    allocator.free(self.glyphs);
}

pub fn freeImage(self: *@This(), allocator: std.mem.Allocator) void {
    if (self.atlas_image) | image | {
        image.free(allocator);
    }
    self.atlas_image = null;
}

pub fn freeTexture(self: *@This()) void {
    if (self.atlas_texture) | texture | {
        texture.free();
    }
    self.atlas_texture = null;
}

pub fn getGlyph(self: *const @This(), codepoint: utf.Codepoint) ?*const Glyph {
    for (self.glyphs) | *glyph | {
        if (glyph.codepoint == codepoint) {
            return glyph;
        }
    } else return null;
}

pub fn scaleForLineHeight(self: *const @This(), line_height: f32) f32 {
    return line_height / self.line_height;
}

pub fn scaledStringWidth(self: *const @This(), string: []const utf.Codepoint, line_height: f32) !f32 {
    const base = try self.baseStringWidth(string);
    return base * scaleForLineHeight(line_height);
}

pub fn stringWidth(self: *const @This(), string: []const utf.Codepoint) !f32 {
    var width: f32 = 0;
    for (string, 0..) | _, i | {
        const codepoint = string[i];
        const glyph = self.getGlyph(codepoint) orelse return error.GlyphNotFound;
        width += glyph.advance;
        if (i + 1 < string.len) {
            const next_codepoint = string[i+1];
            width += try glyph.kerningTo(next_codepoint);
        }
    }
    return width;
}