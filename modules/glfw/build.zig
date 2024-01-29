const std = @import("std");

// TODO: make individual x11 / wayland builds possible

pub fn build(b: *std.Build) !void {

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    const update_gamepad_mappings_step = b.step("update-gamepad-mappings", "update gamepad mappings");
    update_gamepad_mappings_step.makeFn = updateGamepadMappings;

    _ = b.addModule("glfw", .{
        .root_source_file = .{ .path = "src/glfw.zig" },
    });

    const lib = b.addStaticLibrary(.{
        .name               = "glfw",
        .root_source_file   = .{ .path = "src/glfw.zig" },
        .target             = target,
        .optimize           = optimize,
    });

    { // prerequisites

        if (target.result.os.tag == .linux) {
            try generateWaylandCode(b);
        }

    }

    { // includes

        lib.addIncludePath(.{ .path = repo_path ++ "/include" });

        if (target.result.os.tag == .linux) {

            const generated_wayland_code_abspath = try b.cache_root.handle.realpathAlloc(b.allocator, generated_wayland_code_subpath);
            defer b.allocator.free(generated_wayland_code_abspath);
            lib.addIncludePath(.{ .path = generated_wayland_code_abspath });
        
            lib.addIncludePath(.{ .path = "/usr/include" });
        
        }
    
    }

    { // linking

        lib.linkLibC();

    }

    { // c src

        var c_src_list = std.ArrayList([]const u8).init(b.allocator);
        defer c_src_list.deinit();

        try c_src_list.appendSlice(c_src.common);
        try c_src_list.appendSlice(c_src.platform_null);

        switch (target.result.os.tag) {

            .linux => {

                try c_src_list.appendSlice(c_src.platform_linux);
                
                try c_src_list.appendSlice(c_src.window_system_x11);
                try c_src_list.appendSlice(c_src.window_system_wayland);

            },

            else => return error.UnsupportedOS,

        }

        var c_flags_list = std.ArrayList([]const u8).init(b.allocator);
        defer c_flags_list.deinit();

        switch (target.result.os.tag) {

            .linux => {

                try c_flags_list.append(c_flags.build_x11);
                try c_flags_list.append(c_flags.build_wayland);

            },

            else => return error.UnsupportedOS,

        }

        lib.addCSourceFiles(.{
            .files = c_src_list.items,
            .flags = c_flags_list.items,
        });

    }

    b.installArtifact(lib);

}

/// relative to cache dir
const generated_wayland_code_subpath = "generated_wayland_code";

pub fn generateWaylandCode(b: *std.Build) !void {

    const cache_dir = b.cache_root.handle;
    const cache_dir_path = try b.cache_root.handle.realpathAlloc(b.allocator, ".");

    const wayland_scanner_program = try b.findProgram(&.{ "wayland-scanner" }, &.{ "" });

    cache_dir.makeDir(generated_wayland_code_subpath) catch | e | {
        if (e != error.PathAlreadyExists) {
            return e;
        }
    };
    const generated_code_dir = try cache_dir.openDir(generated_wayland_code_subpath, .{});

    const protocols_dir_path = try b.build_root.handle.realpathAlloc(b.allocator, repo_path ++ "/deps/wayland");
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
        
        const input_file_path = try protocols_dir.realpathAlloc(b.allocator, protocol_filename);
        defer b.allocator.free(input_file_path);
        
        var output_file_path_buf: [4096]u8 = undefined;

        const client_header_path = try std.fmt.bufPrint(&output_file_path_buf, "{s}/{s}/{s}-client-protocol.h",
            .{ cache_dir_path, generated_wayland_code_subpath, protocol_name });

        generated_code_dir.access(client_header_path, .{}) catch | e | {

            if (e == error.FileNotFound) {

                var process = std.ChildProcess.init(&[_][]const u8 {
                    wayland_scanner_program,
                    "client-header",
                    input_file_path,
                    client_header_path,
                }, b.allocator);

                const term = try process.spawnAndWait();

                if (term.Exited != 0) {
                    return error.WaylandScannerNonZeroExitCode;
                }

            }

        };

        const private_code_path = try std.fmt.bufPrint(&output_file_path_buf, "{s}/{s}/{s}-client-protocol-code.h",
            .{ b.cache_root.path.?, generated_wayland_code_subpath, protocol_name });

        generated_code_dir.access(private_code_path, .{}) catch | e | {

            if (e == error.FileNotFound) {

                var process = std.ChildProcess.init(&[_][]const u8 {
                    wayland_scanner_program,
                    "private-code",
                    input_file_path,
                    private_code_path,
                }, b.allocator);

                const term = try process.spawnAndWait();

                if (term.Exited != 0) {
                    return error.WaylandScannerNonZeroExitCode;
                }

            }

        };

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

const repo_path = "glfw";
const c_src_path = repo_path ++ "/src";

const c_src = struct {

    const common = &[_][]const u8 {
        c_src_path ++ "/init.c",
        c_src_path ++ "/platform.c",
        c_src_path ++ "/context.c",
        c_src_path ++ "/monitor.c",
        c_src_path ++ "/window.c",
        c_src_path ++ "/input.c",
        c_src_path ++ "/vulkan.c",
    };

    const platform_null = &[_][]const u8 {
        c_src_path ++ "/null_init.c",
        c_src_path ++ "/null_joystick.c",
        c_src_path ++ "/null_monitor.c",
        c_src_path ++ "/null_window.c",
    };

    const platform_linux = &[_][]const u8 {
        c_src_path ++ "/posix_module.c",
        c_src_path ++ "/posix_thread.c",
        c_src_path ++ "/posix_time.c",
        c_src_path ++ "/posix_poll.c",
        c_src_path ++ "/linux_joystick.c",
        c_src_path ++ "/xkb_unicode.c",
        c_src_path ++ "/egl_context.c",
        c_src_path ++ "/osmesa_context.c",
    };

    const window_system_x11 = &[_][]const u8 {
        c_src_path ++ "/x11_init.c",
        c_src_path ++ "/x11_monitor.c",
        c_src_path ++ "/x11_window.c",
        c_src_path ++ "/glx_context.c",
    };

    const window_system_wayland = &[_][]const u8 {
        c_src_path ++ "/wl_init.c",
        c_src_path ++ "/wl_monitor.c",
        c_src_path ++ "/wl_window.c",                    
    };

};

pub const c_flags = struct {

    pub const build_x11     = "-D_GLFW_X11";
    pub const build_wayland = "-D_GLFW_WAYLAND";

};
