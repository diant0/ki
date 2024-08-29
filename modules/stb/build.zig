const std = @import("std");

pub fn build(b: *std.Build) !void {

    // parameters
    const build_stb_image = b.option(bool, "image", "build stb_image") orelse false;
    const build_stb_image_write = b.option(bool, "image_write", "build stb_image_write") orelse false;
    const build_stb_truetype = b.option(bool, "truetype", "build stb_truetype") orelse false;

    const config = b.addOptions();

    config.addOption(bool, "stb_image", build_stb_image);
    config.addOption(bool, "stb_image_write", build_stb_image_write);
    config.addOption(bool, "stb_truetype", build_stb_truetype);

    // module
    const module = b.addModule("stb", .{
        .root_source_file = b.path("src/module.zig"),
    });
    module.addOptions("config", config);
    module.addIncludePath(b.path("src/stb"));

    // lib
    const lib = b.addStaticLibrary(.{
        .name = "stb",
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    lib.linkLibC();
    lib.addIncludePath(b.path("src/stb"));

    if (build_stb_image) {
        lib.addCSourceFile(.{ .file = b.path("src/c/stb_image.c") });
    }

    if (build_stb_image_write) {
        lib.addCSourceFile(.{ .file = b.path("src/c/stb_image_write.c") });
    }

    if (build_stb_truetype) {
        lib.addCSourceFile(.{ .file = b.path("src/c/stb_truetype.c") });
    }

    b.installArtifact(lib);
}
