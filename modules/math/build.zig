const std = @import("std");

pub fn build(b: *std.Build) void {

    _ = b.addModule("math", .{
        .root_source_file = b.path("src/math.zig"),
    });

    const tests = b.addTest(.{
        .root_source_file   = b.path("src/math.zig"),
        .target             = b.standardTargetOptions(.{}),
        .optimize           = b.standardOptimizeOption(.{}),
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

}
