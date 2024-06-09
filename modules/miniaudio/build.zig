const std = @import("std");

pub fn build(b: *std.Build) !void {

    // module
    const module = b.addModule("miniaudio", .{
        .root_source_file = b.path("src/module.zig"),
    });
    module.addIncludePath(b.path("src/miniaudio"));

    // lib
    const lib = b.addStaticLibrary(.{
        .name               = "miniaudio",
        .target             = b.standardTargetOptions(.{}),
        .optimize           = b.standardOptimizeOption(.{}),
    });

    lib.linkLibC();
    lib.addIncludePath(b.path("src/miniaudio"));
    lib.addCSourceFile(.{ .file = b.path("src/c/miniaudio.c")});

    b.installArtifact(lib);

}