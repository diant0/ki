const std = @import("std");

// TODO: bufDecode versions
// TODO: maybe vertically flip not on load, but when passing to gpu?

pub fn Image(ComponentT: type) type {
    return struct {
        size: @Vector(2, u32) = @splat(0),
        components_per_pixel: u32 = 0,
        data: []ComponentT,

        pub fn alloc(allocator: std.mem.Allocator, size: @Vector(2, u32), comptime components_per_pixel: u32, color: @Vector(components_per_pixel, ComponentT)) !@This() {
            const data = try allocator.alloc(ComponentT, size[0] * size[1] * components_per_pixel);

            for (0..(size[0] * size[1])) |pixel_index| {
                const component_pixel_offset = pixel_index * components_per_pixel;
                for (0..components_per_pixel) |component_index| {
                    data[component_pixel_offset + component_index] = color[component_index];
                }
            }

            return .{
                .size = size,
                .components_per_pixel = components_per_pixel,
                .data = data,
            };
        }

        pub const STBIPixelComponents = enum(c_int) {
            Any = 0,
            R = 1,
            RA = 2,
            RGB = 3,
            RGBA = 4,
        };
        /// .data of returned struct needs to be freed, does not internally hold *Allocator.
        /// some temporary allocations will be performed with passed allocator,
        /// as well as stbi's internal allocations
        pub fn stbiDecodeFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8, desrired_components: STBIPixelComponents) !@This() {
            const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
            defer allocator.free(exe_dir_path);
            var exe_dir = try std.fs.openDirAbsolute(exe_dir_path, .{});
            defer exe_dir.close();

            const abs_path = try exe_dir.realpathAlloc(allocator, path);
            defer allocator.free(abs_path);

            return try stbiDecodeFromAbsPathAlloc(allocator, abs_path, desrired_components);
        }

        /// .data of returned struct needs to be freed, does not internally hold *Allocator.
        /// some temporary allocations will be performed with passed allocator,
        /// as well as stbi's internal allocations
        pub fn stbiDecodeFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8, desired_components: STBIPixelComponents) !@This() {
            const file = try std.fs.openFileAbsolute(path, .{});
            defer file.close();

            return try stbiDecodeFromFileAlloc(allocator, file, desired_components);
        }

        /// .data of returned struct needs to be freed, does not internally hold *Allocator.
        /// some temporary allocations will be performed with passed allocator,
        /// as well as stbi's internal allocations
        pub fn stbiDecodeFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File, desired_components: STBIPixelComponents) !@This() {
            const file_contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(file_contents);

            return try stbiDecodeFromMemAlloc(allocator, file_contents, desired_components);
        }

        /// .data of returned struct needs to be freed, does not internally hold *Allocator
        /// some stbi's internal temporary allocations will be performed with libc
        pub fn stbiDecodeFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8, desired_components: STBIPixelComponents) !@This() {
            const stbi = @import("stb").image;
            const load_func = switch (ComponentT) {
                u8 => stbi.stbi_load_from_memory,
                f32 => stbi.stbi_loadf_from_memory,
                else => return error.STBIUnsupportedComponentType,
            };

            var w: c_int = undefined;
            var h: c_int = undefined;
            var c: c_int = undefined;

            const decoded_cptr = load_func(bytes.ptr, @intCast(bytes.len), &w, &h, &c, @intFromEnum(desired_components)) orelse return error.STBILoadFromMemReturnedNull;
            defer stbi.stbi_image_free(decoded_cptr);

            const decoded = decoded_cptr[0..@intCast(w * h * c)];
            const decoded_flipped = try flipVerticallyAlloc(allocator, ComponentT, decoded, .{ @intCast(w), @intCast(h) }, @intCast(c));

            return .{
                .size = [_]u32{ @intCast(w), @intCast(h) },
                .components_per_pixel = @intCast(c),
                .data = decoded_flipped,
            };
        }

        pub const STBIWFormat = enum { png, bmp, tga, hdr, jpg };
        /// stbiw will perform temporary allocations
        /// some temporary allocations will be performed with passed allocator, no need to free anything
        pub fn stbiwEncodeToPathRelToExeTempAlloc(self: *const @This(), allocator: std.mem.Allocator, path: []const u8, format: STBIWFormat) !void {
            var exe_dir_path_buffer: [std.fs.max_path_bytes]u8 = undefined;
            const exe_dir_path = try std.fs.selfExeDirPath(&exe_dir_path_buffer);

            var abs_path_buffer: [std.fs.max_path_bytes]u8 = undefined;
            const abs_path = try std.fmt.bufPrint(&abs_path_buffer, "{s}/{s}", .{ exe_dir_path, path });

            try self.stbiwEncodeToAbsPathTempAlloc(allocator, abs_path, format);
        }

        /// stbiw will perform temporary allocations
        pub fn stbiwEncodeToAbsPathTempAlloc(self: *const @This(), allocator: std.mem.Allocator, path: []const u8, format: STBIWFormat) !void {
            const file = std.fs.createFileAbsolute(path, .{}) catch |e| blk: {
                if (e == error.PathAlreadyExists) {
                    break :blk try std.fs.openFileAbsolute(path, .{ .mode = .write_only });
                } else return e;
            };
            defer file.close();
            errdefer std.fs.deleteFileAbsolute(path) catch {};

            try self.stbiwEncodeToFileTempAlloc(allocator, file, format);
        }

        /// stbiw will perform temporary allocations
        pub fn stbiwEncodeToFileTempAlloc(self: *const @This(), allocator: std.mem.Allocator, file: std.fs.File, format: STBIWFormat) !void {
            const encoded = try self.stbiwEncodeToMemAlloc(allocator, format);
            defer allocator.free(encoded);

            try file.writeAll(encoded);
        }

        /// returned slice needs to be freed.
        /// stbiw will perform temporary allocations
        pub fn stbiwEncodeToMemAlloc(self: *const @This(), allocator: std.mem.Allocator, format: STBIWFormat) ![]const u8 {
            const flipped = try flipVerticallyAlloc(allocator, ComponentT, self.data, self.size, self.components_per_pixel);
            defer allocator.free(flipped);

            const allocCallback = struct {
                fn f(context: ?*anyopaque, data_ptr_opt: ?*anyopaque, data_len: c_int) callconv(.C) void {
                    const list: *std.ArrayList(u8) = @alignCast(@ptrCast(context orelse return));
                    if (data_ptr_opt) |data_ptr| {
                        const data = @as([*]const u8, @ptrCast(data_ptr))[0..@intCast(data_len)];
                        list.ensureTotalCapacity(data.len) catch {};
                        list.appendSlice(data) catch {};
                    }
                }
            }.f;

            var accumulator = std.ArrayList(u8).init(allocator);
            defer accumulator.deinit();
            try stbiwInvokeEncodeCallback(allocCallback, flipped, self.size, self.components_per_pixel, &accumulator, format);
            if (accumulator.items.len == 0) return error.NoDataInEncodeAccumulator;

            return try accumulator.toOwnedSlice();
        }

        fn stbiwInvokeEncodeCallback(callback: *const fn (context: ?*anyopaque, data_ptr_opt: ?*anyopaque, data_len: c_int) callconv(.C) void, data: []const ComponentT, size: @Vector(2, u32), components_per_pixel: usize, context: ?*anyopaque, format: STBIWFormat) !void {
            const stbiw = @import("stb").image_write;
            const stbiw_retcode = switch (ComponentT) {
                u8 => switch (format) {
                    .png => stbiw.stbi_write_png_to_func(callback, context, @intCast(size[0]), @intCast(size[1]), @intCast(components_per_pixel), data.ptr, @intCast(size[0] * components_per_pixel * @sizeOf(ComponentT))),
                    .bmp => stbiw.stbi_write_bmp_to_func(callback, context, @intCast(size[0]), @intCast(size[1]), @intCast(components_per_pixel), data.ptr),
                    .tga => stbiw.stbi_write_tga_to_func(callback, context, @intCast(size[0]), @intCast(size[1]), @intCast(components_per_pixel), data.ptr),
                    .jpg => stbiw.stbi_write_jpg_to_func(callback, context, @intCast(size[0]), @intCast(size[1]), @intCast(components_per_pixel), data.ptr, 100),
                    else => return error.STBIWIncorrectFormatForComponentTypeU8,
                },
                f32 => switch (format) {
                    .hdr => stbiw.stbi_write_hdr_to_func(callback, context, @intCast(size[0]), @intCast(size[1]), @intCast(components_per_pixel), data.ptr),
                    else => return error.STBIWIncorrectFormatForComponentTypeF32,
                },
                else => return error.STBIWUnsupportedComponentType,
            };

            if (stbiw_retcode == 0) {
                return error.STBIWReturnedCFalse;
            }
        }

        pub const QOIPixelComponents = enum(c_int) {
            Any = 0,
            RGB = 3,
            RGBA = 4,
        };
        /// .data of returned struct needs to be freed, does not internally hold *Allocator.
        /// qoi will perform temporary allocations
        pub fn qoiDecodeFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8, desrired_components: QOIPixelComponents) !@This() {
            const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
            defer allocator.free(exe_dir_path);
            var exe_dir = try std.fs.openDirAbsolute(exe_dir_path, .{});
            defer exe_dir.close();

            const abs_path = try exe_dir.realpathAlloc(allocator, path);
            defer allocator.free(abs_path);

            return try qoiDecodeFromAbsPathAlloc(allocator, abs_path, desrired_components);
        }

        /// .data of returned struct needs to be freed, does not internally hold *Allocator.
        /// qoi will perform temporary allocations
        pub fn qoiDecodeFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8, desired_components: QOIPixelComponents) !@This() {
            const file = try std.fs.openFileAbsolute(path, .{});
            defer file.close();

            return try qoiDecodeFromFileAlloc(allocator, file, desired_components);
        }

        /// .data of returned struct needs to be freed, does not internally hold *Allocator.
        /// qoi will perform temporary allocations
        pub fn qoiDecodeFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File, desired_components: QOIPixelComponents) !@This() {
            const file_contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(file_contents);

            return try qoiDecodeFromMemAlloc(allocator, file_contents, desired_components);
        }

        /// .data of returned struct needs to be freed, does not internally hold *Allocator.
        /// qoi will perform temporary allocations
        pub fn qoiDecodeFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8, desired_components: QOIPixelComponents) !@This() {
            const qoi = @import("qoi");

            var desc: qoi.qoi_desc = undefined;
            const decoded_cptr = qoi.qoi_decode(bytes.ptr, @intCast(bytes.len), &desc, @intFromEnum(desired_components)) orelse return error.QOIDecodeReturnedNull;
            // NOTE: requires QOI_FREE() to be libc free()
            defer std.c.free(decoded_cptr);

            const decoded = @as([*]u8, @ptrCast(decoded_cptr))[0..@intCast(desc.width * desc.height * desc.channels)];
            const decoded_flipped = try flipVerticallyAlloc(allocator, ComponentT, decoded, .{ @intCast(desc.width), @intCast(desc.height) }, @intCast(desc.channels));

            return .{
                .size = [_]u32{ desc.width, desc.height },
                .components_per_pixel = @intCast(desc.channels),
                .data = decoded_flipped,
            };
        }

        /// qoi will perform temporary allocations
        /// some temporary allocations will be performed with passed allocator, no need to free anything
        pub fn qoiEncodeToPathRelToExeTempAlloc(self: *const @This(), allocator: std.mem.Allocator, path: []const u8) !void {
            const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
            defer allocator.free(exe_dir_path);

            var abs_path_buffer: [std.fs.max_path_bytes]u8 = undefined;
            const abs_path = try std.fmt.bufPrint(&abs_path_buffer, "{s}/{s}", .{ exe_dir_path, path });
            const abs_path_heap = try allocator.dupe(u8, abs_path);
            defer allocator.free(abs_path_heap);

            try self.qoiEncodeToAbsPathTempAlloc(allocator, abs_path);
        }

        /// qoi will perform temporary allocations
        pub fn qoiEncodeToAbsPathTempAlloc(self: *const @This(), allocator: std.mem.Allocator, path: []const u8) !void {
            const file = std.fs.createFileAbsolute(path, .{}) catch |e| blk: {
                if (e == error.PathAlreadyExists) {
                    break :blk try std.fs.openFileAbsolute(path, .{ .mode = .write_only });
                } else return e;
            };
            defer file.close();
            errdefer std.fs.deleteFileAbsolute(path) catch {};

            try self.qoiEncodeToFileTempAlloc(allocator, file);
        }

        /// qoi will perform temporary allocations
        pub fn qoiEncodeToFileTempAlloc(self: *const @This(), allocator: std.mem.Allocator, file: std.fs.File) !void {
            const encoded = try self.qoiEncodeToMemAlloc(allocator);
            defer allocator.free(encoded);

            try file.writeAll(encoded);
        }

        /// returned slice needs to be freed.
        /// qoi will perform temporary allocations
        pub fn qoiEncodeToMemAlloc(self: *const @This(), allocator: std.mem.Allocator) ![]const u8 {
            const qoi = @import("qoi");

            const desc: qoi.qoi_desc = .{
                .width = self.size[0],
                .height = self.size[1],
                .channels = @intCast(self.components_per_pixel),
                .colorspace = qoi.QOI_SRGB,
            };

            const flipped = try flipVerticallyAlloc(allocator, ComponentT, self.data, .{ self.size[0], self.size[1] }, self.components_per_pixel);
            defer allocator.free(flipped);

            var encoded_len: c_int = undefined;
            const encoded_cptr = qoi.qoi_encode(flipped.ptr, &desc, &encoded_len) orelse return error.QOIEncodeReturnedNull;
            // NOTE: requires QOI_FREE() to be libc free()
            defer std.c.free(encoded_cptr);

            const encoded = @as([*]u8, @ptrCast(encoded_cptr))[0..@intCast(encoded_len)];

            return try allocator.dupe(u8, encoded);
        }

        pub fn free(self: *const @This(), allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }
    };
}

fn flipVertically(ComponentT: type, in: []const ComponentT, size: @Vector(2, usize), components_per_pixel: usize, out: []ComponentT) []ComponentT {
    const stride = size[0] * components_per_pixel;
    for (0..size[1]) |y| {
        const flipped_y = size[1] - y - 1;
        @memcpy(
            out[flipped_y * stride .. (flipped_y + 1) * stride],
            in[y * stride .. (y + 1) * stride],
        );
    }
    return out[0 .. size[1] * stride];
}

fn flipVerticallyAlloc(allocator: std.mem.Allocator, ComponentT: type, in: []const ComponentT, size: @Vector(2, usize), components_per_pixel: usize) ![]ComponentT {
    const bufffer = try allocator.alloc(ComponentT, in.len);
    return flipVertically(ComponentT, in, size, components_per_pixel, bufffer);
}
