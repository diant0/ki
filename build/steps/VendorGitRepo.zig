const std = @import("std");

step: std.Build.Step,

dest_dir: std.Build.LazyPath,
url: []const u8,
checkout_target: ?[]const u8,
copy_paths: ?[]const []const u8,
exclude_paths: []const []const u8,
exclude_basenames: []const []const u8,
redirect_map: []const RedirectMapEntry,
clean_before_copying: bool,

pub fn create(owner: *std.Build, options: Options) *@This() {
    const self = owner.allocator.create(@This()) catch @panic("OOM");
    self.* = .{
        .step = std.Build.Step.init(.{
            .id = .custom,
            .owner = owner,
            .name = "vendor_git_repo",
            .makeFn = @This().make,
        }),
        .dest_dir = options.dest_dir,
        .url = options.url,
        .checkout_target = options.checkout_target,
        .copy_paths = options.copy_paths,
        .exclude_paths = options.exclude_paths,
        .exclude_basenames = options.exclude_basenames,
        .redirect_map = options.redirect_map,
        .clean_before_copying = options.clean_before_copying,
    };
    return self;
}

fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
    const b = step.owner;
    const self: *@This() = @fieldParentPtr("step", step);

    const git_program = try b.findProgram(&.{"git"}, &.{});
    const temp_dir_path = b.makeTempPath();
    defer std.fs.deleteTreeAbsolute(temp_dir_path) catch {};

    _ = b.run(&.{
        git_program,
        "clone",
        self.url,
        temp_dir_path,
    });

    if (self.checkout_target) |checkout_target| {
        _ = b.run(&.{
            git_program,
            "-C",
            temp_dir_path,
            "checkout",
            "-q",
            checkout_target,
        });
    }

    const dest_dir_path = blk: {
        const cp = self.dest_dir.getPath3(b, step);
        break :blk b.pathResolve(&.{ cp.root_dir.path orelse ".", cp.sub_path });
    };

    if (self.clean_before_copying) {
        std.fs.deleteTreeAbsolute(dest_dir_path) catch |e| switch (e) {
            error.FileNotFound => {},
            else => return e,
        };
        try std.fs.makeDirAbsolute(dest_dir_path);
    }

    var src_dir = try std.fs.openDirAbsolute(temp_dir_path, .{ .iterate = true });
    defer src_dir.close();
    var dest_dir = try std.fs.openDirAbsolute(dest_dir_path, .{});
    defer dest_dir.close();

    var paths_to_map = std.ArrayList([]const u8).init(b.allocator);
    defer paths_to_map.deinit();

    if (self.copy_paths) |copy_paths| {
        try paths_to_map.appendSlice(copy_paths);
    } else {
        var iterator = src_dir.iterate();
        while (try iterator.next()) |entry| {
            std.debug.print("{s}\n", .{entry.name});
            try paths_to_map.append(entry.name);
        }
    }

    for (self.redirect_map) |redirect|
        try paths_to_map.append(redirect.src);

    for (paths_to_map.items) |src_path| {
        switch ((try src_dir.statFile(src_path)).kind) {
            .file => {
                if (self.mapPath(src_path)) |dest_path| {
                    if (std.fs.path.dirname(dest_path)) |dirname| try dest_dir.makePath(dirname);
                    try src_dir.copyFile(src_path, dest_dir, dest_path, .{});
                }
            },
            .directory => {
                var src_subdir = try src_dir.openDir(src_path, .{ .iterate = true });
                defer src_subdir.close();
                var src_subdir_walker = try src_subdir.walk(b.allocator);
                defer src_subdir_walker.deinit();
                while (try src_subdir_walker.next()) |src_subdir_entry| {
                    switch (src_subdir_entry.kind) {
                        .file => {
                            const src_subpath = b.fmt("{s}/{s}", .{ src_path, src_subdir_entry.path });
                            if (self.mapPath(src_subpath)) |dest_subpath| {
                                if (std.fs.path.dirname(dest_subpath)) |dirname| try dest_dir.makePath(dirname);
                                try src_dir.copyFile(src_subpath, dest_dir, dest_subpath, .{});
                            }
                        },
                        else => {},
                    }
                }
            },
            else => return error.UnexpectedCopyListEntryKind,
        }
    }
}

const Options = struct {
    dest_dir: std.Build.LazyPath,
    url: []const u8,
    checkout_target: ?[]const u8 = null,
    copy_paths: ?[]const []const u8 = null,
    exclude_paths: []const []const u8 = &.{".git"},
    exclude_basenames: []const []const u8 = &.{},
    redirect_map: []const RedirectMapEntry = &.{},
    clean_before_copying: bool = true,
};

const RedirectMapEntry = struct { src: []const u8, dest: []const u8 };

fn isPathInExcludeList(self: *const @This(), path: []const u8) bool {
    return for (self.exclude_paths) |exclude_list_entry| {
        if (std.mem.eql(u8, exclude_list_entry, path)) break true;
    } else false;
}

fn isBasenameInExcludeList(self: *const @This(), basename: []const u8) bool {
    return for (self.exclude_basenames) |excluded_filename| {
        if (std.mem.eql(u8, excluded_filename, basename)) break true;
    } else false;
}

fn isExcluded(self: *const @This(), path: []const u8) bool {
    if (self.isPathInExcludeList(path)) return true;
    if (self.isBasenameInExcludeList(std.fs.path.basename(path))) return true;
    return false;
}

fn mapPath(self: *const @This(), path: []const u8) ?[]const u8 {
    if (self.isExcluded(path)) return null;
    return for (self.redirect_map) |redirect| {
        if (std.mem.eql(u8, redirect.src, path)) break redirect.dest;
    } else path;
}
