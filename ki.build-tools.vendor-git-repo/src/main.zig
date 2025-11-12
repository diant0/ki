const std = @import("std");
const argparse = @import("ki.cmdline.argparse");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer switch (gpa.deinit()) {
        .leak => @panic("leak detected"),
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

    const temp_dir: []const u8 = try std.fmt.allocPrint(allocator, "{s}{c}{s}", .{ args.dest, std.fs.path.sep, ".kitemp" });
    defer allocator.free(temp_dir);

    // NOTE: we ride on default git behaviour of
    // creating whole path chain
    var git_pull_process = std.process.Child.init(&.{
        "git",
        "clone",
        args.url,
        temp_dir,
    }, allocator);
    git_pull_process.stdin_behavior = .Close;
    git_pull_process.stdout_behavior = .Close;
    git_pull_process.stderr_behavior = .Close;
    switch (try git_pull_process.spawnAndWait()) {
        .Exited => |exit_code| switch (exit_code) {
            0 => {},
            else => return error.NonZeroExitCode,
        },
        else => return error.UnexpectedTermination,
    }

    // + copy
    var filter_iter = std.mem.splitScalar(u8, args.filters, ',');
    while (filter_iter.next()) |item| {
        switch (item[0]) {
            '+' => {
                const subpath = item[1..];
                std.debug.print("+: {s}\n", .{subpath});
            },
            '-' => {},
            else => return error.ParseError,
        }
    }

    // - delete
    filter_iter.reset();
    while (filter_iter.next()) |item| {
        switch (item[0]) {
            '-' => {
                const subpath = item[1..];
                std.debug.print("-: {s}\n", .{subpath});
            },
            '+' => {},
            else => return error.ParseError,
        }
    }

    try std.fs.deleteTreeAbsolute(temp_dir);
}
