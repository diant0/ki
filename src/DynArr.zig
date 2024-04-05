const std = @import("std");

pub fn DynArr(T: type, config: struct {
    auto_shrink_capacity: bool = true,
    min_capacity: usize = 4,
}) type {

    const PopReturnType = if (config.auto_shrink_capacity) anyerror!?T else ?T;

    return struct {
        
        allocator: std.mem.Allocator = undefined,
        buffer: []T = &[_]T{},

        first: usize = 0,
        len: usize = 0,

        pub fn init(self: *@This(), allocator: std.mem.Allocator) !void {

            self.buffer = try allocator.alloc(T, config.min_capacity);
            self.allocator = allocator;
            self.clear();

        }

        pub fn free(self: *const @This()) void {
            self.allocator.free(self.buffer);
        }

        pub fn clear(self: *@This()) void {
            self.first = 0;
            self.len = 0;
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
            return self.buffer[self.first..(self.first+self.len)];
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
            std.mem.copyBackwards(T, self.buffer[self.buffer.len-self.len..self.buffer.len], self.items());
            self.first = self.buffer.len-self.len;
        }

        pub fn packFront(self: *@This()) void {
            std.mem.copyForwards(T, self.buffer[0..self.len], self.items());
            self.first = 0;
        }

        pub fn pushBack(self: *@This(), value: T) !void {

            if (self.len + 1 == self.buffer.len) {
                try self.resizeCapacity(self.buffer.len * 2);
            }

            if (self.first + self.len >= self.buffer.len) {
                self.packFront();
            }

            self.buffer[self.first + self.len] = value;
            self.len += 1;

        }

        pub fn pushFront(self: *@This(), value: T) !void {

            if (self.len + 1 == self.buffer.len) {
                try self.resizeCapacity(self.buffer.len * 2);
            }

            if (self.first == 0) {
                self.packBack();
            }

            self.buffer[self.first-1] = value;
            self.first -= 1;
            self.len += 1;

        }

        pub fn popBack(self: *@This()) PopReturnType {
            
            if (self.len == 0) {
                return null;
            }

            const value = self.buffer[self.first+self.len-1];
            self.len -= 1;

            if (config.auto_shrink_capacity) {
                try self.shrinkCapacityIfNeeded();
            }

            return value;

        }

        pub fn popFront(self: *@This()) PopReturnType {

            if (self.len == 0) {
                return null;
            }

            const value = self.buffer[self.first];
            self.first += 1;
            self.len -= 1;


            if (config.auto_shrink_capacity) {
                try self.shrinkCapacityIfNeeded();
            }

            return value;

        }

        pub fn insertAt(self: *@This(), index: usize, value: T) !void {

            if (self.len == 0 and index == 0) {
                try self.pushBack(value);
                return;
            }

            if (index >= self.len) {
                return error.IndexOutOfRange;
            }

            if (self.len + 1 == self.buffer.len) {
                try self.resizeCapacity(self.buffer.len * 2);
            }

            if (self.first+self.len+1 > self.buffer.len) {
                self.packFront();
            }

            const shift_right = self.first == 0 or index > self.len / 2;

            if (shift_right) {
                std.mem.copyBackwards(T,
                    self.buffer[self.first+index+1..self.first+self.len+1],
                    self.buffer[self.first+index..self.first+self.len]);
                self.len += 1;
                self.buffer[self.first+index] = value;
            } else {
                std.mem.copyForwards(T,
                    self.buffer[self.first-1..self.first+index-1],
                    self.buffer[self.first..self.first+index]);
                self.len += 1;
                self.first -= 1;
                self.buffer[self.first+index] = value;
            }

        }

        pub fn pluckFrom(self: *@This(), index: usize) PopReturnType {

            if (index == 0) {
                return self.popFront();
            }

            if (self.len == 0) {
                return null;
            }

            if (index >= self.len) {
                return null;
            }

            const value = self.buffer[self.first+index];

            const shift_left = self.first == 0 or index > self.len / 2;

            if (shift_left) {
                std.mem.copyForwards(T,
                    self.buffer[self.first+index..self.first+self.len-1],
                    self.buffer[self.first+index+1..self.first+self.len]);
                self.len -= 1;
            } else {
                std.mem.copyBackwards(T,
                    self.buffer[self.first+1..self.first+index],
                    self.buffer[self.first..self.first+index-1]
                );
                self.first += 1;
                self.len -= 1;
            }

            if (config.auto_shrink_capacity) {
                try self.shrinkCapacityIfNeeded();
            }

            return value;

        }

    };

}