const std = @import("std");

pub fn build(b: *std.Build) !void {

    const lib = b.addStaticLibrary(.{
        .name               = "glad",
        .root_source_file   = b.path("src/glad.zig"),
        .target             = b.standardTargetOptions(.{}),
        .optimize           = b.standardOptimizeOption(.{}),
    });

    lib.linkLibC();

    lib.addIncludePath(b.path("glad"));
    lib.addCSourceFile(.{ .file = b.path("c/impl.c") });

    b.installArtifact(lib);

}