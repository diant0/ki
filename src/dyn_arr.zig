const std = @import("std");

pub fn DynArr(T: type, config: struct {
    auto_shrink_capacity: bool = true,
    min_capacity: usize = 4,
}) type {
    const PopReturnType = if (config.auto_shrink_capacity) anyerror!?T else ?T;

    return struct {
        allocator: std.mem.Allocator = undefined,
        buffer: []T = &[_]T{},

        buffer_offset: usize = 0,
        item_count: usize = 0,

        pub fn init(self: *@This(), allocator: std.mem.Allocator) !void {
            self.buffer = try allocator.alloc(T, config.min_capacity);
            self.allocator = allocator;
            self.clear();
        }

        pub fn free(self: *const @This()) void {
            self.allocator.free(self.buffer);
        }

        pub fn clear(self: *@This()) void {
            self.buffer_offset = 0;
            self.item_count = 0;
        }

        pub fn shrinkCapacityIfNeeded(self: *@This()) !void {
            var new_capacity = self.buffer.len;
            while (new_capacity < self.buffer.len / 4) {
                new_capacity /= 2;
                if (new_capacity < config.min_capacity) {
                    new_capacity = config.min_capacity;
                    break;
                }
            }
            if (new_capacity != self.buffer.len) {
                try self.resizeCapacity(new_capacity);
            }
        }

        pub inline fn items(self: *const @This()) []T {
            return self.buffer[self.buffer_offset..(self.buffer_offset + self.item_count)];
        }

        pub fn resizeCapacity(self: *@This(), new_capacity: usize) !void {
            self.packFront();
            self.buffer = self.allocator.realloc(self.buffer, new_capacity) catch blk: {
                const new_buffer = try self.allocator.alloc(T, new_capacity);
                std.mem.copyForwards(T, new_buffer, self.items());
                self.allocator.free(self.buffer);
                break :blk new_buffer;
            };
        }

        pub fn packBack(self: *@This()) void {
            std.mem.copyBackwards(T, self.buffer[self.buffer.len - self.item_count .. self.buffer.len], self.items());
            self.buffer_offset = self.buffer.len - self.item_count;
        }

        pub fn packFront(self: *@This()) void {
            std.mem.copyForwards(T, self.buffer[0..self.item_count], self.items());
            self.buffer_offset = 0;
        }

        pub fn pushBack(self: *@This(), value: T) !void {
            if (self.item_count + 1 == self.buffer.len) {
                try self.resizeCapacity(self.buffer.len * 2);
            }

            if (self.buffer_offset + self.item_count >= self.buffer.len) {
                self.packFront();
            }

            self.buffer[self.buffer_offset + self.item_count] = value;
            self.item_count += 1;
        }

        pub fn pushFront(self: *@This(), value: T) !void {
            if (self.item_count + 1 == self.buffer.len) {
                try self.resizeCapacity(self.buffer.len * 2);
            }

            if (self.buffer_offset == 0) {
                self.packBack();
            }

            self.buffer[self.buffer_offset - 1] = value;
            self.buffer_offset -= 1;
            self.item_count += 1;
        }

        pub fn popBack(self: *@This()) PopReturnType {
            if (self.item_count == 0) {
                return null;
            }

            const value = self.buffer[self.buffer_offset + self.item_count - 1];
            self.item_count -= 1;

            if (config.auto_shrink_capacity) {
                try self.shrinkCapacityIfNeeded();
            }

            return value;
        }

        pub fn popFront(self: *@This()) PopReturnType {
            if (self.item_count == 0) {
                return null;
            }

            const value = self.buffer[self.buffer_offset];
            self.buffer_offset += 1;
            self.item_count -= 1;

            if (config.auto_shrink_capacity) {
                try self.shrinkCapacityIfNeeded();
            }

            return value;
        }

        pub fn insertAt(self: *@This(), index: usize, value: T) !void {
            if (self.item_count == 0 and index == 0) {
                try self.pushBack(value);
                return;
            }

            if (index >= self.item_count) {
                return error.IndexOutOfRange;
            }

            if (self.item_count + 1 == self.buffer.len) {
                try self.resizeCapacity(self.buffer.len * 2);
            }

            if (self.buffer_offset + self.item_count + 1 > self.buffer.len) {
                self.packFront();
            }

            const shift_right = self.buffer_offset == 0 or index > self.item_count / 2;

            if (shift_right) {
                std.mem.copyBackwards(T, self.buffer[self.buffer_offset + index + 1 .. self.buffer_offset + self.item_count + 1], self.buffer[self.buffer_offset + index .. self.buffer_offset + self.item_count]);
                self.item_count += 1;
                self.buffer[self.buffer_offset + index] = value;
            } else {
                std.mem.copyForwards(T, self.buffer[self.buffer_offset - 1 .. self.buffer_offset + index - 1], self.buffer[self.buffer_offset .. self.buffer_offset + index]);
                self.item_count += 1;
                self.buffer_offset -= 1;
                self.buffer[self.buffer_offset + index] = value;
            }
        }

        pub fn pluckFrom(self: *@This(), index: usize) PopReturnType {
            if (index == 0) {
                return self.popFront();
            }

            if (self.item_count == 0) {
                return null;
            }

            if (index >= self.item_count) {
                return null;
            }

            const value = self.buffer[self.buffer_offset + index];

            const shift_left = self.buffer_offset == 0 or index > self.item_count / 2;

            if (shift_left) {
                std.mem.copyForwards(T, self.buffer[self.buffer_offset + index .. self.buffer_offset + self.item_count - 1], self.buffer[self.buffer_offset + index + 1 .. self.buffer_offset + self.item_count]);
                self.item_count -= 1;
            } else {
                std.mem.copyBackwards(T, self.buffer[self.buffer_offset + 1 .. self.buffer_offset + index], self.buffer[self.buffer_offset .. self.buffer_offset + index - 1]);
                self.buffer_offset += 1;
                self.item_count -= 1;
            }

            if (config.auto_shrink_capacity) {
                try self.shrinkCapacityIfNeeded();
            }

            return value;
        }
    };
}
