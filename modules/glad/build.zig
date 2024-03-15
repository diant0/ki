const std = @import("std");

pub fn build(b: *std.Build) !void {

    const module = b.addModule("glad", .{
        .root_source_file = .{ .path = "src/glad.zig" },
    });
    module.addIncludePath(.{ .path = "glad" });

    // --------------------------------

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name               = "glad",
        .root_source_file   = .{ .path = "src/glad.zig" },
        .target             = target,
        .optimize           = optimize,
    });

    b.installArtifact(lib);

    // --------------------------------

    lib.linkLibC();

    lib.addIncludePath(.{ .path = "glad" });

    try addGeneratedGLADImpl(lib, "glad.h", "GLAD_GL_IMPLEMENTATION");

}

fn addGeneratedGLADImpl(compile: *std.Build.Step.Compile, header: []const u8, impl_define: []const u8) !void {

    const b = compile.step.owner;

    const cache_dir = b.cache_root.handle;

    var qoi_impls_dir = try cache_dir.makeOpenPath("glad", .{});
    defer qoi_impls_dir.close();
    
    const qoi_impl_filename = "glad.c";
    const qoi_impl_file = qoi_impls_dir.openFile(qoi_impl_filename, .{}) catch | e | blk: {
    
        if (e == error.FileNotFound) {

            const new_impl_file = try qoi_impls_dir.createFile(qoi_impl_filename, .{});
            try new_impl_file.writer().print("#define {s}\n#include \"{s}\"\n", .{ impl_define, header });
            break :blk new_impl_file;

        } else return e;
    
    };
    qoi_impl_file.close();

    const qoi_impl_file_abspath = try qoi_impls_dir.realpathAlloc(b.allocator, qoi_impl_filename);
    defer b.allocator.free(qoi_impl_file_abspath);

    compile.addCSourceFile(.{
        .file = .{ .path = qoi_impl_file_abspath },
        .flags = &[_][]const u8 {},
    });

}