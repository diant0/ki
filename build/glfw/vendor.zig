const std = @import("std");
const VendorGitRepo = @import("../steps/VendorGitRepo.zig");

pub fn glfw(b: *std.Build, name: []const u8, dest_dir: std.Build.LazyPath) *std.Build.Step {
    const vendor_repo = VendorGitRepo.create(b, .{
        .url = "https://github.com/glfw/glfw",
        .dest_dir = dest_dir,
        .copy_paths = &.{
            "deps",
            "include",
            "src",
            "LICENSE.md",
        },
        .exclude_basenames = &.{"CMakeLists.txt"},
    });
    const step = b.step(name, "vendor latest glfw");
    step.dependOn(&vendor_repo.step);
    return step;
}
