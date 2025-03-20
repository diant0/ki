const std = @import("std");
const glfw = @import("build/glfw.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = .{
        .window = .{
            .linux = .{
                .wayland = b.option(bool, "window.wayland", "include wayland window support") orelse true,
                .x11 = b.option(bool, "window.x11", "include x11 window support") orelse true,
                .use_bundled_headers = b.option(bool, "window.linux.use_bundled_headers", "use included headers") orelse !target.query.isNative(),
            },
        },
    };

    _ = glfw.vendor.glfw(b, "vendor-glfw", b.path("vendor/glfw/"));
    _ = glfw.vendor.linuxSystemHeaders(b, "vendor-linux-system-headers", b.path("vendor/include/glfw/"), b.path("vendor/glfw/deps/wayland/"));

    const glfw_module = glfw.module(b, "glfw", .{
        .target = target,
        .optimize = optimize,
        .repo_path = b.path("vendor/glfw"),
        .linux = .{
            .wayland = options.window.linux.wayland,
            .x11 = options.window.linux.x11,
            .include_overrides = if (options.window.linux.use_bundled_headers) .{
                .wayland = b.path("vendor/include/glfw/wayland/"),
                .wayland_protocols = b.path("vendor/include/glfw/wayland-protocols/"),
                .x11 = b.path("vendor/include/glfw/x11/"),
            } else null,
        },
    });

    _ = b.addModule("ki", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "glfw", .module = glfw_module },
        },
    });
}
