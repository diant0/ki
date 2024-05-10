const std = @import("std");

pub fn build(b: *std.Build) !void {

    // module
    const module = b.addModule("qoi", .{
        .root_source_file = b.path("src/qoi.zig"),
    });
    module.addIncludePath(b.path("qoi"));

    // lib
    const lib = b.addStaticLibrary(.{
        .name               = "qoi",
        .target             = b.standardTargetOptions(.{}),
        .optimize           = b.standardOptimizeOption(.{}),
    });

    lib.linkLibC();
    lib.addIncludePath(b.path("qoi"));
    lib.addCSourceFile(.{ .file = b.path("c/impl.c") });

    b.installArtifact(lib);

}