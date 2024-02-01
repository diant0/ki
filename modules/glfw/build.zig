const std = @import("std");

pub fn build(b: *std.Build) !void {

    // --------------------------------

    const update_gamepad_mappings_step = b.step("update-gamepad-mappings", "update gamepad mappings");
    update_gamepad_mappings_step.makeFn = updateGamepadMappings;

    // --------------------------------

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    const build_platform_wayland    = b.option(bool, "wayland",   "build wayland platform") orelse false;
    const build_platform_x11        = b.option(bool, "x11",       "build x11 platform")     orelse false;

    if (target.result.os.tag == .linux) {
        if (!build_platform_x11 and !build_platform_wayland) {
            return error.NoPlatformForLinuxSelected;
        }
    }

    // --------------------------------
    
    const module = b.addModule("glfw", .{
        .root_source_file = .{ .path = "src/glfw.zig" },
    });

    module.addIncludePath(.{ .path = repo_path ++ "/include" });

    switch (target.result.os.tag) {

        .linux => {
            module.addIncludePath(.{ .path = "/usr/include" });
        },

        else => return error.UnsupportedOS,

    }

    // --------------------------------

    const lib = b.addStaticLibrary(.{
        .name               = "glfw",
        .root_source_file   = .{ .path = "src/glfw.zig" },
        .target             = target,
        .optimize           = optimize,
    });

    b.installArtifact(lib);

    // --------------------------------

    var c_src = std.ArrayList([]const u8).init(b.allocator);
    defer c_src.deinit();

    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    defer c_flags.deinit();

    try c_src.appendSlice(c_src_common);
    try c_src.appendSlice(c_src_platform_null);

    lib.addIncludePath(.{ .path = repo_path ++ "/include" });

    switch (target.result.os.tag) {

        .linux => {

            lib.addIncludePath(.{ .path = "/usr/include" });
            try c_src.appendSlice(c_src_platform_linux);
            lib.linkLibC();

            if (build_platform_x11) {

                try c_src.appendSlice(c_src_platform_x11);
                try c_flags.append(c_flag_build_x11);

            }

            if (build_platform_wayland) {

                try generateWaylandCode(b);

                const generated_wayland_code_abspath = try b.cache_root.handle.realpathAlloc(b.allocator, generated_wayland_code_subpath);
                defer b.allocator.free(generated_wayland_code_abspath);
                lib.addIncludePath(.{ .path = generated_wayland_code_abspath });
            
                try c_src.appendSlice(c_src_platform_wayland);
                try c_flags.append(c_flag_build_wayland);

            }


        },

        else => return error.UnsupportedOS,

    }

    lib.addCSourceFiles(.{
        .files = c_src.items,
        .flags = c_flags.items,
    });

    // --------------------------------

}

/// relative to cache dir
const generated_wayland_code_subpath = "generated/glfw/wayland-protocols";

pub fn generateWaylandCode(b: *std.Build) !void {

    const cache_dir = b.cache_root.handle;
    const cache_dir_path = try b.cache_root.handle.realpathAlloc(b.allocator, ".");

    const wayland_scanner_program = try b.findProgram(&.{ "wayland-scanner" }, &.{ "" });

    const generated_code_dir = try cache_dir.makeOpenPath(generated_wayland_code_subpath, .{});

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

        const genereted_client_header_file = generated_code_dir.openFile(client_header_path, .{}) catch | e | blk: {

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

            break :blk try generated_code_dir.openFile(client_header_path, .{});

        };
        genereted_client_header_file.close();

        const private_code_path = try std.fmt.bufPrint(&output_file_path_buf, "{s}/{s}/{s}-client-protocol-code.h",
            .{ b.cache_root.path.?, generated_wayland_code_subpath, protocol_name });

        const genereted_private_code_file = generated_code_dir.openFile(private_code_path, .{}) catch | e | blk: {

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

            break :blk try generated_code_dir.openFile(private_code_path, .{});

        };
        genereted_private_code_file.close();
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

pub const c_flag_build_x11     = "-D_GLFW_X11";
pub const c_flag_build_wayland = "-D_GLFW_WAYLAND";

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