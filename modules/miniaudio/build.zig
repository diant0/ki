const std = @import("std");

pub fn build(b: *std.Build) !void {

    // module
    const module = b.addModule("miniaudio", .{
        .root_source_file = b.path("src/miniaudio.zig"),
    });
    module.addIncludePath(b.path("miniaudio"));

    // lib
    const lib = b.addStaticLibrary(.{
        .name               = "miniaudio",
        .target             = b.standardTargetOptions(.{}),
        .optimize           = b.standardOptimizeOption(.{}),
    });

    lib.linkLibC();
    lib.addIncludePath(b.path("miniaudio"));
    lib.addCSourceFile(.{ .file = b.path("c/impl.c")});

    b.installArtifact(lib);

}