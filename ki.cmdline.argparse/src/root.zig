const std = @import("std");

// TODO: parsing for ints, floats, enums
pub fn parseValue(comptime T: type, value_string: []const u8) !T {
    return switch (T) {
        []const u8 => return value_string,
        else => switch (@typeInfo(T)) {
            .void => if (std.mem.eql(u8, value_string, "{}")) {} else error.CouldNotParseValue,
            .bool => blk: {
                if (std.mem.eql(u8, value_string, "true")) break :blk true;
                if (std.mem.eql(u8, value_string, "false")) break :blk false;
                break :blk error.ParseError;
            },
            .optional => |optional_type_info| if (std.mem.eql(u8, value_string, "null")) null else try parseValue(optional_type_info.child, value_string),
            else => return error.UnsupportedType,
        },
    };
}

pub fn toStructTempAlloc(T: type, allocator: std.mem.Allocator, argv: []const []const u8) !T {
    if (@typeInfo(T) != .@"struct")
        return error.UnexpectedArgsType;

    var table: std.StringHashMap(?[]const u8) = .init(allocator);
    defer table.deinit();

    const args_struct_fields = @typeInfo(T).@"struct".fields;
    inline for (args_struct_fields) |struct_field| {
        try table.put(struct_field.name, null);
    }

    for (argv) |arg| {
        switch (arg[0]) {
            '.' => {
                const id_end = std.mem.find(u8, arg, "=") orelse arg.len;
                const id = arg[1..id_end];
                if (table.get(id)) |table_value| {
                    if (table_value) |_| return error.DuplicateArg;
                    const value_string = if (id_end == arg.len) "{}" else arg[id_end + 1 ..];
                    try table.put(id, value_string);
                } else return error.UnknownArgInArgv;
            },
            else => continue,
        }
    }

    var args_struct: T = undefined;
    inline for (args_struct_fields) |struct_field| {
        const provided_value_string = table.get(struct_field.name) orelse return error.TableStructMismatch;
        const provided_value = if (provided_value_string) |value_string| try parseValue(struct_field.type, value_string) else null;
        const value = if (provided_value) |value| value else struct_field.defaultValue();
        @field(args_struct, struct_field.name) = value orelse return error.NoValueProvided;
    }

    return args_struct;
}
