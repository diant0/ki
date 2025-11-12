const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("ki.cmdline.argparse", .{
        .root_source_file = b.path("src/root.zig"),
    });
}
