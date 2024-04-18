const std = @import("std");
const AudioIO = @import("AudioIO.zig").AudioIO;
const miniaudio = @import("miniaudio");
const AudioPlayer = @import("AudioPlayer.zig").AudioPlayer;
const DynArr = @import("../DynArr.zig").DynArr;

pub const AudioSourceType = enum {
    predecoded,
};

pub const AudioSource = union(AudioSourceType) {

    predecoded: AudioSourceDecodedFrames,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded => .{ .predecoded = try AudioSourceDecodedFrames.maDecodeFromPathRelToExeAlloc(allocator, path), },
        };
    }

    pub fn maFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded => .{ .predecoded = try AudioSourceDecodedFrames.maDecodeFromAbsPathAlloc(allocator, path), },
        };
    }

    pub fn maFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded => .{ .predecoded = try AudioSourceDecodedFrames.maDecodeFromFileAlloc(allocator, file), },
        };
    }

    pub fn maFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded => .{ .predecoded = try AudioSourceDecodedFrames.maDecodeFromMemAlloc(allocator, bytes), },
        };
    }

    pub fn free(self: @This(), allocator: std.mem.Allocator) void {
        switch (self) {
            .predecoded => | x | x.free(allocator),
        }
    }

    pub fn sampleCount(self: @This()) usize {
        return switch (self) {
            .predecoded => | x | x.samples.len,
        };
    }

};

pub const AudioSourceDecodedFrames = struct {

    samples: []const AudioIO.SampleT,

    pub fn maDecodeFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exe_dir_path);
        var exe_dir = try std.fs.openDirAbsolute(exe_dir_path, .{});
        defer exe_dir.close();

        const abs_path = try exe_dir.realpathAlloc(allocator, path);
        defer allocator.free(abs_path);

        return try maDecodeFromAbsPathAlloc(allocator, abs_path);

    }

    pub fn maDecodeFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        return try maDecodeFromFileAlloc(allocator, file);

    }

    pub fn maDecodeFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File) !@This() {

        const file_contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(file_contents);

        return try maDecodeFromMemAlloc(allocator, file_contents);
    
    }

    pub fn maDecodeFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8) !@This() {

        const decoder_config = miniaudio.ma_decoder_config_init(AudioIO.format, AudioIO.channels, AudioIO.sample_rate);

        var decoder = blk: {
            var x: miniaudio.ma_decoder = undefined;
            const decoder_init_result = miniaudio.ma_decoder_init_memory(bytes.ptr, @intCast(bytes.len), &decoder_config, &x);
            std.debug.assert(decoder_init_result == miniaudio.MA_SUCCESS);
            break :blk x;
        };

        const pcm_frame_count = blk: {
            var x: miniaudio.ma_uint64 = undefined;
            const decoder_get_length_result = miniaudio.ma_decoder_get_length_in_pcm_frames(&decoder, &x);
            std.debug.assert(decoder_get_length_result == miniaudio.MA_SUCCESS);
            break :blk x;
        };

        const decoded = try allocator.alloc(AudioIO.SampleT, pcm_frame_count * AudioIO.channels);

        const pcm_frames_read = blk: {
            var x: miniaudio.ma_uint64 = undefined;
            const decoder_read_pcm_frames_result = miniaudio.ma_decoder_read_pcm_frames(&decoder, decoded.ptr, pcm_frame_count, &x);
            std.debug.assert(decoder_read_pcm_frames_result == miniaudio.MA_SUCCESS);
            break :blk x;
        };
        
        std.debug.assert(pcm_frames_read == pcm_frame_count);

        _ = miniaudio.ma_decoder_uninit(&decoder);

        return .{
            .samples = decoded,
        };

    }

    pub fn free(self: *const @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.samples);
    }

};