const std = @import("std");
const AudioIO = @import("AudioIO.zig").AudioIO;
const miniaudio = @import("miniaudio");
const AudioPlayer = @import("AudioPlayer.zig").AudioPlayer;
const DynArr = @import("../DynArr.zig").DynArr;

pub const AudioSourceType = enum {
    predecoded, streamed
};

pub const AudioSource = union(AudioSourceType) {

    predecoded: AudioSourceDecodedFrames,
    streamed: AudioSourceStreamed,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded => .{ .predecoded = try AudioSourceDecodedFrames.maDecodeFromPathRelToExeAlloc(allocator, path), },
            .streamed => .{ .streamed = try AudioSourceStreamed.maFromPathRelToExeAlloc(allocator, path), }
        };
    }

    pub fn maFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded => .{ .predecoded = try AudioSourceDecodedFrames.maDecodeFromAbsPathAlloc(allocator, path), },
            .streamed => .{ .streamed = try AudioSourceStreamed.maFromAbsPath(path), }
        };
    }

    pub fn maFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded => .{ .predecoded = try AudioSourceDecodedFrames.maDecodeFromFileAlloc(allocator, file), },
            .streamed => return error.NoStreamedAudioWithZigFileIO,
        };
    }

    pub fn maFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded => .{ .predecoded = try AudioSourceDecodedFrames.maDecodeFromMemAlloc(allocator, bytes), },
            .streamed => return error.NoStreamedAudioFromMemory,
        };
    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .predecoded => self.predecoded.free(allocator),
            .streamed   => self.streamed.free(),
        }
    }

    // pub fn sampleCount(self: *const @This()) usize {
    //     return switch (self.*) {
    //         .predecoded => | predecoded | predecoded.sampleCount(),
    //         .streamed => | streamed | streamed.sampleCount(),
    //         // blk: {
    //         //     switch (streamed) {
    //         //         .miniaudio => | streamed_miniaudio | {
    //         //             var pcm_frame_count: miniaudio.ma_uint64 = undefined;
    //         //             _ = miniaudio.ma_decoder_get_length_in_pcm_frames(&streamed_miniaudio.decoder, &pcm_frame_count);
    //         //             break :blk pcm_frame_count * AudioIO.channels;
    //         //         }
    //         //     }
    //         // }
    //     };
    // }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        return switch (self.*) {
            .predecoded => | predecoded | predecoded.sumToBuffer(offset, buffer, channel_multipliers),
            .streamed   => self.streamed.sumToBuffer(offset, buffer, channel_multipliers),
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

    pub fn sumToBuffer(self: *const @This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {

        const samples_left = @min(buffer.len, self.samples.len - offset);
        for (0..samples_left) | i | {
            buffer[i] += self.samples[offset+i] * channel_multipliers[i%channel_multipliers.len];
        }

        return samples_left;

    }

};

pub const AudioSourceStreamed = union(enum) {

    miniaudio: AudioSourceStreamedMiniaudio,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {
        return .{
            .miniaudio = try AudioSourceStreamedMiniaudio.fromPathRelToExeAlloc(allocator, path),
        };
    }

    pub fn maFromAbsPath(path: []const u8) !@This() {
        return .{
            .miniaudio = try AudioSourceStreamedMiniaudio.fromAbsPath(path),
        };
    }

    pub fn free(self: *@This()) void {
        switch (self.*) {
            .miniaudio => self.miniaudio.free(),
        }
    }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        return switch (self.*) {
            .miniaudio => self.miniaudio.sumToBuffer(offset, buffer, channel_multipliers),
        };
    }

};

pub const AudioSourceStreamedMiniaudio = struct {

    decoder: miniaudio.ma_decoder,
    sample_count: miniaudio.ma_uint64,

    pub fn fromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exe_dir_path);
        var exe_dir = try std.fs.openDirAbsolute(exe_dir_path, .{});
        defer exe_dir.close();

        const abs_path = try exe_dir.realpathAlloc(allocator, path);
        defer allocator.free(abs_path);

        return try fromAbsPath(allocator, abs_path);

    }

    pub fn fromAbsPath(path: []const u8) !@This() {

        if (!std.fs.path.isAbsolute(path)) {
            return error.PathNotAbsolute;
        }

        var decoder = blk: {
            const decoder_config = miniaudio.ma_decoder_config_init(AudioIO.format, AudioIO.channels, AudioIO.sample_rate);
            var x: miniaudio.ma_decoder = undefined;
            const result = miniaudio.ma_decoder_init_file(path.ptr, &decoder_config, &x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioDecoderInitFailed;
            }
            break :blk x;
        };

        const sample_count = blk: {
            var x: miniaudio.ma_uint64 = undefined;
            _ = miniaudio.ma_decoder_get_length_in_pcm_frames(&decoder, &x);
            break :blk x * AudioIO.channels;
        };

        return .{
            .decoder = decoder,
            .sample_count = sample_count,
        };

    }

    pub fn free(self: *@This()) void {
        _ = miniaudio.ma_decoder_uninit(&self.decoder);
    }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {

        _ = miniaudio.ma_decoder_seek_to_pcm_frame(&self.decoder, offset/AudioIO.channels);

        var local_buffer: [2048]AudioIO.SampleT = undefined;
        var offset_into_output_buffer: usize = 0;
        const samples_to_output = @min(buffer.len, self.sample_count - offset);
        var left_samples_to_output = samples_to_output;

        while (left_samples_to_output > 0) {

            const samples_to_output_to_a_local_buffer = @min(local_buffer.len, left_samples_to_output);
            var frames_read: miniaudio.ma_uint64 = undefined;
            _ = miniaudio.ma_decoder_read_pcm_frames(&self.decoder, &local_buffer, samples_to_output_to_a_local_buffer/AudioIO.channels, &frames_read);
            const samples_read = frames_read * AudioIO.channels;

            for (0..samples_to_output_to_a_local_buffer) | i | {
                buffer[offset_into_output_buffer+i] += local_buffer[i] * channel_multipliers[i%AudioIO.channels];
            }

            offset_into_output_buffer += samples_read;
            left_samples_to_output -= samples_read;

        }

        return samples_to_output;

    }

};