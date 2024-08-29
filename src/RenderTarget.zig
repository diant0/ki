const gl = @import("glad");
const Texture = @import("Texture.zig");
const math = @import("math");

pub const Vertex = struct {
    pos: @Vector(2, f32),
    uv: @Vector(2, f32),
};

framebuffer: gl.GLuint = 0,
rgba_texture: Texture = .{},
depth_renderbuffer: gl.GLuint = 0,
shader_program: gl.GLuint = 0,
vao: gl.GLuint = 0,
vbo: gl.GLuint = 0,
rgba_texture_loc: gl.GLint = 0,
transform_loc: gl.GLint = 0,

reference_resolution: @Vector(2, f32) = .{ 1920, 1080 },
reference_scale: @Vector(2, f32) = @splat(0),

pub const Parameters = struct {
    filter_min: Texture.FilterMin = .Nearest,
    filter_mag: Texture.FilterMag = .Nearest,
};

pub fn init(self: *@This(), size: @Vector(2, u32), parameters: Parameters) void {
    gl.glGenFramebuffers(1, &self.framebuffer);
    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.framebuffer);

    gl.glGenTextures(1, &self.rgba_texture.id);
    gl.glBindTexture(gl.GL_TEXTURE_2D, self.rgba_texture.id);
    self.rgba_texture.setFilterMin(parameters.filter_min);
    self.rgba_texture.setFilterMag(parameters.filter_mag);
    self.rgba_texture.setWrap(.ClampToEdge, .ClampToEdge);

    gl.glGenRenderbuffers(1, &self.depth_renderbuffer);
    gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, self.depth_renderbuffer);

    self.resize(size);

    gl.glFramebufferTexture(gl.GL_FRAMEBUFFER, gl.GL_COLOR_ATTACHMENT0, self.rgba_texture.id, 0);
    gl.glFramebufferRenderbuffer(gl.GL_FRAMEBUFFER, gl.GL_DEPTH_ATTACHMENT, gl.GL_RENDERBUFFER, self.depth_renderbuffer);

    gl.glDrawBuffers(1, &[_]gl.GLenum{gl.GL_COLOR_ATTACHMENT0});

    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);

    gl.glGenVertexArrays(1, &self.vao);
    gl.glBindVertexArray(self.vao);

    self.vbo = blk: {
        var buffer: gl.GLuint = undefined;
        gl.glGenBuffers(1, &buffer);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, buffer);

        const vertex_buffer_data = [6]Vertex{
            .{ .pos = .{ -1.0, -1.0 }, .uv = .{ 0.0, 1.0 } },
            .{ .pos = .{ 1.0, -1.0 }, .uv = .{ 1.0, 1.0 } },
            .{ .pos = .{ 1.0, 1.0 }, .uv = .{ 1.0, 0.0 } },

            .{ .pos = .{ 1.0, 1.0 }, .uv = .{ 1.0, 0.0 } },
            .{ .pos = .{ -1.0, 1.0 }, .uv = .{ 0.0, 0.0 } },
            .{ .pos = .{ -1.0, -1.0 }, .uv = .{ 0.0, 1.0 } },
        };

        gl.glBufferStorage(gl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertex_buffer_data)), &vertex_buffer_data, 0);

        break :blk buffer;
    };

    self.shader_program = blk: {
        const vertex_shader_src: [*c]const u8 =
            \\ #version 330 core
            \\
            \\ in vec4 pos;
            \\ in vec2 uv;
            \\ 
            \\ out vec2 v_uv;
            \\ 
            \\ uniform mat4 transform;
            \\
            \\ void main() {
            \\   v_uv = uv;
            \\   gl_Position = pos * transform;
            \\ }
        ;

        const vertex_shader = gl.glCreateShader(gl.GL_VERTEX_SHADER);
        gl.glShaderSource(vertex_shader, 1, &vertex_shader_src, null);
        gl.glCompileShader(vertex_shader);

        const fragment_shader_src: [*c]const u8 =
            \\ #version 330 core
            \\
            \\ in vec2 v_uv;
            \\
            \\ uniform sampler2D rgba_texture;
            \\
            \\ layout(location=0) out vec4 out_col;
            \\
            \\ void main() {
            \\   out_col = texture(rgba_texture, v_uv);
            \\ }
        ;

        const fragment_shader = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
        gl.glShaderSource(fragment_shader, 1, &fragment_shader_src, null);
        gl.glCompileShader(fragment_shader);

        const program = gl.glCreateProgram();
        gl.glAttachShader(program, vertex_shader);
        gl.glAttachShader(program, fragment_shader);

        gl.glLinkProgram(program);
        gl.glValidateProgram(program);

        gl.glDetachShader(program, vertex_shader);
        gl.glDetachShader(program, fragment_shader);

        gl.glDeleteShader(vertex_shader);
        gl.glDeleteShader(fragment_shader);

        break :blk program;
    };

    const pos_vertex_attrib_location: gl.GLuint = @intCast(gl.glGetAttribLocation(self.shader_program, "pos"));
    gl.glEnableVertexAttribArray(pos_vertex_attrib_location);
    gl.glVertexAttribPointer(pos_vertex_attrib_location, 2, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "pos")));

    const uv_vertex_attrib_location: gl.GLuint = @intCast(gl.glGetAttribLocation(self.shader_program, "uv"));
    gl.glEnableVertexAttribArray(uv_vertex_attrib_location);
    gl.glVertexAttribPointer(uv_vertex_attrib_location, 2, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "uv")));

    self.rgba_texture_loc = gl.glGetUniformLocation(self.shader_program, "rgba_texture");
    self.transform_loc = gl.glGetUniformLocation(self.shader_program, "transform");
}

pub fn free(self: *const @This()) void {
    self.rgba_texture.free();
    gl.glDeleteProgram(self.shader_program);
    gl.glDeleteBuffers(1, &self.vbo);
    gl.glDeleteRenderbuffers(1, &self.depth_renderbuffer);
    gl.glDeleteFramebuffers(1, &self.framebuffer);
    gl.glDeleteVertexArrays(1, &self.vao);
}

pub fn resize(self: *@This(), size: @Vector(2, u32)) void {
    if (@reduce(.And, size == self.rgba_texture.size)) {
        return;
    }

    self.rgba_texture.size = size;
    gl.glBindTexture(gl.GL_TEXTURE_2D, self.rgba_texture.id);
    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA, @intCast(size[0]), @intCast(size[1]), 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, null);
    gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, self.depth_renderbuffer);
    gl.glRenderbufferStorage(gl.GL_RENDERBUFFER, gl.GL_DEPTH_COMPONENT, @intCast(size[0]), @intCast(size[1]));

    self.reference_scale = @as(@Vector(2, f32), @floatFromInt(size)) / self.reference_resolution;
}

pub fn bind(self: *const @This()) void {
    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.framebuffer);
    gl.glViewport(0, 0, @intCast(self.rgba_texture.size[0]), @intCast(self.rgba_texture.size[1]));
}

pub fn unbind(_: *const @This()) void {
    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
}

pub fn presentScaled(self: *@This(), target_size: @Vector(2, u32)) void {
    gl.glViewport(0, 0, @intCast(target_size[0]), @intCast(target_size[1]));
    gl.glUseProgram(self.shader_program);

    const transform = math.m4Identity(f32);
    gl.glUniformMatrix4fv(self.transform_loc, 1, gl.GL_FALSE, @ptrCast(&transform));
    gl.glBindVertexArray(self.vao);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);

    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, self.rgba_texture.id);
    gl.glUniform1i(self.rgba_texture_loc, 0);

    gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);
}

pub fn presentLetterboxed(self: *@This(), target_size: @Vector(2, u32)) void {
    gl.glViewport(0, 0, @intCast(target_size[0]), @intCast(target_size[1]));
    gl.glUseProgram(self.shader_program);

    const aspect = @as(f32, @floatFromInt(self.rgba_texture.size[0])) / @as(f32, @floatFromInt(self.rgba_texture.size[1]));
    const target_aspect = @as(f32, @floatFromInt(target_size[0])) / @as(f32, @floatFromInt(target_size[1]));

    var scale: @Vector(2, f32) = @splat(1);

    if (aspect > target_aspect) {
        scale[1] = target_aspect / aspect;
    } else {
        scale[0] = aspect / target_aspect;
    }

    const transform = math.m4Scale(f32, .{ scale[0], scale[1], 1 });
    gl.glUniformMatrix4fv(self.transform_loc, 1, gl.GL_FALSE, @ptrCast(&transform));

    gl.glBindVertexArray(self.vao);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);

    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, self.rgba_texture.id);
    gl.glUniform1i(self.rgba_texture_loc, 0);

    gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);
}
