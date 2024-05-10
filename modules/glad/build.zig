const std = @import("std");

pub fn build(b: *std.Build) !void {

    // module
    const module = b.addModule("glad", .{
        .root_source_file = b.path("src/glad.zig"),
    });
    module.addIncludePath(b.path("glad"));

    // lib
    const lib = b.addStaticLibrary(.{
        .name               = "glad",
        .target             = b.standardTargetOptions(.{}),
        .optimize           = b.standardOptimizeOption(.{}),
    });

    lib.linkLibC();
    lib.addIncludePath(b.path("glad"));
    lib.addCSourceFile(.{ .file = b.path("c/impl.c") });

    b.installArtifact(lib);

}