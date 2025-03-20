const std = @import("std");
const VendorGitRepo = @import("steps/VendorGitRepo.zig");
const GeneratedWaylandProtocolHeadersWriteFiles = @import("steps/glfw/GeneratedWaylandProtocolHeadersWriteFiles.zig");
const VendorLinuxSystemHeaders = @import("steps/glfw/VendorLinuxSystemHeaders.zig");

pub const vendor = struct {
    pub fn glfw(b: *std.Build, name: []const u8, dest_dir: std.Build.LazyPath) *std.Build.Step {
        const vendor_repo = VendorGitRepo.create(b, .{
            .url = "https://github.com/glfw/glfw",
            .dest_dir = dest_dir,
            .copy_paths = &.{
                "deps",
                "include",
                "src",
                "LICENSE.md",
            },
            .exclude_basenames = &.{"CMakeLists.txt"},
        });
        const step = b.step(name, "vendor latest glfw");
        step.dependOn(&vendor_repo.step);
        return step;
    }

    pub fn linuxSystemHeaders(b: *std.Build, name: []const u8, dest_dir: std.Build.LazyPath, wayland_protocols_dir: std.Build.LazyPath) *std.Build.Step {
        const vendor_headers = VendorLinuxSystemHeaders.create(b, .{
            .dest_dir = dest_dir,
            .wayland_protocols_dir = wayland_protocols_dir,
        });
        const step = b.step(name, "vendor current system's headers");
        step.dependOn(&vendor_headers.step);
        return step;
    }
};

pub const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    repo_path: std.Build.LazyPath,
    linux: struct {
        x11: bool = true,
        wayland: bool = true,
        include_overrides: ?struct {
            wayland: std.Build.LazyPath,
            wayland_protocols: std.Build.LazyPath,
            x11: std.Build.LazyPath,
        } = null,
    },
};

pub fn module(b: *std.Build, name: []const u8, options: Options) *std.Build.Module {
    const root_source_file = b.addWriteFile("glfw.zig",
        \\pub usingnamespace @cImport({
        \\    @cDefine("GLFW_INCLUDE_NONE", "");
        \\    @cInclude("GLFW/glfw3.h");
        \\});
    );

    const m = b.addModule(name, .{
        .root_source_file = root_source_file.getDirectory().path(b, "glfw.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });
    m.addIncludePath(options.repo_path.path(b, "include/"));
    m.linkLibrary(staticLib(b, name, options));

    return m;
}

pub fn staticLib(b: *std.Build, name: []const u8, options: Options) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = name,
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });

    lib.root_module.addCSourceFiles(.{
        .root = options.repo_path,
        .files = &.{
            "src/init.c",
            "src/platform.c",
            "src/context.c",
            "src/monitor.c",
            "src/window.c",
            "src/input.c",
            "src/vulkan.c",
        },
    });

    lib.root_module.addCSourceFiles(.{
        .root = options.repo_path,
        .files = &.{
            "src/null_init.c",
            "src/null_joystick.c",
            "src/null_monitor.c",
            "src/null_window.c",
        },
    });

    switch (options.target.result.os.tag) {
        .linux => {
            if (options.linux.include_overrides) |include_overrides| {
                if (options.linux.wayland) {
                    lib.root_module.addIncludePath(include_overrides.wayland);
                    lib.root_module.addIncludePath(include_overrides.wayland_protocols);
                }
                if (options.linux.x11) {
                    lib.root_module.addIncludePath(include_overrides.x11);
                }
            } else if (options.target.query.isNative()) {
                if (options.linux.wayland) {
                    const generate_wayland_protocol_headers = GeneratedWaylandProtocolHeadersWriteFiles.create(b, options.repo_path.path(b, "deps/wayland/"));
                    lib.step.dependOn(&generate_wayland_protocol_headers.step);
                    lib.root_module.addIncludePath(generate_wayland_protocol_headers.write_files.getDirectory());
                }
            }

            lib.root_module.addCSourceFiles(.{
                .root = options.repo_path,
                .files = &.{
                    "src/posix_module.c",
                    "src/posix_thread.c",
                    "src/posix_time.c",
                    "src/posix_poll.c",
                    "src/linux_joystick.c",
                    "src/egl_context.c",
                    "src/osmesa_context.c",
                },
            });

            if (options.linux.x11) {
                lib.root_module.addCMacro("_GLFW_X11", "");
                lib.root_module.addCSourceFiles(.{
                    .root = options.repo_path,
                    .files = &.{
                        "src/x11_init.c",
                        "src/x11_monitor.c",
                        "src/x11_window.c",
                        "src/glx_context.c",
                        "src/xkb_unicode.c",
                    },
                });
            }

            if (options.linux.wayland) {
                lib.root_module.addCMacro("_GLFW_WAYLAND", "");
                lib.root_module.addCSourceFiles(.{
                    .root = options.repo_path,
                    .files = &.{
                        "src/wl_init.c",
                        "src/wl_monitor.c",
                        "src/wl_window.c",
                    },
                });
            }
        },
        .windows => {
            lib.root_module.addCMacro("_GLFW_WIN32", "");
            lib.root_module.addCSourceFiles(.{
                .root = options.repo_path,
                .files = &.{
                    "src/win32_init.c",
                    "src/win32_module.c",
                    "src/win32_monitor.c",
                    "src/win32_window.c",
                    "src/win32_joystick.c",
                    "src/win32_time.c",
                    "src/win32_thread.c",
                    "src/wgl_context.c",
                    "src/egl_context.c",
                    "src/osmesa_context.c",
                },
            });
            lib.root_module.linkSystemLibrary("gdi32", .{ .preferred_link_mode = .static });
        },
        else => |os_tag| std.debug.panic("unsupported os {s}\n", .{@tagName(os_tag)}),
    }

    return lib;
}
