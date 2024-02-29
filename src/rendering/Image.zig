const std = @import("std");
const log = @import("../log.zig");

pub fn Image(ComponentT: type) type {

    return struct {

        size: @Vector(2, u32) = @splat(0),
        components_per_pixel: u32 = 0,
        data: []const ComponentT,

        pub const STBIPixelComponents = enum(c_int) { Any = 0, R = 1, RA = 2, RGB = 3, RGBA = 4, };
        /// .data of returned struct needs to be freed, does not internally hold *Allocator
        /// some temporary allocations will be performed with passed allocator,
        /// as well as stbi's internal allocations
        pub fn stbiDecodeAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8, desired_components: STBIPixelComponents) !@This() {

            const file = try std.fs.openFileAbsolute(path, .{});
            defer file.close();

            return try stbiDecodeFileAlloc(allocator, file, desired_components);

        }

        /// .data of returned struct needs to be freed, does not internally hold *Allocator
        /// some temporary allocations will be performed with passed allocator,
        /// as well as stbi's internal allocations
        pub fn stbiDecodeFileAlloc(allocator: std.mem.Allocator, file: std.fs.File, desired_components: STBIPixelComponents) !@This() {

            const file_contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(file_contents);

            return try stbiDecodeMemAlloc(allocator, file_contents, desired_components);
        }
        
        /// .data of returned struct needs to be freed, does not internally hold *Allocator
        /// some stbi's internal temporary allocations will be performed with libc
        pub fn stbiDecodeMemAlloc(allocator: std.mem.Allocator, bytes: []const u8, desired_components: STBIPixelComponents) !@This() {

            const stbi = @import("stb").image;
            const load_func = switch(ComponentT) {
                u8  => stbi.stbi_load_from_memory,
                f32 => stbi.stbi_loadf_from_memory,
                else => return error.STBIUnsupportedComponentType,
            };

            var w: c_int = undefined;
            var h: c_int = undefined;
            var c: c_int = undefined;

            const decoded = load_func(bytes.ptr, @intCast(bytes.len),
                &w, &h, &c, @intFromEnum(desired_components)) orelse return error.STBILoadFromMemReturnedNull;
            defer stbi.stbi_image_free(decoded);

            return .{
                .size = [_]u32 { @intCast(w), @intCast(h) },
                .components_per_pixel = @intCast(c),
                .data = try allocator.dupe(ComponentT, decoded[0..@intCast(w*h*c)]),
            };

        }
        
        pub const STBIWFormat = enum { png, bmp, tga, hdr, jpg };
        pub fn stbiwEncodeAbsPath(self: *const @This(), path: []const u8, format: STBIWFormat) !void {

            const file = std.fs.createFileAbsolute(path, .{}) catch | e | blk: {
                if (e == error.PathAlreadyExists) {
                    break :blk try std.fs.openFileAbsolute(path, .{ .mode = .write_only });
                } else return e;
            };
            defer file.close();
            errdefer std.fs.deleteFileAbsolute(path) catch {};

            try self.stbiwEncodeFile(file, format);

        }

        pub fn stbiwEncodeFile(self: *const @This(), file: std.fs.File, format: STBIWFormat) !void {

            const writeToFileCallback = struct {
                fn f(context: ?*anyopaque, data_ptr_opt: ?*anyopaque, data_len: c_int) callconv(.C) void {
                    const out_file: *std.fs.File = @alignCast(@ptrCast(
                        context orelse {
                            log.print(.Error, "stb_image_write: recieved null context in encoding callback\n", .{});
                            return;
                        }
                    ));
                    if (data_ptr_opt) | data_ptr | {
                        const data = @as([*]const u8, @ptrCast(data_ptr))[0..@intCast(data_len)];
                        out_file.writeAll(data) catch {
                            log.print(.Error, "stb_image_write: could not write encoded bytes to file\n", .{});
                        };
                    } else {
                        log.print(.Error, "stb_image_write: recieved null data in encoding callback\n", .{});
                        return;
                    }
                }
            }.f;

            try self.stbiwInvokeEncodeCallback(writeToFileCallback, @constCast(&file), format);

        }

        pub fn stbiwEncodeMemAlloc(self: *const @This(), allocator: std.mem.Allocator, format: STBIWFormat) ![]const u8 {

            const allocCallback = struct {
                fn f(context: ?*anyopaque, data_ptr_opt: ?*anyopaque, data_len: c_int) callconv(.C) void {
                    const list: *std.ArrayList(u8) = @alignCast(@ptrCast(
                        context orelse {
                            log.print(.Error, "stb_image_write: recieved null context in encoding callback\n", .{});
                            return;
                        }
                    ));
                    if (data_ptr_opt) | data_ptr | {
                        const data = @as([*]const u8, @ptrCast(data_ptr))[0..@intCast(data_len)];
                        list.ensureTotalCapacity(data.len) catch {
                            log.print(.Error, "stb_image_write: could not reserve needed capacity for encoded memory\n", .{});
                        };
                        list.appendSlice(data) catch {
                            log.print(.Error, "stb_image_write: could not append encoded bytes to accumulator\n", .{});
                        };
                    } else {
                        log.print(.Error, "stb_image_write: recieved null data in encoding callback\n", .{});
                        return;
                    }
                }
            }.f;

            var accumulator = std.ArrayList(u8).init(allocator);
            try self.stbiwInvokeEncodeCallback(allocCallback, &accumulator, format);
            return accumulator.toOwnedSlice();

        }

        pub fn stbiwInvokeEncodeCallback(self: *const @This(),
            callback: *const fn(context: ?*anyopaque, data_ptr_opt: ?*anyopaque, data_len: c_int) callconv(.C) void,
            context: ?*anyopaque, format: STBIWFormat) !void {

            const stbiw = @import("stb").image_write;
            const stbiw_retcode = switch (ComponentT) {

                u8 => switch (format) {

                    .png => stbiw.stbi_write_png_to_func(callback, context, 
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr, @intCast(self.size[0] * self.components_per_pixel * @sizeOf(ComponentT))),

                    .bmp => stbiw.stbi_write_bmp_to_func(callback, context,
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr),

                    .tga => stbiw.stbi_write_tga_to_func(callback, context,
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr),
                    
                    .jpg => stbiw.stbi_write_jpg_to_func(callback, context,
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr, 100),

                    else => return error.STBIWIncorrectFormatForComponentTypeU8,

                },

                f32 => switch (format) {

                    .hdr => stbiw.stbi_write_hdr_to_func(callback, context,
                        @intCast(self.size[0]), @intCast(self.size[1]), @intCast(self.components_per_pixel),
                        self.data.ptr),
                        
                    else => return error.STBIWIncorrectFormatForComponentTypeF32,

                },

                else => return error.STBIWUnsupportedComponentType,

            };

            if (stbiw_retcode == 0) {
                return error.STBIWReturnedCFalse;
            }


        }

        pub const QOIPixelComponents = enum(c_int) { Any = 0, RGB = 3, RGBA = 4, };
        pub fn qoiDecodeAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8, desired_components: QOIPixelComponents) !@This() {
            
            const file = try std.fs.openFileAbsolute(path, .{});
            defer file.close();

            return try qoiDecodeFileAlloc(allocator, file, desired_components);
        
        }

        pub fn qoiDecodeFileAlloc(allocator: std.mem.Allocator, file: std.fs.File, desired_components: QOIPixelComponents) !@This() {

            const file_contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(file_contents);

            return try qoiDecodeMemAlloc(allocator, file_contents, desired_components);

        }

        pub fn qoiDecodeMemAlloc(allocator: std.mem.Allocator, bytes: []const u8, desired_components: QOIPixelComponents) !@This() {

            const qoi = @import("qoi");

            var desc: qoi.qoi_desc = undefined;
            const decoded = qoi.qoi_decode(bytes.ptr, @intCast(bytes.len), &desc, @intFromEnum(desired_components))
                orelse return error.QOIDecodeReturnedNull;
            // NOTE: requires QOI_FREE() to be libc free()
            defer std.c.free(decoded);

            const data = @as([*]u8, @ptrCast(decoded))[0..@intCast(desc.width * desc.height * desc.channels)];

            return .{
                .size = [_]u32 { desc.width, desc.height },
                .components_per_pixel = @intCast(desc.channels),
                .data = try allocator.dupe(u8, data),
            };
            
        }

        pub fn qoiEncodeAbsPath(self: *const @This(), path: []const u8) !void {

            const file = try std.fs.openFileAbsolute(path, .{});
            defer file.close();

            return try self.qoiEncodeFile(file);    

        }

        pub fn qoiEncodeFile(self: *const @This(), file: std.fs.File) !void {

            const qoi = @import("qoi");

            const desc: qoi.qoi_desc = .{
                .width = self.size[0],
                .height = self.size[1],
                .channels = @intCast(self.components_per_pixel),
                .colorspace = qoi.QOI_SRGB,
            };

            var encoded_len: c_int = undefined;
            const encoded = qoi.qoi_encode(self.data.ptr, &desc, &encoded_len)
                orelse return error.QOIEncodeReturnedNull;
            // NOTE: requires QOI_FREE() to be libc free()
            defer std.c.free(encoded);

            try file.writeAll(@as([*]const u8, @ptrCast(encoded))[0..@intCast(encoded_len)]);

        }

        pub fn qoiEncodeMemAlloc(self: *const @This(), allocator: std.mem.Allocator) ![]const u8 {

            const qoi = @import("qoi");

            const desc: qoi.qoi_desc = .{
                .width = self.size[0],
                .height = self.size[1],
                .channels = @intCast(self.components_per_pixel),
                .colorspace = qoi.QOI_SRGB,
            };

            var encoded_len: c_int = undefined;
            const encoded = qoi.qoi_encode(self.data.ptr, &desc, &encoded_len)
                orelse return error.QOIEncodeReturnedNull;
            // NOTE: requires QOI_FREE() to be libc free()
            defer std.c.free(encoded);

            return try allocator.dupe(u8. encoded);

        }

        pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
            self.size = @splat(0);
            self.components_per_pixel = 0;
            allocator.free(self.data);
        }

    };

}