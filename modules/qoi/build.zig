const std = @import("std");

pub fn build(b: *std.Build) !void {

    // --------------------------------
    
    const module = b.addModule("qoi", .{
        .root_source_file = .{ .path = "src/qoi.zig" },
    });

    module.addIncludePath(.{ .path = repo_path });

    // --------------------------------

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name               = "qoi",
        .root_source_file   = .{ .path = "src/qoi.zig" },
        .target             = target,
        .optimize           = optimize,
    });

    b.installArtifact(lib);

    // --------------------------------

    lib.linkLibC();

    lib.addIncludePath(.{ .path = repo_path });

    try addGeneratedQoiImpl(lib, "qoi.h", "QOI_IMPLEMENTATION");

}

const repo_path = "qoi";

fn addGeneratedQoiImpl(compile: *std.Build.Step.Compile, header: []const u8, impl_define: []const u8) !void {

    const b = compile.step.owner;

    const cache_dir = b.cache_root.handle;

    var qoi_impls_dir = try cache_dir.makeOpenPath("generated/qoi/impls", .{});
    defer qoi_impls_dir.close();
    
    const qoi_impl_filename = "qoi.c";
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