const std = @import("std");

pub fn build(b: *std.Build) !void {

    // --------------------------------

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    // --------------------------------


    const module = b.addModule("qoi", .{
        .root_source_file = .{ .path = "src/qoi.zig" },
    });

    module.addIncludePath(.{ .path = repo_path });

    // --------------------------------

    const lib = b.addStaticLibrary(.{
        .name               = "qoi",
        .root_source_file   = .{ .path = "src/qoi.zig" },
        .target             = target,
        .optimize           = optimize,
    });

    lib.linkLibC();
    lib.addIncludePath(.{ .path = repo_path });

    try addGeneratedImpl(lib, "qoi", "qoi.c", "qoi.h", "QOI_IMPLEMENTATION");

    b.installArtifact(lib);

    // --------------------------------

}

const repo_path = "qoi";

fn addGeneratedImpl(compile: *std.Build.Step.Compile, cache_subpath: []const u8, impl_filename: []const u8, header: []const u8, impl_define: []const u8) !void {

    const b = compile.step.owner;

    const cache_dir = b.cache_root.handle;

    var impls_dir = try cache_dir.makeOpenPath(cache_subpath, .{});
    defer impls_dir.close();
    
    const impl_file = impls_dir.openFile(impl_filename, .{}) catch | e | blk: {
    
        if (e == error.FileNotFound) {

            const new_impl_file = try impls_dir.createFile(impl_filename, .{});
            try new_impl_file.writer().print("#define {s}\n#include \"{s}\"\n", .{ impl_define, header });
            break :blk new_impl_file;

        } else return e;
    
    };
    impl_file.close();

    const impl_file_abspath = try impls_dir.realpathAlloc(b.allocator, impl_filename);
    defer b.allocator.free(impl_file_abspath);

    compile.addCSourceFile(.{
        .file = .{ .path = impl_file_abspath },
        .flags = &[_][]const u8 {},
    });

}