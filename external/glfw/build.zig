const std = @import("std");

pub fn build(b: *std.Build) !void {

    const target    = b.standardTargetOptions(.{});
    const optimize  = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name               = "glfw",
        .root_source_file   = .{ .path = "src/main.zig" },
        .target             = target,
        .optimize           = optimize,
    });

    const config = try BuildConfig.default(target);
    try addGLFW(b, lib, config);

    b.installArtifact(lib);

}

const BuildTargetOs = enum {
    linux, windows
};

const BuildConfig = union(BuildTargetOs) {

    linux: struct {
        wayland: struct {  
            build: bool = true,
        } = .{},
        x11: struct {
            build: bool = true,
        } = .{},
    },

    windows: void,

    pub fn default(target: std.zig.CrossTarget) !@This() {

        const os_tag = if (target.os_tag) | x | x else (try std.zig.system.NativeTargetInfo.detect(target)).target.os.tag;

        return switch (os_tag) {

            .linux      => .{ .linux = .{} },
            .windows    => .{ .windows = {} },
            else => return error.UnsupportedOS,

        };

    }

};

pub fn addGLFW(b: *std.Build, compile: *std.Build.Step.Compile, config: BuildConfig) !void {

    _ = compile;

    // required steps
    switch (config) {

        .linux => | linux_config | {
            if (linux_config.wayland.build) {
                const generate_wayland_code_step = generateWaylandCodeStep(b, "generate-wayland-code", "generate wayland protocol headers");
                b.getInstallStep().dependOn(generate_wayland_code_step);
            }
        },

        .windows => {},

    }



}

pub fn generateWaylandCodeStep(b: *std.Build, name: []const u8, description: []const u8) *std.build.Step {
    const step = b.step(name, description);
    step.makeFn = generateWaylandCode;
    return step;
}

pub fn generateWaylandCode(self: *std.Build.Step, _: *std.Progress.Node) !void {

    // TODO? more robust search
    const wayland_scanner_program = try self.owner.findProgram(&.{ "wayland-scanner" }, &.{ "" });

    const cache_dir = self.owner.cache_root.handle;
    cache_dir.makeDir(generated_wayland_code_subpath) catch | err | {
        if (err == error.PathAlreadyExists) {
            return;
        }
    };

    const protocol_xmls_path = glfw_path ++ "/deps/wayland";
    const iterable_dir = try std.fs.openIterableDirAbsolute(protocol_xmls_path, .{});
    var iterator = iterable_dir.iterate();

    while (try iterator.next()) | entry | {

        const xml_filename = entry.name;
        const protocol_name = xml_filename[0..std.mem.lastIndexOf(u8, xml_filename, ".").?];
        
        var input_buf: [4096]u8 = undefined;
        const input_file_path = try std.fmt.bufPrint(&input_buf, "{s}/{s}", .{ protocol_xmls_path, xml_filename });
        
        var output_buf: [4096]u8 = undefined;
        const client_header_path = try std.fmt.bufPrint(&output_buf, "{s}/{s}/{s}-client-protocol.h",
            .{ self.owner.cache_root.path.?, generated_wayland_code_subpath, protocol_name });

        _ = try std.ChildProcess.exec(.{
            .allocator = std.heap.page_allocator,
            .argv = &[_][]const u8{
                wayland_scanner_program,
                "client-header",
                input_file_path,
                client_header_path,
            },
        });

        const private_code_path = try std.fmt.bufPrint(&output_buf, "{s}/{s}/{s}-client-protocol-code.h",
            .{ self.owner.cache_root.path.?, generated_wayland_code_subpath, protocol_name });

        _ = try std.ChildProcess.exec(.{
            .allocator = std.heap.page_allocator,
            .argv = &[_][]const u8{
                wayland_scanner_program,
                "client-header",
                input_file_path,
                private_code_path,
            },
        });

    }

}

pub const project_path = projectPath();
pub fn projectPath() []const u8 {
    return if (std.fs.path.dirname(@src().file)) | parent | parent else "";
}

const glfw_path: []const u8 = project_path ++ "/glfw";

/// relative to cache dir
pub const generated_wayland_code_subpath = "generated_wayland_code";