const std = @import("std");

pub fn build(b: *std.Build) !void {

    // --------------------------------

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    // --------------------------------

    const config = b.addOptions();

    const build_stb_image = b.option(bool, "image", "build stb_image") orelse false;
    config.addOption(bool, "stb_image", build_stb_image);

    const build_stb_image_write = b.option(bool, "image_write", "build stb_image_write") orelse false;
    config.addOption(bool, "stb_image_write", build_stb_image_write);

    const build_stb_truetype = b.option(bool, "truetype", "build stb_truetype") orelse false;
    config.addOption(bool, "stb_truetype", build_stb_truetype);

    // --------------------------------
    
    const module = b.addModule("stb", .{
        .root_source_file = .{ .path = "src/stb.zig" },
    });

    module.addOptions("config", config);
    module.addIncludePath(.{ .path = repo_path });

    // --------------------------------

    const lib = b.addStaticLibrary(.{
        .name               = "stb",
        .root_source_file   = .{ .path = "src/stb.zig" },
        .target             = target,
        .optimize           = optimize,
    });

    lib.root_module.addOptions("config", config);

    lib.linkLibC();
    lib.addIncludePath(.{ .path = repo_path });

    const cache_subpath = "stb";

    if (build_stb_image) {
        try addGeneratedImpl(lib, cache_subpath, "stb_image.c", "stb_image.h", "STB_IMAGE_IMPLEMENTATION");
    }

    if (build_stb_image_write) {
        try addGeneratedImpl(lib, cache_subpath, "stb_image_write.c", "stb_image_write.h", "STB_IMAGE_WRITE_IMPLEMENTATION");
    }

    if (build_stb_truetype) {
        try addGeneratedImpl(lib, cache_subpath, "stb_truetype.c", "stb_truetype.h", "STB_TRUETYPE_IMPLEMENTATION");
    }

    b.installArtifact(lib);

    // --------------------------------

}

const repo_path = "stb";

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