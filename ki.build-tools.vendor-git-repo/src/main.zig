const std = @import("std");
const argparse = @import("ki.cmdline.argparse");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer switch (gpa.deinit()) {
        .leak => std.debug.panic("leak detected\n", .{}),
        .ok => {},
    };

    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    const args = try argparse.toStructTempAlloc(struct {
        url: []const u8,
        dest: []const u8,
        commit: ?[]const u8 = null,
        filters: []const u8,
    }, allocator, argv[1..]);

    const temp_dir_path: []const u8 = try std.fmt.allocPrint(allocator, "{s}{c}{s}", .{ args.dest, std.fs.path.sep, ".kitemp" });
    defer allocator.free(temp_dir_path);

    std.fs.deleteTreeAbsolute(args.dest) catch |e| switch (e) {
        error.FileNotFound => {},
        else => return e,
    };

    // NOTE: we ride on default git behaviour of
    // creating whole path chain
    const git_pull_process_output = try runProcessCaptureOutput(allocator, &.{
        "git",
        "clone",
        args.url,
        temp_dir_path,
    });
    git_pull_process_output.free(allocator);

    defer std.fs.deleteTreeAbsolute(temp_dir_path) catch |e| {
        std.debug.panic("could not delete temporary directory \"{s}\", {s}", .{ temp_dir_path, @errorName(e) });
    };

    var temp_dir = try std.fs.openDirAbsolute(temp_dir_path, .{});
    defer temp_dir.close();

    if (args.commit) |commit| {
        const cwd = std.fs.cwd();
        try temp_dir.setAsCwd();

        const git_checkout_output = try runProcessCaptureOutput(allocator, &.{
            "git",
            "checkout",
            commit,
        });
        git_checkout_output.free(allocator);

        try cwd.setAsCwd();
    }

    var vendor_dest_dir = try std.fs.openDirAbsolute(args.dest, .{});
    defer vendor_dest_dir.close();

    { // vendor_info_file
        const cwd = std.fs.cwd();
        try temp_dir.setAsCwd();

        const output = try runProcessCaptureOutput(allocator, &.{
            "git",
            "rev-parse",
            "--verify",
            "HEAD",
        });

        const file = try vendor_dest_dir.createFile(".kivendor", .{});
        defer file.close();

        var writer_buffer: [1024]u8 = undefined;
        var writer = file.writer(&writer_buffer);
        try writer.interface.print(".url={s}\n.commit={s}", .{ args.url, output.stdout });
        try writer.interface.flush();

        output.free(allocator);
        try cwd.setAsCwd();
    }

    // + copy
    var filter_iter = std.mem.splitScalar(u8, args.filters, ',');
    while (filter_iter.next()) |filter| {
        switch (filter[0]) {
            '+' => {
                const filter_target_subpath = filter[1..];
                const target_stat = try temp_dir.statFile(filter_target_subpath);
                switch (target_stat.kind) {
                    .file => {
                        var cp_src_path_buffer: [std.fs.max_path_bytes]u8 = undefined;
                        const cp_src_path = try temp_dir.realpath(filter_target_subpath, &cp_src_path_buffer);

                        var cp_dest_path_buffer: [std.fs.max_path_bytes]u8 = undefined;
                        const cp_dest_path = try std.fmt.bufPrint(&cp_dest_path_buffer, "{s}{c}{s}", .{ args.dest, std.fs.path.sep, filter_target_subpath });

                        try std.fs.copyFileAbsolute(cp_src_path, cp_dest_path, .{});
                    },
                    .directory => {
                        var cp_src_dir = try temp_dir.openDir(filter_target_subpath, .{ .iterate = true });
                        defer cp_src_dir.close();

                        var cp_src_dir_walker = try cp_src_dir.walk(allocator);
                        defer cp_src_dir_walker.deinit();

                        try vendor_dest_dir.makePath(filter_target_subpath);
                        while (try cp_src_dir_walker.next()) |cp_src_dir_entry| {
                            switch (cp_src_dir_entry.kind) {
                                .file => {
                                    var cp_src_path_buffer: [std.fs.max_path_bytes]u8 = undefined;
                                    const cp_src_path = try cp_src_dir.realpath(cp_src_dir_entry.path, &cp_src_path_buffer);
                                    var cp_dest_path_buffer: [std.fs.max_path_bytes]u8 = undefined;
                                    const cp_dest_path = try std.fmt.bufPrint(&cp_dest_path_buffer, "{s}{c}{s}{c}{s}", .{ args.dest, std.fs.path.sep, filter_target_subpath, std.fs.path.sep, cp_src_dir_entry.path });
                                    try std.fs.copyFileAbsolute(cp_src_path, cp_dest_path, .{});
                                },
                                .directory => {
                                    var makedir_target_subpath_buffer: [std.fs.max_path_bytes]u8 = undefined;
                                    const makedir_target_subpath = try std.fmt.bufPrint(&makedir_target_subpath_buffer, "{s}{c}{s}", .{ filter_target_subpath, std.fs.path.sep, cp_src_dir_entry.path });
                                    try vendor_dest_dir.makePath(makedir_target_subpath);
                                },
                                else => return error.UnsupportedFileKind,
                            }
                        }
                    },
                    else => return error.UnsupportedFileKind,
                }
            },
            '-' => {},
            else => return error.ParseError,
        }
    }

    // - delete
    filter_iter.reset();
    while (filter_iter.next()) |filter| {
        switch (filter[0]) {
            '-' => {
                const filter_target_subpath = filter[1..];
                const target_stat = try temp_dir.statFile(filter_target_subpath);
                switch (target_stat.kind) {
                    .file => try vendor_dest_dir.deleteFile(filter_target_subpath),
                    .directory => try vendor_dest_dir.deleteDir(filter_target_subpath),
                    else => return error.UnsupportedFileKind,
                }
            },
            '+' => {},
            else => return error.ParseError,
        }
    }
}

fn runProcessCaptureOutput(allocator: std.mem.Allocator, args: []const []const u8) !ProcessOutput {
    var process = std.process.Child.init(args, allocator);
    process.stdin_behavior = .Close;
    process.stdout_behavior = .Pipe;
    process.stderr_behavior = .Pipe;

    try process.spawn();

    var stdout: std.ArrayList(u8) = .empty;
    var stderr: std.ArrayList(u8) = .empty;
    try process.collectOutput(allocator, &stdout, &stderr, std.math.maxInt(usize));

    switch (try process.wait()) {
        .Exited => |exit_code| switch (exit_code) {
            0 => {},
            else => return error.NonZeroExitCode,
        },
        else => return error.UnexpectedTermination,
    }

    return .{
        .stdout = try stdout.toOwnedSlice(allocator),
        .stderr = try stderr.toOwnedSlice(allocator),
    };
}

const ProcessOutput = struct {
    stdout: []const u8,
    stderr: []const u8,

    pub fn free(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }
};
