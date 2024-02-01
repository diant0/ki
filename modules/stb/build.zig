const std = @import("std");

pub fn build(b: *std.Build) !void {

    // --------------------------------
    
    const module = b.addModule("stb", .{
        .root_source_file = .{ .path = "src/stb.zig" },
    });

    module.addIncludePath(.{ .path = repo_path });

    // --------------------------------

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name               = "stb",
        .root_source_file   = .{ .path = "src/stb.zig" },
        .target             = target,
        .optimize           = optimize,
    });

    b.installArtifact(lib);

    // --------------------------------

    lib.linkLibC();

    lib.addIncludePath(.{ .path = repo_path });

    if (b.option(bool, "image", "build stb_image") orelse false) {
        try addGeneratedStbImpl(lib, "stb_image.h", "STB_IMAGE_IMPLEMENTATION");
    }

    if (b.option(bool, "truetype", "build stb_truetype") orelse false) {
        try addGeneratedStbImpl(lib, "stb_truetype.h", "STB_TRUETYPE_IMPLEMENTATION");
    }

}

const repo_path = "stb";
const generated_impls_subpath = "generated/stb/impls";

fn addGeneratedStbImpl(compile: *std.Build.Step.Compile, header: []const u8, impl_define: []const u8) !void {
    const b = compile.step.owner;

    const cache_dir = b.cache_root.handle;

    var stb_impls_dir = try cache_dir.makeOpenPath(generated_impls_subpath, .{});
    defer stb_impls_dir.close();

    const stb_lib_name = try blk: {
        const last_dot_index = std.mem.lastIndexOf(u8, header, ".");
        if (last_dot_index) | extension_dot_index | {
            break :blk header[0..extension_dot_index];
        } else break :blk error.UndexpectedStbHeaderFilename;
    };
    
    var stb_impl_filename_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const stb_impl_filename = try std.fmt.bufPrint(&stb_impl_filename_buf, "{s}.c", .{ stb_lib_name });

    const stb_impl_file = stb_impls_dir.openFile(stb_impl_filename, .{}) catch | e | blk: {
    
        if (e == error.FileNotFound) {

            const new_impl_file = try stb_impls_dir.createFile(stb_impl_filename, .{});
            try new_impl_file.writer().print("#define {s}\n#include \"{s}\"\n", .{ impl_define, header });
            break :blk new_impl_file;

        } else return e;
    
    };
    stb_impl_file.close();

    const stb_impl_file_abspath = try stb_impls_dir.realpathAlloc(b.allocator, stb_impl_filename);
    defer b.allocator.free(stb_impl_file_abspath);

    compile.addCSourceFile(.{
        .file = .{ .path = stb_impl_file_abspath },
        .flags = &[_][]const u8 {},
    });

}