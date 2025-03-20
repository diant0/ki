const std = @import("std");

step: std.Build.Step,
write_files: *std.Build.Step.WriteFile,

protocols_dir: std.Build.LazyPath,

pub fn create(owner: *std.Build, protocols_dir: std.Build.LazyPath) *@This() {
    const self = owner.allocator.create(@This()) catch @panic("OOM");
    self.* = .{
        .step = std.Build.Step.init(.{
            .id = .custom,
            .name = "generate_wayland_protocol_headers",
            .owner = owner,
        }),
        .write_files = owner.addWriteFiles(),
        .protocols_dir = protocols_dir,
    };
    self.populateWaylandProtocolHeaderWriteFiles() catch @panic("(-_-)");
    self.step.dependOn(&self.write_files.step);
    return self;
}

fn populateWaylandProtocolHeaderWriteFiles(self: *@This()) !void {
    const b = self.step.owner;
    const write_files = self.write_files;
    const wayland_scanner_program = try b.findProgram(&.{"wayland-scanner"}, &.{});

    const protocols_dir_path = blk: {
        const cp = self.protocols_dir.getPath3(b, &self.step);
        break :blk b.pathResolve(&.{ cp.root_dir.path orelse ".", cp.sub_path });
    };
    var protocols_dir = try std.fs.openDirAbsolute(protocols_dir_path, .{ .iterate = true });
    defer protocols_dir.close();
    var protocols_dir_iterator = protocols_dir.iterate();

    while (try protocols_dir_iterator.next()) |protocol_dir_entry| {
        const protocol_filename = switch (protocol_dir_entry.kind) {
            .file => protocol_dir_entry.name,
            else => return error.UnexpectedProtocolDirEntry,
        };
        const protocol_name = if (std.mem.lastIndexOf(u8, protocol_filename, ".")) |extension_dot_index|
            protocol_filename[0..extension_dot_index]
        else
            return error.UnexpectedWaylandProtocolFileFormat;

        const input_file_abspath = try protocols_dir.realpathAlloc(b.allocator, protocol_filename);

        _ = write_files.add(
            b.fmt("{s}-client-protocol.h", .{protocol_name}),
            b.run(&.{
                wayland_scanner_program,
                "client-header",
                input_file_abspath,
                "/dev/stdout",
            }),
        );
        _ = write_files.add(
            b.fmt("{s}-client-protocol-code.h", .{protocol_name}),
            b.run(&.{
                wayland_scanner_program,
                "private-code",
                input_file_abspath,
                "/dev/stdout",
            }),
        );
    }
}
