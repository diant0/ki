const std = @import("std");

pub const Codepoint = u21;

pub fn decodeAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]const Codepoint {
    const codepoint_count = try std.unicode.utf8CountCodepoints(bytes);
    const codepoints = try allocator.alloc(Codepoint, codepoint_count);

    return try bufDecode(codepoints, bytes);
}

pub fn bufDecode(buffer: []Codepoint, bytes: []const u8) ![]const Codepoint {
    var byte_offset: usize = 0;
    var codepoint_count: usize = 0;

    while (byte_offset < bytes.len) {
        const byte_sequence_length = try std.unicode.utf8ByteSequenceLength(bytes[byte_offset]);
        const byte_sequence = bytes[byte_offset..(byte_offset + byte_sequence_length)];
        byte_offset += byte_sequence_length;

        const codepoint: Codepoint = @intCast(try std.unicode.utf8Decode(byte_sequence));
        buffer[codepoint_count] = codepoint;
        codepoint_count += 1;
    }

    return buffer[0..codepoint_count];
}
