const std = @import("std");
const log = @import("../log.zig");

pub fn Image(ComponentT: type) type {

    return struct {

        pub var allocator = std.heap.page_allocator;

        size: @Vector(2, u32) = @splat(0),
        components_per_pixel: u32 = 0,
        data: []const ComponentT,

        pub fn loadSTBI(path: []const u8, desired_components: ?u32) !@This() {

            const file = try std.fs.openFileAbsolute(path, .{});
            defer file.close();

            const file_contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(file_contents);

            var w: c_int = undefined;
            var h: c_int = undefined;
            var c: c_int = undefined;

            const stbi = @import("stb").image;
            const load_func = switch(ComponentT) {
                u8  => stbi.stbi_load_from_memory,
                f32 => stbi.stbi_loadf_from_memory,
                else => return error.STBIUnsupportedComponentType,
            };

            const data = load_func(file_contents.ptr, @intCast(file_contents.len),
                &w, &h, &c, @intCast(desired_components orelse 0)) orelse return error.STBILoadFromMemReturnedNull;
            defer stbi.stbi_image_free(data);

            return .{
                .size = [_]u32 { @intCast(w), @intCast(h) },
                .components_per_pixel = @intCast(c),
                .data = try allocator.dupe(ComponentT, data[0..@intCast(w*h*c)]),
            };

        }
        
        const STBIWFormat = enum { png, bmp, tga, hdr, jpg };
        pub fn saveSTBIW(self: *const @This(), path: []const u8, format: STBIWFormat) !void {

            const writeCallback = struct {
                fn f(context_ptr: ?*anyopaque, data_ptr: ?*anyopaque, data_size: c_int) callconv(.C) void {
                    const writer: *std.fs.File.Writer = @alignCast(@ptrCast(context_ptr orelse {
                        log.print(.Error, "recieved null context while writing image\n", .{});
                        return;
                    }));
                    const data = (@as([*]u8, @ptrCast(data_ptr orelse {
                        log.print(.Error, "recieved null data while writing image\n", .{});
                        return;
                    })))[0..@intCast(data_size)];
                    writer.writeAll(data) catch | e | {
                        log.print(.Error, "failed writing image with error {s}\n",
                            .{ @errorName(e) });
                    };
                }
            }.f;

            const file = std.fs.openFileAbsolute(path, .{ .mode = .write_only }) catch | e | blk: {

                if (e == error.FileNotFound) {
                    break :blk try std.fs.createFileAbsolute(path, .{});
                }
                
                return e;

            };
            errdefer std.fs.deleteFileAbsolute(path) catch {};
            defer file.close();
            var writer = file.writer();

            const stbiw = @import("stb").image_write;

            const stbiw_retcode = switch (ComponentT) {

                u8 => switch (format) {

                    .png => stbiw.stbi_write_png_to_func(writeCallback, &writer, 
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr, @intCast(self.size[0] * self.components_per_pixel * @sizeOf(ComponentT))),

                    .bmp => stbiw.stbi_write_bmp_to_func(writeCallback, &writer,
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr),

                    .tga => stbiw.stbi_write_tga_to_func(writeCallback, &writer,
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr),
                    
                    .jpg => stbiw.stbi_write_jpg_to_func(writeCallback, &writer,
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr, 100),

                    else => return error.STBIWIncorrectFormatForComponentTypeU8,

                },

                f32 => switch (format) {

                    .hdr => stbiw.stbi_write_hdr_to_func(writeCallback, &writer,
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr),
                        
                    else => return error.STBIWIncorrectFormatForComponentTypeF32,

                },

                else => return error.STBIWUnsupportedComponentType,

            };

            if (stbiw_retcode == 0) {
                return error.STBIWReturned0;
            }

        }

        pub fn free(self: *@This()) void {
            self.size = @splat(0);
            self.components_per_pixel = 0;
            allocator.free(self.data);
        }

    };

}