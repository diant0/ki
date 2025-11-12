const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vendor_git_repo = b.dependency("ki.build-tools.vendor-git-repo", .{
        .target = .native,
        .optimize = .Debug,
    }).artifact("exe");

    const vendor_glfw_commit = b.option([]const u8, "vendor-glfw-commit", "specifies glfw commit to vendor, uses latest when unset");
    const run_vendor_git_repo_glfw = b.addRunArtifact(vendor_git_repo);
    run_vendor_git_repo_glfw.addArgs(&.{
        ".url=https://github.com/glfw/glfw",
        b.fmt(".dest={s}", .{b.pathResolve(&.{ b.build_root.path orelse ".", "vendor/glfw" })}),
        // copy/filter lists will go here
        ".filters=+src,-src/CMakeLists.txt,+include,+deps/wayland,+LICENSE.md",
    });
    if (vendor_glfw_commit) |commit| {
        run_vendor_git_repo_glfw.addArg(b.fmt("commit={s}", .{commit}));
    }

    const vendor_glfw = b.step("vendor-glfw", "updates glfw source, see -Dvendor-glfw-coomit option");
    vendor_glfw.dependOn(&run_vendor_git_repo_glfw.step);

    _ = target;
    _ = optimize;
}
