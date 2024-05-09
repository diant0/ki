const std = @import("std");

pub fn build(b: *std.Build) !void {

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name               = "glad",
        .root_source_file   = b.path("src/glad.zig"),
        .target             = target,
        .optimize           = optimize,
    });

    lib.linkLibC();

    lib.addIncludePath(b.path("glad"));
    lib.addCSourceFile(.{ .file = b.path("c/impl.c") });

    b.installArtifact(lib);

}