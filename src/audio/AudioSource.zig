const std = @import("std");
const AudioIO = @import("AudioIO.zig").AudioIO;
const miniaudio = @import("miniaudio");
const AudioPlayer = @import("AudioPlayer.zig").AudioPlayer;
const DynArr = @import("../DynArr.zig").DynArr;

/// NOTE: .streamed_from_memory is useless on fast drives.
pub const AudioSourceType = enum {
    predecoded, decoded_threaded, streamed_from_disk, streamed_from_memory,
};

pub const AudioSource = union(AudioSourceType) {

    predecoded: AudioSourcePredecoded,
    decoded_threaded: AudioSourceDecodedThreaded,
    streamed_from_disk: AudioSourceStreamedFromDisk,
    streamed_from_memory: AudioSourceStreamedFromMemory,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded           => .{ .predecoded           = try AudioSourcePredecoded.maFromPathRelToExeAlloc(allocator, path), },
            .decoded_threaded     => .{ .decoded_threaded     = try AudioSourceDecodedThreaded.maFromPathRelToExeAlloc(allocator, path), },
            .streamed_from_disk   => .{ .streamed_from_disk   = try AudioSourceStreamedFromDisk.maFromPathRelToExeAlloc(allocator, path), },
            .streamed_from_memory => .{ .streamed_from_memory = try AudioSourceStreamedFromMemory.maFromPathRelToExeAlloc(allocator, path) },
        };
    }

    pub fn maFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded           => .{ .predecoded           = try AudioSourcePredecoded.maFromAbsPathAlloc(allocator, path), },
            .decoded_threaded     => .{ .decoded_threaded     = try AudioSourceDecodedThreaded.maFromAbsPathAlloc(allocator, path), },
            .streamed_from_disk   => .{ .streamed_from_disk   = try AudioSourceStreamedFromDisk.maFromAbsPath(path), },
            .streamed_from_memory => .{ .streamed_from_memory = try AudioSourceStreamedFromMemory.maFromAbsPathAlloc(allocator, path) },
        };
    }

    pub fn maFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded           => .{ .predecoded           = try AudioSourcePredecoded.maFromFileAlloc(allocator, file), },
            .decoded_threaded     => .{ .decoded_threaded     = try AudioSourceDecodedThreaded.maFromFileAlloc(allocator, file), },
            .streamed_from_disk   => return error.NoStreamedAudioWithZigFileIO,
            .streamed_from_memory => .{ .streamed_from_memory = try AudioSourceStreamedFromMemory.maFromFileAlloc(allocator, file), },
        };
    }

    pub fn maFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8, audio_source_type: AudioSourceType) !@This() {
        return switch (audio_source_type) {
            .predecoded           => .{ .predecoded           = try AudioSourcePredecoded.maFromMemAlloc(allocator, bytes), },
            .decoded_threaded     => .{ .decoded_threaded     = try AudioSourceDecodedThreaded.maFromMemAlloc(allocator, bytes), },
            .streamed_from_disk   => return error.NoStreamedAudioFromMemory,
            .streamed_from_memory => .{ .streamed_from_memory = try AudioSourceStreamedFromMemory.fromMem(bytes) }
        };
    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .predecoded           => self.predecoded.free(allocator),
            .decoded_threaded     => self.decoded_threaded.free(allocator),
            .streamed_from_disk   => self.streamed_from_disk.free(),
            .streamed_from_memory => self.streamed_from_memory.free(allocator),
        }
    }

    pub var nanos_spent: i128 = 0;
    pub var samples_passed: i128 = 0;

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        
        const start_time = std.time.nanoTimestamp();
        defer {
            nanos_spent += std.time.nanoTimestamp() - start_time;
            samples_passed += buffer.len;
        }

        return switch (self.*) {
            .predecoded           => self.predecoded.sumToBuffer(offset, buffer, channel_multipliers),
            .decoded_threaded     => self.decoded_threaded.sumToBuffer(offset, buffer, channel_multipliers),
            .streamed_from_disk   => self.streamed_from_disk.sumToBuffer(offset, buffer, channel_multipliers),
            .streamed_from_memory => self.streamed_from_memory.sumToBuffer(offset, buffer, channel_multipliers),
        };
    }

    pub fn sampleCount(self: *const @This()) usize {
        return switch(self.*) {
            .predecoded => self.predecoded.samples.len,
            .decoded_threaded => self.decoded_threaded.samples.len,
            .streamed_from_disk => switch (self.streamed_from_disk) {
                .miniaudio => self.streamed_from_disk.miniaudio.sample_count,
            },
            .streamed_from_memory => switch (self.streamed_from_memory) {
                .miniaudio => self.streamed_from_memory.miniaudio.sample_count,
            },
        };
    }

};

pub const AudioSourcePredecoded = struct {

    samples: []const AudioIO.SampleT,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exe_dir_path);
        var exe_dir = try std.fs.openDirAbsolute(exe_dir_path, .{});
        defer exe_dir.close();

        const abs_path = try exe_dir.realpathAlloc(allocator, path);
        defer allocator.free(abs_path);

        return try maFromAbsPathAlloc(allocator, abs_path);

    }

    pub fn maFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        return try maFromFileAlloc(allocator, file);

    }

    pub fn maFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File) !@This() {

        const file_contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(file_contents);

        return try maFromMemAlloc(allocator, file_contents);
    
    }

    pub fn maFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8) !@This() {

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

pub const AudioSourceStreamedFromDisk = union(enum) {

    miniaudio: AudioSourceStreamedFromDiskMiniaudio,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {
        return .{
            .miniaudio = try AudioSourceStreamedFromDiskMiniaudio.fromPathRelToExeAlloc(allocator, path),
        };
    }

    pub fn maFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {
        return .{
            .miniaudio = try AudioSourceStreamedFromDiskMiniaudio.fromAbsPathAlloc(allocator, path),
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

pub const AudioSourceStreamedFromDiskMiniaudio = struct {

    decoder: miniaudio.ma_decoder,
    sample_count: miniaudio.ma_uint64,

    pub fn fromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exe_dir_path);
        var exe_dir = try std.fs.openDirAbsolute(exe_dir_path, .{});
        defer exe_dir.close();

        const abs_path = try exe_dir.realpathAlloc(allocator, path);
        defer allocator.free(abs_path);

        return try fromAbsPathAlloc(allocator, abs_path);

    }

    pub fn fromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        if (!std.fs.path.isAbsolute(path)) {
            return error.PathNotAbsolute;
        }

        const path_null_terminated = try allocator.dupeZ(u8, path);
        defer allocator.free(path_null_terminated);

        const decoder_config = miniaudio.ma_decoder_config_init(AudioIO.format, AudioIO.channels, AudioIO.sample_rate);
        
        var decoder = blk: {
            var x: miniaudio.ma_decoder = undefined;
            const result = miniaudio.ma_decoder_init_file(path_null_terminated.ptr, &decoder_config, &x);
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
        return maDecoderSumToBuffer(&self.decoder, self.sample_count, offset, buffer, channel_multipliers);
    }

};

pub const AudioSourceStreamedFromMemory = union(enum) {

    miniaudio: AudioSourceStreamedFromMemoryMiniaudio,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {
        return .{ .miniaudio = try AudioSourceStreamedFromMemoryMiniaudio.fromPathRelToExeAlloc(allocator, path) };
    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .miniaudio => self.miniaudio.free(allocator),
        }
    }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        return switch (self.*) {
            .miniaudio => self.miniaudio.sumToBuffer(offset, buffer, channel_multipliers),
        };
    }
};

pub const AudioSourceStreamedFromMemoryMiniaudio = struct {

    encoded: []const u8,
    decoder: miniaudio.ma_decoder,
    sample_count: miniaudio.ma_uint64,

    pub fn fromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exe_dir_path);
        var exe_dir = try std.fs.openDirAbsolute(exe_dir_path, .{});
        defer exe_dir.close();

        const abs_path = try exe_dir.realpathAlloc(allocator, path);
        defer allocator.free(abs_path);

        return try fromAbsPathAlloc(allocator, abs_path);

    }

    pub fn fromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        return try fromFileAlloc(allocator, file);

    }

    pub fn fromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File) !@This() {

        const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

        return try fromMem(bytes);

    }

    pub fn fromMem(bytes: []const u8) !@This() {

        const decoder_config = miniaudio.ma_decoder_config_init(AudioIO.format, AudioIO.channels, AudioIO.sample_rate);

        var decoder = blk: {
            var x: miniaudio.ma_decoder = undefined;
            const decoder_init_result = miniaudio.ma_decoder_init_memory(bytes.ptr, @intCast(bytes.len), &decoder_config, &x);
            std.debug.assert(decoder_init_result == miniaudio.MA_SUCCESS);
            break :blk x;
        };

        return .{
            .encoded = bytes,
            .decoder = decoder,
            .sample_count = blk: {
                var x: miniaudio.ma_uint64 = undefined;
                _ = miniaudio.ma_decoder_get_length_in_pcm_frames(&decoder, &x);
                break :blk x * AudioIO.channels;
            }
        };

    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        _ = miniaudio.ma_decoder_uninit(&self.decoder);
        allocator.free(self.encoded);
    }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        return maDecoderSumToBuffer(&self.decoder, self.sample_count, offset, buffer, channel_multipliers);
    }

};

pub const AudioSourceDecodedThreaded = struct {

    samples: []const AudioIO.SampleT,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exe_dir_path);
        var exe_dir = try std.fs.openDirAbsolute(exe_dir_path, .{});
        defer exe_dir.close();

        const abs_path = try exe_dir.realpathAlloc(allocator, path);
        defer allocator.free(abs_path);

        return try maFromAbsPathAlloc(allocator, abs_path);

    }

    pub fn maFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {

        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        return try maFromFileAlloc(allocator, file);

    }

    pub fn maFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File) !@This() {

        const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

        return try maFromMemAlloc(allocator, bytes);

    }

    pub fn maFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8) !@This() {

        const decoder_config = miniaudio.ma_decoder_config_init(AudioIO.format, AudioIO.channels, AudioIO.sample_rate);


        const decoder = blk: {
            const x = try allocator.create(miniaudio.ma_decoder);
            const decoder_init_result = miniaudio.ma_decoder_init_memory(bytes.ptr, @intCast(bytes.len), &decoder_config, x);
            std.debug.assert(decoder_init_result == miniaudio.MA_SUCCESS);
            break :blk x;
        };

        const sample_count = blk: {
            var x: miniaudio.ma_uint64 = undefined;
            _ = miniaudio.ma_decoder_get_length_in_pcm_frames(decoder, &x);
            break :blk x * AudioIO.channels;
        };

        const samples: []AudioIO.SampleT = try allocator.alloc(AudioIO.SampleT, sample_count);

        const thread = try std.Thread.spawn(.{}, maDecodeFreeEncoded, .{ allocator, samples, bytes, decoder });
        thread.detach();

        return .{
            .samples = samples,
        };

    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
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

fn maDecodeFreeEncoded(allocator: std.mem.Allocator, out_buffer: []AudioIO.SampleT, in_bytes: []const u8, decoder: *miniaudio.ma_decoder) void {

    var frames_read: usize = undefined;
    _ = miniaudio.ma_decoder_read_pcm_frames(decoder, @ptrCast(out_buffer), out_buffer.len/AudioIO.channels, &frames_read);

    std.debug.print("background decode finished\n", .{});

    _ = miniaudio.ma_decoder_uninit(decoder);
    allocator.free(in_bytes);
    allocator.destroy(decoder);

}

fn maDecoderSumToBuffer(decoder: *miniaudio.ma_decoder, sample_count: miniaudio.ma_uint64,
    offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {

    _ = miniaudio.ma_decoder_seek_to_pcm_frame(decoder, offset/AudioIO.channels);

    var local_buffer: [2048]AudioIO.SampleT = undefined;
    var offset_into_output_buffer: usize = 0;
    const samples_to_output = @min(buffer.len, sample_count - offset);
    var left_samples_to_output = samples_to_output;

    while (left_samples_to_output > 0) {

        const samples_to_output_to_a_local_buffer = @min(local_buffer.len, left_samples_to_output);
        var frames_read: miniaudio.ma_uint64 = undefined;
        _ = miniaudio.ma_decoder_read_pcm_frames(decoder, &local_buffer, samples_to_output_to_a_local_buffer/AudioIO.channels, &frames_read);
        const samples_read = frames_read * AudioIO.channels;

        for (0..samples_to_output_to_a_local_buffer) | i | {
            buffer[offset_into_output_buffer+i] += local_buffer[i] * channel_multipliers[i%AudioIO.channels];
        }

        offset_into_output_buffer += samples_read;
        left_samples_to_output -= samples_read;

    }

    return samples_to_output;


}