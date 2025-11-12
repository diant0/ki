const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ki_cmdline_argparse = b.dependency("ki_cmdline_argparse", .{});

    const exe = b.addExecutable(.{
        .name = "exe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "ki.cmdline.argparse",
                    .module = ki_cmdline_argparse.module("ki.cmdline.argparse"),
                },
            },
        }),
    });

    const install_exe = b.addInstallArtifact(exe, .{});
    b.default_step.dependOn(&install_exe.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&install_exe.step);
    if (b.args) |args|
        run_cmd.addArgs(args);

    const run_step = b.step("run", "run executable");
    run_step.dependOn(&run_cmd.step);
}
