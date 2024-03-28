const std = @import("std");

pub fn build(b: *std.Build) !void {

    // --------------------------------

    const module = b.addModule("ki", .{
        .root_source_file = .{ .path = "src/ki.zig" },
    });

    // --------------------------------

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name               = "ki",
        .root_source_file   = .{ .path = "src/ki.zig" },
        .target             = target,
        .optimize           = optimize,
    });

    b.installArtifact(lib);

    // --------------------------------

    const math = b.dependency("math", .{
        .target     = target,
        .optimize   = optimize,
    });
    module.addImport("math", math.module("math"));

    // --------------------------------

    const glfw_x11     = b.option(bool, "glfw_x11", "")     orelse true;
    const glfw_wayland = b.option(bool, "glfw_wayland", "") orelse true;

    const glfw = b.dependency("glfw", .{
        .target     = target,
        .optimize   = optimize,
        .x11        = glfw_x11,
        .wayland    = glfw_wayland,
    });
    module.addImport("glfw", glfw.module("glfw"));
    lib.linkLibrary(glfw.artifact("glfw"));

    // --------------------------------

    const glad = b.dependency("glad", .{
        .target     = target,
        .optimize   = optimize,
    });
    module.addImport("glad", glad.module("glad"));
    lib.linkLibrary(glad.artifact("glad"));

    // --------------------------------

    const stb = b.dependency("stb", .{
        .target         = target,
        .optimize       = optimize,
        .image          = true,
        .image_write    = true,
        .truetype       = true,
    });

    module.addImport("stb", stb.module("stb"));
    lib.linkLibrary(stb.artifact("stb"));

    // --------------------------------

    const qoi = b.dependency("qoi", .{
        .target         = target,
        .optimize       = optimize,
    });
    module.addImport("qoi", qoi.module("qoi"));
    lib.linkLibrary(qoi.artifact("qoi"));

    // --------------------------------

    const main_tests = b.addTest(.{
        .root_source_file   = .{ .path = "src/ki.zig" },
        .target             = target,
        .optimize           = optimize,
    });
    main_tests.root_module.addImport("math", math.module("math"));
    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // --------------------------------

}