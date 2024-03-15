const std       = @import("std");
const gl        = @import("glad");
const math      = @import("math");
const Texture   = @import("Texture.zig").Texture;

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
    quads_to_flush: usize = 0,
    
    vao: gl.GLuint = undefined,
    vbo: gl.GLuint = undefined,
    ibo: gl.GLuint = undefined,

    shader_program: gl.GLuint = undefined,

    vertex_buffer: []Vertex = &[_]Vertex{},

    uniforms: Uniforms = .{},
    uniform_locations: [@typeInfo(Uniforms).Struct.fields.len]gl.GLint = undefined,

    texture_ids: [32]gl.GLuint = undefined,
    textures_to_flush: usize = 0,
    max_texture_units: usize = 0,

    white_pixel_texture: Texture = undefined,

    pub fn createAlloc(allocator: std.mem.Allocator, quad_capacity: usize) !@This() {

        var batch: @This() = .{};

        batch.vertex_buffer = try allocator.alloc(Vertex, quad_capacity * 4);
        batch.quad_capacity = quad_capacity;

        for (batch.uniforms.samplers, 0..) | _, i | {
            batch.uniforms.samplers[i] = @intCast(i);
        }

        batch.max_texture_units = blk: {
            var x: gl.GLint = undefined;
            gl.glGetIntegerv(gl.GL_MAX_TEXTURE_IMAGE_UNITS, &x);
            break :blk @intCast(x);
        };

        gl.glGenVertexArrays(1, &batch.vao);
        gl.glBindVertexArray(batch.vao);

        gl.glGenBuffers(1, &batch.vbo);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, batch.vbo);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(@sizeOf(Vertex) * batch.vertex_buffer.len), null, gl.GL_DYNAMIC_DRAW);

        gl.glGenBuffers(1, &batch.ibo);
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, batch.ibo);

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

        batch.shader_program = gl.glCreateProgram();
        gl.glAttachShader(batch.shader_program, vertex_shader);
        gl.glAttachShader(batch.shader_program, fragment_shader);

        gl.glLinkProgram(batch.shader_program);
        gl.glValidateProgram(batch.shader_program);

        gl.glDetachShader(batch.shader_program, vertex_shader);
        gl.glDetachShader(batch.shader_program, fragment_shader);

        gl.glDeleteShader(vertex_shader);
        gl.glDeleteShader(fragment_shader);

        inline for (@typeInfo(Vertex).Struct.fields) | vert_attrib | {
                
            const location: gl.GLuint = @intCast(gl.glGetAttribLocation(batch.shader_program, vert_attrib.name));

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
            batch.uniform_locations[i] = gl.glGetUniformLocation(batch.shader_program, uniform.name);

        gl.glGenTextures(1, &batch.white_pixel_texture.id);
        batch.white_pixel_texture.setFilterMin(.Nearest);
        batch.white_pixel_texture.setFilterMag(.Nearest);
        batch.white_pixel_texture.setWrap(.ClampToEdge, .ClampToEdge);

        const white_pixel_image_data = [_]u8 { 255, 255, 255, 255 };
        gl.glBindTexture(gl.GL_TEXTURE_2D, batch.white_pixel_texture.id);
        gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA8, 1, 1, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, @ptrCast(&white_pixel_image_data));
        batch.white_pixel_texture.size = @splat(1);
        batch.white_pixel_texture.channels = 4;

        return batch;

    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.vertex_buffer);
        self.white_pixel_texture.free();
        gl.glDeleteProgram(self.shader_program);
        gl.glDeleteBuffers(1, &self.vbo);
        gl.glDeleteBuffers(1, &self.ibo);
        gl.glDeleteVertexArrays(1, &self.vao);
    }

    pub fn flush(self: *@This()) void {

        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

        gl.glEnable(gl.GL_CULL_FACE);
        gl.glCullFace(gl.GL_BACK);

        gl.glUseProgram(self.shader_program);

        for (0..self.textures_to_flush) | i | {
            gl.glActiveTexture(@intCast(gl.GL_TEXTURE0 + i));
            gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_ids[i]);
        }

        inline for (@typeInfo(Uniforms).Struct.fields, 0..) | uniform, i | {

            switch (uniform.type) {

                @Vector(16, f32) => gl.glUniformMatrix4fv(self.uniform_locations[i], 1, gl.GL_FALSE, @ptrCast(&@field(self.uniforms, uniform.name))),
                [32]gl.GLint => gl.glUniform1iv(self.uniform_locations[i], @intCast(self.textures_to_flush), &@field(self.uniforms, uniform.name)),

                else => @compileError("unknow uniform type " ++ @typeName(uniform.field_type)),

            }

        }

        gl.glBindVertexArray(self.vao);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.ibo);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @intCast(self.quads_to_flush * 4 * @sizeOf(Vertex)), self.vertex_buffer.ptr, gl.GL_DYNAMIC_DRAW);
        gl.glDrawElements(gl.GL_TRIANGLES, @intCast(self.quads_to_flush * 6), gl.GL_UNSIGNED_INT, null);

        self.quads_to_flush = 0;
        self.textures_to_flush = 0;

    }

    pub fn putTextureGetIndex(self: *@This(), texture: Texture) !usize {

        const existing_texture_id_index: ?usize = blk: {

            for (self.texture_ids[0..self.textures_to_flush], 0..) | existing_texture_id, index | {
                if (texture.id == existing_texture_id) {
                    break :blk index;
                }
            }

            break :blk null;

        };

        if (existing_texture_id_index) | x | {
            return x;
        }

        if (self.textures_to_flush + 1 > self.max_texture_units) {
            return error.TextureUnitsUsed;
        }

        const new_texture_id_index = self.textures_to_flush;
        self.texture_ids[new_texture_id_index] = texture.id;
        self.textures_to_flush += 1;
        return new_texture_id_index;

    }

    pub fn putQuadVertices(self: *@This(), bl: Vertex, br: Vertex, tr: Vertex, tl: Vertex) !void {

        if (self.quads_to_flush + 1 > self.quad_capacity) {
            return error.VertexBufferFull;
        }

        self.vertex_buffer[self.quads_to_flush * 4 + 0] = bl;
        self.vertex_buffer[self.quads_to_flush * 4 + 1] = br;
        self.vertex_buffer[self.quads_to_flush * 4 + 2] = tr;
        self.vertex_buffer[self.quads_to_flush * 4 + 3] = tl;

        self.quads_to_flush += 1;

    }

    pub fn putTexturedRect(self: *@This(), rect: @Vector(4, f32), texture: Texture, col: @Vector(4, f32)) !void {

        const sampler_index: gl.GLfloat = @floatFromInt(try self.putTextureGetIndex(texture));

        try self.putQuadVertices(.{
            .pos = math.rBottomLeft(rect),
            .col = col,
            .uv = .{ 0.0, 1.0 },
            .sampler_index = sampler_index,
        }, .{
            .pos = math.rBottomRight(rect),
            .col = col,
            .uv = .{ 1.0, 1.0 },
            .sampler_index = sampler_index,
        }, .{
            .pos = math.rTopRight(rect),
            .col = col,
            .uv = .{ 1.0, 0.0 },
            .sampler_index = sampler_index,
        }, .{
            .pos = math.rTopLeft(rect),
            .col = col,
            .uv = .{ 0.0, 0.0 },
            .sampler_index = sampler_index,
        });

    }

    pub fn putColoredRect(self: *@This(), rect: @Vector(4, f32), col: @Vector(4, f32)) !void {
        try self.putTexturedRect(rect, self.white_pixel_texture, col);
    }

};