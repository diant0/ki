const std = @import("std");

pub fn build(b: *std.Build) !void {

    // --------------------------------

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    // --------------------------------

    const module = b.addModule("glad", .{
        .root_source_file = b.path("src/glad.zig"),
    });
    module.addIncludePath(b.path("glad"));

    // --------------------------------

    const lib = b.addStaticLibrary(.{
        .name               = "glad",
        .root_source_file   = b.path("src/glad.zig"),
        .target             = target,
        .optimize           = optimize,
    });

    lib.linkLibC();
    lib.addIncludePath(b.path("glad"));

    try addGeneratedImpl(lib, "glad", "glad.c", "glad.h", "GLAD_GL_IMPLEMENTATION");

    b.installArtifact(lib);

    // --------------------------------

}

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
        .file = .{ .cwd_relative = impl_file_abspath },
        .flags = &[_][]const u8 {},
    });

}