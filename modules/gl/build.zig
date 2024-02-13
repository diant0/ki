const std = @import("std");

pub fn build(b: *std.Build) !void {

    const target = b.standardTargetOptions(.{});

    const module = b.addModule("gl", .{
        .root_source_file = .{ .path = "src/gl.zig" },
    });

    switch (target.result.os.tag) {

        .linux => {
            module.addIncludePath(.{ .path = "/usr/include" });
        },

        else => return error.UnsupportedOS,

    }

}