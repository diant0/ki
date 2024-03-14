const glfw = @import("glfw");
const log = @import("log.zig");

pub const Window = struct {

    pub const context = struct {

        pub inline fn init() !void {
            {
                var version: @Vector(3, c_int) = undefined;
                glfw.glfwGetVersion(&version[0], &version[1], &version[2]);
                log.print(.Info, "initializing glfw\n\tversion: {}.{}.{}\n", .{ version[0], version[1], version[2] });
            }
            const ret_code = glfw.glfwInit();
            if (ret_code != glfw.GLFW_TRUE) {
                return error.GLFWInitFailed;
            }
        }

        pub inline fn terminate() void {
            glfw.glfwTerminate();
        }
        
        pub inline fn pollEvents() void {
            glfw.glfwPollEvents();
        }

        pub const getProcAddress = glfw.glfwGetProcAddress;

    };

    handle: *glfw.GLFWwindow,

    pub inline fn create(title: [:0]const u8, size: @Vector(2, u32)) !@This() {

        glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glfw.GLFW_TRUE);
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4);
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 5);
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
        
        const handle = glfw.glfwCreateWindow(@intCast(size[0]), @intCast(size[1]), title, null, null)
            orelse return error.GLFWCreateWindowFailed;
    
        return .{
            .handle = handle,
        };

    }

    pub inline fn terminate(self: *const @This()) void {
        glfw.glfwDestroyWindow(self.handle);
    }

    pub inline fn terminationRequested(self: *const @This()) bool {
        return glfw.glfwWindowShouldClose(self.handle) != 0;
    }

    pub inline fn makeContextCurrent(self: *const @This()) void {
        glfw.glfwMakeContextCurrent(self.handle);
    }

    pub inline fn swapBuffers(self: *const @This()) void {
        glfw.glfwSwapBuffers(self.handle);
    }

};

