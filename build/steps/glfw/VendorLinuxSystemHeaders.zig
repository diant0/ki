// TODO: maybe needs to be split by x11/wayland/generated-wayland

const std = @import("std");
const GeneratedWaylandProtocolHeadersWriteFiles = @import("GeneratedWaylandProtocolHeadersWriteFiles.zig");

step: std.Build.Step,
generate_wayland_protocol_headers: *GeneratedWaylandProtocolHeadersWriteFiles,
dest_dir: std.Build.LazyPath,

pub const Options = struct {
    wayland_protocols_dir: std.Build.LazyPath,
    dest_dir: std.Build.LazyPath,
};

pub fn create(owner: *std.Build, options: Options) *@This() {
    const self = owner.allocator.create(@This()) catch @panic("OOM");
    self.* = .{
        .step = std.Build.Step.init(.{
            .id = .custom,
            .name = "vendor_linux_system_headers",
            .owner = owner,
            .makeFn = @This().make,
        }),
        .generate_wayland_protocol_headers = GeneratedWaylandProtocolHeadersWriteFiles.create(owner, options.wayland_protocols_dir),
        .dest_dir = options.dest_dir,
    };
    self.step.dependOn(&self.generate_wayland_protocol_headers.step);
    return self;
}

pub fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
    const b = step.owner;
    const self: *@This() = @fieldParentPtr("step", step);

    { // generated
        const src_cache_dir = self.generate_wayland_protocol_headers.write_files.getDirectory().getPath3(b, step);
        const src_dir_path = b.pathResolve(&.{ src_cache_dir.root_dir.path orelse ".", src_cache_dir.sub_path });

        var src_dir = try std.fs.openDirAbsolute(src_dir_path, .{ .iterate = true });
        defer src_dir.close();

        var dest_dir = blk: {
            const cache_dir = self.dest_dir.path(b, "wayland-protocols").getPath3(b, step);
            const dir_path = b.pathResolve(&.{ cache_dir.root_dir.path orelse ".", cache_dir.sub_path });

            std.fs.deleteTreeAbsolute(dir_path) catch |e| switch (e) {
                error.FileNotFound => {},
                else => return e,
            };

            try std.fs.makeDirAbsolute(dir_path);
            break :blk try std.fs.openDirAbsolute(dir_path, .{});
        };
        defer dest_dir.close();

        var src_dir_iterator = src_dir.iterate();
        while (try src_dir_iterator.next()) |src_dir_entry| {
            switch (src_dir_entry.kind) {
                .file => try src_dir.copyFile(src_dir_entry.name, dest_dir, src_dir_entry.name, .{}),
                else => return error.UnexpectedWaylandProtocolHeadersDirEntry,
            }
        }
    }

    { // system
        var src_dir = try std.fs.openDirAbsolute("/usr/include/", .{});
        defer src_dir.close();

        var wayland_dest_dir = blk: {
            const cache_dir = self.dest_dir.path(b, "wayland").getPath3(b, step);
            const dir_path = b.pathResolve(&.{ cache_dir.root_dir.path orelse ".", cache_dir.sub_path });

            std.fs.deleteTreeAbsolute(dir_path) catch |e| switch (e) {
                error.FileNotFound => {},
                else => return e,
            };

            try std.fs.makeDirAbsolute(dir_path);
            break :blk try std.fs.openDirAbsolute(dir_path, .{});
        };
        defer wayland_dest_dir.close();

        const wayland_headers = &[_][]const u8{
            "wayland-client.h",
            "wayland-client-core.h",
            "wayland-util.h",
            "wayland-version.h",
            "xkbcommon/xkbcommon.h",
            "xkbcommon/xkbcommon-names.h",
            "xkbcommon/xkbcommon-keysyms.h",
            "xkbcommon/xkbcommon-compat.h",
            "xkbcommon/xkbcommon-compose.h",
        };

        for (wayland_headers) |header| {
            if (std.fs.path.dirname(header)) |dirname|
                try wayland_dest_dir.makePath(dirname);
            try src_dir.copyFile(header, wayland_dest_dir, header, .{});
        }

        var x11_dest_dir = blk: {
            const cache_dir = self.dest_dir.path(b, "x11").getPath3(b, step);
            const dir_path = b.pathResolve(&.{ cache_dir.root_dir.path orelse ".", cache_dir.sub_path });

            std.fs.deleteTreeAbsolute(dir_path) catch |e| switch (e) {
                error.FileNotFound => {},
                else => return e,
            };

            try std.fs.makeDirAbsolute(dir_path);
            break :blk try std.fs.openDirAbsolute(dir_path, .{});
        };
        defer x11_dest_dir.close();

        const x11_headers = &[_][]const u8{
            "X11/Xlib.h",
            "X11/X.h",
            "X11/Xfuncproto.h",
            "X11/Xosdefs.h",
            "X11/keysym.h",
            "X11/keysymdef.h",
            "X11/Xatom.h",
            "X11/Xresource.h",
            "X11/Xutil.h",
            "X11/Xdefs.h",
            "X11/XKBlib.h",
            "X11/cursorfont.h",
            "X11/Xmd.h",
            "X11/Xcursor/Xcursor.h",
            "X11/extensions/Xrandr.h",
            "X11/extensions/randr.h",
            "X11/extensions/Xrender.h",
            "X11/extensions/render.h",
            "X11/extensions/XKBstr.h",
            "X11/extensions/XKB.h",
            "X11/extensions/Xinerama.h",
            "X11/extensions/XInput2.h",
            "X11/extensions/XI2.h",
            "X11/extensions/Xge.h",
            "X11/extensions/Xfixes.h",
            "X11/extensions/xfixeswire.h",
            "X11/extensions/shape.h",
            "X11/extensions/shapeconst.h",
        };

        for (x11_headers) |header| {
            if (std.fs.path.dirname(header)) |dirname|
                try x11_dest_dir.makePath(dirname);
            try src_dir.copyFile(header, x11_dest_dir, header, .{});
        }
    }
}
