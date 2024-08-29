const std = @import("std");

pub fn build(b: *std.Build) !void {

    // module
    const module = b.addModule("qoi", .{
        .root_source_file = b.path("src/module.zig"),
    });
    module.addIncludePath(b.path("src/qoi"));

    // lib
    const lib = b.addStaticLibrary(.{
        .name = "qoi",
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    lib.linkLibC();
    lib.addIncludePath(b.path("src/qoi"));
    lib.addCSourceFile(.{ .file = b.path("src/c/qoi.c") });

    b.installArtifact(lib);
}
