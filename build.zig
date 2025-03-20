const std = @import("std");
const glfw = @import("build/glfw.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = glfw.vendor.glfw(b, "vendor-glfw", b.path("vendor/glfw/"));

    _ = b.addModule("ki", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
}
