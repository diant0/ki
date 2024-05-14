const std = @import("std");

pub fn build(b: *std.Build) !void {

    const build_platform_wayland    = b.option(bool, "wayland",   "build wayland platform") orelse true;
    const build_platform_x11        = b.option(bool, "x11",       "build x11 platform")     orelse true;

    const update_gamepad_mappings_step = b.step("update-gamepad-mappings", "update gamepad mappings");
    update_gamepad_mappings_step.makeFn = updateGamepadMappings;

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    const wayland_headers_path: ?[]const u8 = switch (target.result.os.tag) {
        .linux => blk: {
            if (!build_platform_wayland) {
                break :blk null;
            }
            const cache_subpath = "wayland";
            try generateWaylandHeaders(b, cache_subpath);
            const x = try b.cache_root.handle.realpathAlloc(b.allocator, "wayland");
            break :blk x;
        },
        else => null,

    };
    defer if (wayland_headers_path) | x | {
        b.allocator.free(x);
    };

    // module
    const module = b.addModule("glfw", .{
        .root_source_file = b.path("src/glfw.zig"),
    });

    module.addIncludePath(b.path("glfw/include"));
    
    switch (target.result.os.tag) {
    
        .linux => {

            module.addIncludePath(.{ .cwd_relative = "/usr/include" });
            if (wayland_headers_path) | x | {
                module.addIncludePath(.{ .cwd_relative = x });
            }
        
        },

        else => {},
    
    }

    // lib
    const lib = b.addStaticLibrary(.{
        .name               = "glfw",
        .target             = target,
        .optimize           = optimize,
    });

    lib.linkLibC();
    lib.addIncludePath(b.path("glfw/include"));

    switch (target.result.os.tag) {
    
        .linux => {

            lib.addIncludePath(.{ .cwd_relative = "/usr/include" });
            if (wayland_headers_path) | x | {
                lib.addIncludePath(.{ .cwd_relative = x });
            }
        
        },

        .windows => {

            lib.linkSystemLibrary("gdi32");

        },

        else => {},
    
    }

    var c_src = std.ArrayList([]const u8).init(b.allocator);
    defer c_src.deinit();

    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    defer c_flags.deinit();

    try c_src.appendSlice(c_src_common);
    try c_src.appendSlice(c_src_platform_null);

    lib.addIncludePath(b.path("glfw/include"));

    switch (target.result.os.tag) {

        .linux => {
            
            try c_src.appendSlice(c_src_platform_linux);

            if (build_platform_x11) {
                try c_src.appendSlice(c_src_platform_x11);
                try c_flags.append(c_flag_build_x11);
            }

            if (build_platform_wayland) {
                try c_src.appendSlice(c_src_platform_wayland);
                try c_flags.append(c_flag_build_wayland);
            }

        },

        .windows => {

            try c_src.appendSlice(c_src_platform_win32);
            try c_flags.append(c_flag_build_win32);

        },

        else => return error.UnsupportedOS,

    }

    lib.addCSourceFiles(.{
        .files = c_src.items,
        .flags = c_flags.items,
    });

    b.installArtifact(lib);

}

fn generateWaylandHeaders(b: *std.Build, cache_subpath: []const u8) !void {

    const access_error = b.cache_root.handle.access(cache_subpath, .{});
    if (access_error != error.FileNotFound) {
        return;
    }

    try b.cache_root.handle.makePath(cache_subpath);

    const wayland_scanner_program = try b.findProgram(&.{ "wayland-scanner" }, &.{ "" });

    const protocols_dir_path = try b.build_root.handle.realpathAlloc(b.allocator, "glfw/deps/wayland");
    defer b.allocator.free(protocols_dir_path);
    const protocols_dir = try std.fs.openDirAbsolute(protocols_dir_path, .{ .iterate = true });
    var protocols_dir_iterator = protocols_dir.iterate();

    while (try protocols_dir_iterator.next()) | protocol_dir_entry | {

        const protocol_filename = protocol_dir_entry.name;
        const protocol_name = blk: {
            const last_dot_index = std.mem.lastIndexOf(u8, protocol_filename, ".");
            if (last_dot_index) | extension_dot_index | {
                break :blk protocol_filename[0..extension_dot_index];
            } else return error.UnexpectedWaylandProtocolFileFormat;
        };
        
        const input_file_abspath = try protocols_dir.realpathAlloc(b.allocator, protocol_filename);
        defer b.allocator.free(input_file_abspath);
        
        var output_file_path_buf: [4096]u8 = undefined;

        const exit_code_client_header = blk: {

            const client_header_abspath = try std.fmt.bufPrint(&output_file_path_buf, "{s}/{s}/{s}-client-protocol.h",
                .{ b.cache_root.path orelse ".", cache_subpath, protocol_name });

            var process = std.ChildProcess.init(&[_][]const u8 {
                wayland_scanner_program,
                "client-header",
                input_file_abspath,
                client_header_abspath,
            }, b.allocator);

            const term = try process.spawnAndWait();

            break :blk term.Exited;

        };
        if (exit_code_client_header != 0) {
            return error.CouldNotGenerateWaylandClientHeader;
        }

        const exit_code_private_code = blk: {

            const private_code_abspath = try std.fmt.bufPrint(&output_file_path_buf, "{s}/{s}/{s}-client-protocol-code.h",
                .{ b.cache_root.path.?, cache_subpath, protocol_name });

            var process = std.ChildProcess.init(&[_][]const u8 {
                wayland_scanner_program,
                "private-code",
                input_file_abspath,
                private_code_abspath,
            }, b.allocator);

            const term = try process.spawnAndWait();

            break :blk term.Exited;

        };
        if (exit_code_private_code != 0) {
            return error.CouldNotGenerateWaylandPrivateCode;
        }

    }

}

fn updateGamepadMappings(self: *std.Build.Step, _: *std.Progress.Node) !void {

    const b = self.owner;

    const cmake_program = try b.findProgram(&.{ "cmake" }, &.{ "" });

    const build_root = b.build_root.handle;
    
    const cmake_scipt_path = try build_root.realpathAlloc(b.allocator, "glfw/CMake/GenerateMappings.cmake");
    defer b.allocator.free(cmake_scipt_path);
    
    const mappings_h_in_path = try build_root.realpathAlloc(b.allocator, "glfw/src/mappings.h.in");
    defer b.allocator.free(mappings_h_in_path);

    const mappings_h_path = try build_root.realpathAlloc(b.allocator, "glfw/src/mappings.h");
    defer b.allocator.free(mappings_h_path);

    var process = std.ChildProcess.init(&[_][]const u8 {
        cmake_program,
        "-P",
        cmake_scipt_path,
        mappings_h_in_path,
        mappings_h_path,
    }, b.allocator);

    const term = try process.spawnAndWait();

    if (term.Exited != 0) {
        return error.CMakeNonZeroExitCode;
    }
    
}

const c_src_path = "glfw/src";

pub const c_flag_build_x11     = "-D_GLFW_X11";
pub const c_flag_build_wayland = "-D_GLFW_WAYLAND";
pub const c_flag_build_win32   = "-D_GLFW_WIN32";

const c_src_common = &[_][]const u8 {
    c_src_path ++ "/init.c",
    c_src_path ++ "/platform.c",
    c_src_path ++ "/context.c",
    c_src_path ++ "/monitor.c",
    c_src_path ++ "/window.c",
    c_src_path ++ "/input.c",
    c_src_path ++ "/vulkan.c",
};

const c_src_platform_null = &[_][]const u8 {
    c_src_path ++ "/null_init.c",
    c_src_path ++ "/null_joystick.c",
    c_src_path ++ "/null_monitor.c",
    c_src_path ++ "/null_window.c",
};

const c_src_platform_linux = &[_][]const u8 {
    c_src_path ++ "/posix_module.c",
    c_src_path ++ "/posix_thread.c",
    c_src_path ++ "/posix_time.c",
    c_src_path ++ "/posix_poll.c",
    c_src_path ++ "/linux_joystick.c",
    c_src_path ++ "/xkb_unicode.c",
    c_src_path ++ "/egl_context.c",
    c_src_path ++ "/osmesa_context.c",
};

const c_src_platform_x11 = &[_][]const u8 {
    c_src_path ++ "/x11_init.c",
    c_src_path ++ "/x11_monitor.c",
    c_src_path ++ "/x11_window.c",
    c_src_path ++ "/glx_context.c",
};

const c_src_platform_wayland = &[_][]const u8 {
    c_src_path ++ "/wl_init.c",
    c_src_path ++ "/wl_monitor.c",
    c_src_path ++ "/wl_window.c",                    
};

const c_src_platform_win32 = &[_][]const u8 {
    c_src_path ++ "/win32_init.c",
    c_src_path ++ "/win32_module.c",
    c_src_path ++ "/win32_monitor.c",
    c_src_path ++ "/win32_window.c",
    c_src_path ++ "/win32_joystick.c",
    c_src_path ++ "/win32_time.c",
    c_src_path ++ "/win32_thread.c",
    c_src_path ++ "/wgl_context.c",
    c_src_path ++ "/egl_context.c",
    c_src_path ++ "/osmesa_context.c",
};