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

    const math = b.dependency("math", .{});
    module.addImport("math", math.module("math"));

    // --------------------------------

    const glfw_x11     = b.option(bool, "glfw_x11", "")     orelse true;
    const glfw_wayland = b.option(bool, "glfw_wayland", "") orelse true;

    const glfw = b.dependency("glfw", .{
        .x11        = glfw_x11,
        .wayland    = glfw_wayland,
    });
    module.addImport("glfw", glfw.module("glfw"));
    lib.linkLibrary(glfw.artifact("glfw"));

    // --------------------------------

    const gl = b.dependency("gl", .{});
    module.addImport("gl", gl.module("gl"));

    // --------------------------------

    const stb = b.dependency("stb", .{
        .image      = true,
        .truetype   = true,
    });

    module.addImport("stb", stb.module("stb"));
    lib.linkLibrary(stb.artifact("stb"));

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