const std       = @import("std");
const gl        = @import("glad");
const math      = @import("math");
const Texture   = @import("Texture.zig").Texture;
const Image     = @import("Image.zig").Image;
const utf       = @import("../utf.zig");
const Font      = @import("Font.zig").Font;

pub const SpriteBatch = struct {

    pub const Vertex = struct {
        pos: @Vector(2, gl.GLfloat),
        col: @Vector(4, gl.GLfloat),
        uv:  @Vector(2, gl.GLfloat),
        sampler_index: gl.GLfloat,
    };

    pub const Uniforms = struct {
        projection: @Vector(16, f32) = @splat(0),
        samplers: [32]gl.GLint = undefined,
    };

    quad_capacity: usize = 0,
    quads_to_draw: usize = 0,
    
    vao: gl.GLuint = undefined,
    vbo: gl.GLuint = undefined,
    ibo: gl.GLuint = undefined,

    shader_program: gl.GLuint = undefined,

    vertex_buffer: []Vertex = &[_]Vertex{},

    uniforms: Uniforms = .{},
    uniform_locations: [@typeInfo(Uniforms).Struct.fields.len]gl.GLint = undefined,

    texture_ids: [32]gl.GLuint = undefined,
    textures_to_draw: usize = 0,
    max_texture_units: usize = 0,

    white_pixel_texture: Texture = undefined,

    pub fn initAlloc(self: *@This(), allocator: std.mem.Allocator, quad_capacity: usize) !void {

        self.vertex_buffer = try allocator.alloc(Vertex, quad_capacity * 4);
        self.quad_capacity = quad_capacity;

        for (self.uniforms.samplers, 0..) | _, i | {
            self.uniforms.samplers[i] = @intCast(i);
        }

        self.max_texture_units = blk: {
            var x: gl.GLint = undefined;
            gl.glGetIntegerv(gl.GL_MAX_TEXTURE_IMAGE_UNITS, &x);
            break :blk @intCast(x);
        };

        gl.glGenVertexArrays(1, &self.vao);
        gl.glBindVertexArray(self.vao);

        gl.glGenBuffers(1, &self.vbo);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(@sizeOf(Vertex) * self.vertex_buffer.len), null, gl.GL_DYNAMIC_DRAW);

        gl.glGenBuffers(1, &self.ibo);
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.ibo);

        {
            var index_buffer = try allocator.alloc(u32, quad_capacity * 6);
            defer allocator.free(index_buffer);

            for (0..quad_capacity) | quad_index | {
                
                index_buffer[quad_index * 6 + 0] = @intCast(quad_index * 4 + 0);
                index_buffer[quad_index * 6 + 1] = @intCast(quad_index * 4 + 1);
                index_buffer[quad_index * 6 + 2] = @intCast(quad_index * 4 + 2);

                index_buffer[quad_index * 6 + 3] = @intCast(quad_index * 4 + 2);
                index_buffer[quad_index * 6 + 4] = @intCast(quad_index * 4 + 3);
                index_buffer[quad_index * 6 + 5] = @intCast(quad_index * 4 + 0);
            
            }

            gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(u32) * index_buffer.len), index_buffer.ptr, gl.GL_STATIC_DRAW);

        }

        const vertex_shader = blk: {
            
            const src: [*c]const u8 =
                \\ #version 450 core
                \\ 
                \\ in vec4 pos;
                \\ in vec4 col;
                \\ in vec2 uv;
                \\ in float sampler_index;
                \\
                \\ uniform mat4 projection;
                \\
                \\ out vec4 v_col;
                \\ out vec2 v_uv;
                \\ flat out float v_sampler_index;
                \\
                \\ void main() {
                \\   v_col = col;
                \\   v_uv  = uv;
                \\   v_sampler_index = sampler_index;
                \\   gl_Position = pos * projection;
                \\}
                ;

            const shader = gl.glCreateShader(gl.GL_VERTEX_SHADER);
            gl.glShaderSource(shader, 1, &src, null);
            gl.glCompileShader(shader);

            break :blk shader;

        };

        const fragment_shader = blk: {

            const src: [*c]const u8 =
                \\ #version 450 core
                \\
                \\ uniform sampler2D samplers[32];
                \\
                \\ in vec4 v_col;
                \\ in vec2 v_uv;
                \\ flat in float v_sampler_index;
                \\
                \\ out vec4 out_col;
                \\
                \\ void main() {
                \\   out_col = texture(samplers[int(v_sampler_index)], v_uv) * v_col;
                \\   if (v_sampler_index > 32) {
                \\   out_col.g = 0.0;
                \\}
                \\ }
                ;

            const shader = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
            gl.glShaderSource(shader, 1, &src, null);
            gl.glCompileShader(shader);

            break :blk shader;
            
        };

        self.shader_program = gl.glCreateProgram();
        gl.glAttachShader(self.shader_program, vertex_shader);
        gl.glAttachShader(self.shader_program, fragment_shader);

        gl.glLinkProgram(self.shader_program);
        gl.glValidateProgram(self.shader_program);

        gl.glDetachShader(self.shader_program, vertex_shader);
        gl.glDetachShader(self.shader_program, fragment_shader);

        gl.glDeleteShader(vertex_shader);
        gl.glDeleteShader(fragment_shader);

        inline for (@typeInfo(Vertex).Struct.fields) | vert_attrib | {
                
            const location: gl.GLuint = @intCast(gl.glGetAttribLocation(self.shader_program, vert_attrib.name));

            gl.glEnableVertexAttribArray(location);

            switch (vert_attrib.type) {

                @Vector(2, gl.GLfloat) => gl.glVertexAttribPointer(
                    location, 2, gl.GL_FLOAT, gl.GL_FALSE, @intCast(@sizeOf(Vertex)), @ptrFromInt(@offsetOf(Vertex, vert_attrib.name))
                ),

                @Vector(4, gl.GLfloat) => gl.glVertexAttribPointer(
                    location, 4, gl.GL_FLOAT, gl.GL_FALSE, @intCast(@sizeOf(Vertex)), @ptrFromInt(@offsetOf(Vertex, vert_attrib.name))
                ),

                gl.GLfloat => gl.glVertexAttribPointer(
                    location, 1, gl.GL_FLOAT, gl.GL_FALSE, @intCast(@sizeOf(Vertex)), @ptrFromInt(@offsetOf(Vertex, vert_attrib.name))
                ),

                else => @compileError("SpriteBatch: unknown vertex attribute type " ++ @typeName(vert_attrib.field_type)),

            }

        }

        inline for (@typeInfo(Uniforms).Struct.fields, 0..) | uniform, i |
            self.uniform_locations[i] = gl.glGetUniformLocation(self.shader_program, uniform.name);

        self.white_pixel_texture = blk: {

            const image = try Image(u8).alloc(allocator, @splat(1), 4, @splat(255));
            const texture = try Texture.fromImage(image, .{});
            image.free(allocator);
            break :blk texture;

        };

    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.vertex_buffer);
        self.white_pixel_texture.free();
        gl.glDeleteProgram(self.shader_program);
        gl.glDeleteBuffers(1, &self.vbo);
        gl.glDeleteBuffers(1, &self.ibo);
        gl.glDeleteVertexArrays(1, &self.vao);
    }

    pub fn draw(self: *@This()) void {

        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

        gl.glEnable(gl.GL_CULL_FACE);
        gl.glCullFace(gl.GL_BACK);

        gl.glUseProgram(self.shader_program);

        for (0..self.textures_to_draw) | i | {
            gl.glActiveTexture(@intCast(gl.GL_TEXTURE0 + i));
            gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_ids[i]);
        }

        inline for (@typeInfo(Uniforms).Struct.fields, 0..) | uniform, i | {

            switch (uniform.type) {

                @Vector(16, f32) => gl.glUniformMatrix4fv(self.uniform_locations[i], 1, gl.GL_FALSE, @ptrCast(&@field(self.uniforms, uniform.name))),
                [32]gl.GLint => gl.glUniform1iv(self.uniform_locations[i], @intCast(self.textures_to_draw), &@field(self.uniforms, uniform.name)),

                else => @compileError("unknow uniform type " ++ @typeName(uniform.field_type)),

            }

        }

        gl.glBindVertexArray(self.vao);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.ibo);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(self.quads_to_draw * 4 * @sizeOf(Vertex)), self.vertex_buffer.ptr, gl.GL_DYNAMIC_DRAW);
        gl.glDrawElements(gl.GL_TRIANGLES, @intCast(self.quads_to_draw * 6), gl.GL_UNSIGNED_INT, null);

        self.quads_to_draw = 0;
        self.textures_to_draw = 0;

    }

    pub fn putTextureGetIndex(self: *@This(), texture: Texture) !usize {

        const existing_texture_id_index: ?usize = blk: {

            for (self.texture_ids[0..self.textures_to_draw], 0..) | existing_texture_id, index | {
                if (texture.id == existing_texture_id) {
                    break :blk index;
                }
            }

            break :blk null;

        };

        if (existing_texture_id_index) | x | {
            return x;
        }

        if (self.textures_to_draw + 1 > self.max_texture_units) {
            return error.TextureUnitsUsed;
        }

        const new_texture_id_index = self.textures_to_draw;
        self.texture_ids[new_texture_id_index] = texture.id;
        self.textures_to_draw += 1;
        return new_texture_id_index;

    }

    pub fn putQuadVertices(self: *@This(), bl: Vertex, br: Vertex, tr: Vertex, tl: Vertex) !void {

        if (self.quads_to_draw + 1 > self.quad_capacity) {
            return error.VertexBufferFull;
        }

        self.vertex_buffer[self.quads_to_draw * 4 + 0] = bl;
        self.vertex_buffer[self.quads_to_draw * 4 + 1] = br;
        self.vertex_buffer[self.quads_to_draw * 4 + 2] = tr;
        self.vertex_buffer[self.quads_to_draw * 4 + 3] = tl;

        self.quads_to_draw += 1;

    }

    pub fn putSubtextureRect(self: *@This(), texture: Texture, uv_rect: @Vector(4, f32), rect: @Vector(4, f32), col: @Vector(4, f32)) !void {

        const sampler_index: gl.GLfloat = @floatFromInt(try self.putTextureGetIndex(texture));

        try self.putQuadVertices(.{
            .pos = math.rBottomLeft(rect),
            .col = col,
            .uv = math.rTopLeft(uv_rect),
            .sampler_index = sampler_index,
        }, .{
            .pos = math.rBottomRight(rect),
            .col = col,
            .uv = math.rTopRight(uv_rect),
            .sampler_index = sampler_index,
        }, .{
            .pos = math.rTopRight(rect),
            .col = col,
            .uv = math.rBottomRight(uv_rect),
            .sampler_index = sampler_index,
        }, .{
            .pos = math.rTopLeft(rect),
            .col = col,
            .uv = math.rBottomLeft(uv_rect),
            .sampler_index = sampler_index,
        });

    }

    pub fn putTexturedRect(self: *@This(), texture: Texture, rect: @Vector(4, f32), col: @Vector(4, f32)) !void {
        try self.putSubtextureRect(texture, math.rUnit(f32), rect, col);
    }

    pub fn putColoredRect(self: *@This(), rect: @Vector(4, f32), col: @Vector(4, f32)) !void {
        try self.putTexturedRect(self.white_pixel_texture, rect, col);
    }

    pub fn putTexturedLine(self: *@This(), texture: Texture, start: @Vector(2, f32), end: @Vector(2, f32), width: f32, col: @Vector(4, f32)) !void {

        const direction = math.vNormalized(end - start);
        const offset = math.v2RotatedBy(direction, math.pi / 2.0) * @as(@Vector(2, f32), @splat(width / 2.0));

        const sampler_index: gl.GLfloat = @floatFromInt(try self.putTextureGetIndex(texture));

        try self.putQuadVertices(.{
            .pos = start - offset,
            .col = col,
            .uv = .{ 0.0, 1.0 },
            .sampler_index = sampler_index,
        }, .{
            .pos = end - offset,
            .col = col,
            .uv = .{ 1.0, 1.0 },
            .sampler_index = sampler_index,
        }, .{
            .pos = end + offset,
            .col = col,
            .uv = .{ 1.0, 0.0 },
            .sampler_index = sampler_index,
        }, .{
            .pos = start + offset,
            .col = col,
            .uv = .{ 0.0, 0.0 },
            .sampler_index = sampler_index,
        });

    }

    pub fn putColoredLine(self: *@This(), start: @Vector(2, f32), end: @Vector(2, f32), width: f32, col: @Vector(4, f32)) !void {
        try self.putTexturedLine(self.white_pixel_texture, start, end, width, col);
    }

    pub fn putColoredLineRect(self: *@This(), rect: @Vector(4, f32), line_width: f32, col: @Vector(4, f32)) !void {

        const bottom_left   = math.rBottomLeft(rect);
        const bottom_right  = math.rBottomRight(rect);
        const top_right     = math.rTopRight(rect);
        const top_left      = math.rTopLeft(rect);

        const offset = line_width / 2.0;

        try self.putColoredLine(bottom_left  + @Vector(2, f32) { offset, 0 }, bottom_right + @Vector(2, f32) { offset, 0 }, line_width, col);
        try self.putColoredLine(bottom_right + @Vector(2, f32) { 0, offset }, top_right    + @Vector(2, f32) { 0, offset }, line_width, col);
        try self.putColoredLine(top_right    - @Vector(2, f32) { offset, 0 }, top_left     - @Vector(2, f32) { offset, 0 }, line_width, col);
        try self.putColoredLine(top_left     - @Vector(2, f32) { 0, offset }, bottom_left  - @Vector(2, f32) { 0, offset }, line_width, col);

    }

    pub fn putTextureSprite(self: *@This(), texture: Texture, uv_rect: @Vector(4, f32), pos: @Vector(2, f32),
        scale: @Vector(2, f32), anchor: @Vector(2, f32), rotation: f32, col: @Vector(4, f32)) !void {

        const sampler_index: f32 = @floatFromInt(try self.putTextureGetIndex(texture));

        const scaled_size = @as(@Vector(2, f32), @floatFromInt(texture.size)) * (scale * @Vector(2, f32) { uv_rect[2], uv_rect[3] });
        const pos_relative_to_anchor = @Vector(2, f32) { 0, 0 } - scaled_size * anchor;

        const anchored_at_zero = @Vector(4, f32) {
            pos_relative_to_anchor[0], pos_relative_to_anchor[1],
            scaled_size[0], scaled_size[1],
        };

        try self.putQuadVertices(.{
            .pos = pos + math.v2RotatedBy(math.rBottomLeft(anchored_at_zero), rotation),
            .col = col,
            .uv = math.rTopLeft(uv_rect),
            .sampler_index = sampler_index,
        }, .{
            .pos = pos + math.v2RotatedBy(math.rBottomRight(anchored_at_zero), rotation),
            .col = col,
            .uv = math.rTopRight(uv_rect),
            .sampler_index = sampler_index,
        }, .{
            .pos = pos + math.v2RotatedBy(math.rTopRight(anchored_at_zero), rotation),
            .col = col,
            .uv = math.rBottomRight(uv_rect),
            .sampler_index = sampler_index,
        }, .{
            .pos = pos + math.v2RotatedBy(math.rTopLeft(anchored_at_zero), rotation),
            .col = col,
            .uv = math.rBottomLeft(uv_rect),
            .sampler_index = sampler_index,
        });

    }

    pub fn putFontString(self: *@This(), font: Font, string: []const utf.Codepoint, pos: @Vector(2, f32), line_height: f32, anchor: @Vector(2, f32), col: @Vector(4, f32)) !void {

        const texture = font.atlas_texture orelse return error.MissingFontAtlasTexture;

        const scale = font.scaleForLineHeight(line_height);
        const string_size = @Vector(2, f32) {
            try font.stringWidth(string) * scale,
            font.ascent,
        };

        var pos_cursor = pos - (string_size * anchor);

        for (string, 0..) | _, i | {

            const codepoint = string[i];
            const glyph = font.getGlyph(codepoint) orelse return error.FontMissingStringGlyph;

            const kerning = blk: {
                if (i + 1 < string.len) {
                    const next_codepoint = string[i + 1];
                    const unscaled = try glyph.kerningTo(next_codepoint);
                    break :blk unscaled * scale;
                } else break :blk @as(f32, 0);
            };

            const bearing  = glyph.bearing  * scale;
            const advance  = glyph.advance  * scale;
            const y_offset = glyph.y_offset * scale;

            const target_rect = @Vector(4, f32) {
                pos_cursor[0] + bearing,
                pos_cursor[1] + y_offset,
                @as(f32, @floatFromInt(glyph.pixel_rect[2])) * scale,
                @as(f32, @floatFromInt(glyph.pixel_rect[3])) * scale,
            };

            pos_cursor[0] += advance + kerning;

            try self.putSubtextureRect(texture, glyph.uv_rect, target_rect, col);

        }

    }

};