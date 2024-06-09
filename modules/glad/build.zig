const std = @import("std");

pub fn build(b: *std.Build) !void {

    // module
    const module = b.addModule("glad", .{
        .root_source_file = b.path("src/module.zig"),
    });
    module.addIncludePath(b.path("src/c/include"));

    // lib
    const lib = b.addStaticLibrary(.{
        .name               = "glad",
        .target             = b.standardTargetOptions(.{}),
        .optimize           = b.standardOptimizeOption(.{}),
    });

    lib.linkLibC();
    lib.addIncludePath(b.path("src/c/include"));
    lib.addCSourceFile(.{ .file = b.path("src/c/glad.c") });

    b.installArtifact(lib);

}