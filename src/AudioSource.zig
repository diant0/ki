const std = @import("std");
const DynArr = @import("../DynArr.zig").DynArr;
const miniaudio = @import("miniaudio");
const AudioIO = @import("AudioIO.zig").AudioIO;
const AudioPlayer = @import("AudioPlayer.zig").AudioPlayer;

// NOTE: with miniaudio, passing ma_decoder by value produces a lot of
// unpredictable failures, so allocating it on heap is pretty much required

/// TODO: blocking/nonblocking strategies need better names.
pub const DecodingStrategy = enum {
    blocking, nonblocking, stream_from_disk, stream_from_memory,
};

pub const AudioSource = union(DecodingStrategy) {

    // NOTE: blocking and nonblocking decoding strategies will result in pretty
    // high peak memory usage since until decoding finished, we need both
    // encoded bytes and decoded samples in-memory.
    // reason for this is we cannot use ma_decoder with zig's file io.
    // ma_decoder expects either a filepath or a whole file's contents in-memory.

    // TODO: investigate qoa, reference implementation is pretty light, so
    // implementing/adapting it may enable streaming encoded bytes from disk,
    // potentially reducing peak memory usage.
    // however, qoa.h uses c_shorts(i16). should be trivial to map, especially with @Vector,
    // still, its an additional step. speed of decoding might be able to offset this.

    /// simplest one.
    /// setback is you have to wait until audio has been decoded.
    blocking: AudioSourceBlocking,

    /// decodes in a separate thread.
    /// freeing is only possible once decoding finishes
    nonblocking: AudioSourceNonBlocking,

    /// streams directly from disk.
    /// sebacks are not being able to use this strategy from memory and not being able to play more
    /// than one instance of such audio source.
    stream_from_disk: AudioSourceStreamFromDisk,

    // streams from memory. can be used with zig's file io.
    // might be useful if disk is slow.
    stream_from_memory: AudioSourceStreamFromMemory,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8, decoding_strategy: DecodingStrategy) !@This() {
        return switch (decoding_strategy) {
            .blocking           => .{ .blocking           = try AudioSourceBlocking.maFromPathRelToExeAlloc(allocator, path), },
            .nonblocking        => .{ .nonblocking        = try AudioSourceNonBlocking.maFromPathRelToExeAlloc(allocator, path), },
            .stream_from_disk   => .{ .stream_from_disk   = try AudioSourceStreamFromDisk.maFromPathRelToExeAlloc(allocator, path), },
            .stream_from_memory => .{ .stream_from_memory = try AudioSourceStreamFromMemory.maFromPathRelToExeAlloc(allocator, path), },
        };
    }

    pub fn maFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8, decoding_strategy: DecodingStrategy) !@This() {
        return switch (decoding_strategy) {
            .blocking           => .{ .blocking           = try AudioSourceBlocking.maFromAbsPathAlloc(allocator, path), },
            .nonblocking        => .{ .nonblocking        = try AudioSourceNonBlocking.maFromAbsPathAlloc(allocator, path), },
            .stream_from_disk   => .{ .stream_from_disk   = try AudioSourceStreamFromDisk.maFromAbsPathAlloc(allocator, path), },
            .stream_from_memory => .{ .stream_from_memory = try AudioSourceStreamFromMemory.maFromAbsPathAlloc(allocator, path), },
        };
    }

    pub fn maFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File, decoding_strategy: DecodingStrategy) !@This() {
        return switch (decoding_strategy) {
            .blocking           => .{ .blocking           = try AudioSourceBlocking.maFromFileAlloc(allocator, file), },
            .nonblocking        => .{ .nonblocking        = try AudioSourceNonBlocking.maFromFileAlloc(allocator, file), },
            .stream_from_disk   => return error.StreamingAudioNotAvailableWithZigFileIO,
            .stream_from_memory => .{ .stream_from_memory = try AudioSourceStreamFromMemory.maFromFileAlloc(allocator, file), },
        };
    }

    pub fn maFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8, decoding_strategy: DecodingStrategy) !@This() {
        return switch (decoding_strategy) {
            .blocking           => .{ .blocking           = try AudioSourceBlocking.maFromMemAlloc(allocator, bytes), },
            .nonblocking        => .{ .nonblocking        = try AudioSourceNonBlocking.maFromMemAlloc(allocator, bytes), },
            .stream_from_disk   => return error.StreamingAudioNotAvailableFromMemory,
            .stream_from_memory => .{ .stream_from_memory = try AudioSourceStreamFromMemory.maFromMemAlloc(allocator, bytes), },
        };
    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .blocking           => self.blocking.free(allocator),
            .nonblocking        => self.nonblocking.free(allocator),
            .stream_from_disk   => self.stream_from_disk.free(allocator),
            .stream_from_memory => self.stream_from_memory.free(allocator),
        }
    }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        return switch (self.*) {
            .blocking           => self.blocking.sumToBuffer(offset, buffer, channel_multipliers),
            .nonblocking        => self.nonblocking.sumToBuffer(offset, buffer, channel_multipliers),
            .stream_from_disk   => self.stream_from_disk.sumToBuffer(offset, buffer, channel_multipliers),
            .stream_from_memory => self.stream_from_memory.sumToBuffer(offset, buffer, channel_multipliers),
        };
    }

    pub inline fn sampleCount(self: *const @This()) usize {
        return switch(self.*) {
            .blocking           => self.blocking.sampleCount(),
            .nonblocking        => self.nonblocking.sampleCount(),
            .stream_from_disk   => self.stream_from_disk.sampleCount(),
            .stream_from_memory => self.stream_from_memory.sampleCount(),
        };
    }

};

pub const AudioSourceBlocking = struct {

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
            const result = miniaudio.ma_decoder_init_memory(bytes.ptr, @intCast(bytes.len), &decoder_config, &x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioDecoderInitFailed;
            }
            break :blk x;
        };

        const pcm_frame_count = blk: {
            var x: miniaudio.ma_uint64 = undefined;
            const result = miniaudio.ma_decoder_get_length_in_pcm_frames(&decoder, &x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioDecoderGetLengthFailed;
            }            
            break :blk x;
        };

        const decoded = try allocator.alloc(AudioIO.SampleT, pcm_frame_count * AudioIO.channels);

        const pcm_frames_read = blk: {
            var x: miniaudio.ma_uint64 = undefined;
            const result = miniaudio.ma_decoder_read_pcm_frames(&decoder, decoded.ptr, pcm_frame_count, &x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioReadFramesFailed;
            }
            break :blk x;
        };
        
        if (pcm_frames_read != pcm_frame_count) {
            return error.MiniaudioCouldNotDecodeAllFrames;
        }

        _ = miniaudio.ma_decoder_uninit(&decoder);

        return .{
            .samples = decoded,
        };

    }

    pub fn free(self: *const @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.samples);
    }

    pub inline fn sampleCount(self: *const @This()) usize {
        return self.samples.len;
    }

    pub fn sumToBuffer(self: *const @This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {

        const samples_left = @min(buffer.len, self.samples.len - offset);
        for (0..samples_left) | i | {
            buffer[i] += self.samples[offset+i] * channel_multipliers[i%channel_multipliers.len];
        }

        return samples_left;

    }

};

pub const AudioSourceStreamFromDisk = union(enum) {

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

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .miniaudio => self.miniaudio.free(allocator),
        }
    }

    pub inline fn sampleCount(self: *const @This()) usize {
        return switch (self.*) {
            .miniaudio => self.miniaudio.sample_count,
        };
    }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        return switch (self.*) {
            .miniaudio => self.miniaudio.sumToBuffer(offset, buffer, channel_multipliers),
        };
    }

};

pub const AudioSourceNonBlocking = struct {

    samples: []const AudioIO.SampleT,
    mutex: *std.Thread.Mutex,

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
            const result = miniaudio.ma_decoder_init_memory(bytes.ptr, @intCast(bytes.len), &decoder_config, x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioDecoderInitFailed;
            }
            break :blk x;
        };

        const sample_count = blk: {
            var x: miniaudio.ma_uint64 = undefined;
            const result = miniaudio.ma_decoder_get_length_in_pcm_frames(decoder, &x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioDecoderGetLengthFailed;
            }
            break :blk x * AudioIO.channels;
        };

        const samples: []AudioIO.SampleT = try allocator.alloc(AudioIO.SampleT, sample_count);

        // NOTE: possibly needs some "buffer" decoded in blocking mode,
        // in case callback arrives before thread spawns and starts
        // decoding samples.

        // TODO: some kind of messaging about validity of sample buffer.
        // right now freeing it while decoding still going on is guaranteed segfault.
        // is this even possible? we are decoding all samples at once,
        // and not in power to stop it once it starts.
        // maybe better way to do this will be to include a "finished" flag in a struct,
        // then we can block until decoding finishes on free (might be wasteful).
        // maybe both, with chunking of samples on spawned thread.
        // that way we can stop decoding sooner, but that will require two-way
        // communication with spawned thread.

        const mutex = try allocator.create(std.Thread.Mutex);

        const thread = try std.Thread.spawn(.{}, maDecodeThenFreeEncodedAndDecoder, .{ allocator, samples, bytes, decoder, mutex });
        thread.detach();

        return .{
            .samples = samples,
            .mutex = mutex,
        };

    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        self.mutex.lock();
        allocator.free(self.samples);
        self.mutex.unlock();
        allocator.destroy(self.mutex);
    }

    pub inline fn sampleCount(self: *const @This()) usize {
        return self.samples.len;
    }

    pub fn sumToBuffer(self: *const @This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {

        const samples_left = @min(buffer.len, self.samples.len - offset);
        for (0..samples_left) | i | {
            buffer[i] += self.samples[offset+i] * channel_multipliers[i%channel_multipliers.len];
        }

        return samples_left;

    }

};

pub const AudioSourceStreamedFromDiskMiniaudio = struct {

    decoder: *miniaudio.ma_decoder,
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
        
        const decoder = blk: {
            const x = try allocator.create(miniaudio.ma_decoder);
            const result = miniaudio.ma_decoder_init_file(path_null_terminated.ptr, &decoder_config, x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioDecoderInitFailed;
            }
            break :blk x;
        };

        const sample_count = blk: {
            var x: miniaudio.ma_uint64 = undefined;
            const result = miniaudio.ma_decoder_get_length_in_pcm_frames(decoder, &x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioDecoderGetLengthFailed;
            }
            break :blk x * AudioIO.channels;
        };

        return .{
            .decoder = decoder,
            .sample_count = sample_count,
        };

    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        _ = miniaudio.ma_decoder_uninit(self.decoder);
        allocator.destroy(self.decoder);
    }

    pub inline fn sampleCount(self: *const @This()) usize {
        return self.sample_count;
    }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        return maDecoderSumToBuffer(self.decoder, self.sample_count, offset, buffer, channel_multipliers);
    }

};

pub const AudioSourceStreamFromMemory = union(enum) {

    miniaudio: AudioSourceStreamedFromMemoryMiniaudio,

    pub fn maFromPathRelToExeAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {
        return .{
            .miniaudio = try AudioSourceStreamedFromMemoryMiniaudio.fromPathRelToExeAlloc(allocator, path),
        };
    }

    pub fn maFromAbsPathAlloc(allocator: std.mem.Allocator, path: []const u8) !@This() {
        return .{
            .miniaudio = try AudioSourceStreamedFromMemoryMiniaudio.fromAbsPathAlloc(allocator, path),
        };
    }

    pub fn maFromFileAlloc(allocator: std.mem.Allocator, file: std.fs.File) !@This() {
        return .{
            .miniaudio = try AudioSourceStreamedFromMemoryMiniaudio.fromFileAlloc(allocator, file),
        };
    }

    pub fn maFromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8) !@This() {
        return .{
            .miniaudio = try AudioSourceStreamedFromMemoryMiniaudio.fromMemAlloc(allocator, bytes),
        };
    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .miniaudio => self.miniaudio.free(allocator),
        }
    }

    pub inline fn sampleCount(self: *const @This()) usize {
        return switch (self.*) {
            .miniaudio => self.miniaudio.sampleCount(),
        };
    }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        return switch (self.*) {
            .miniaudio => self.miniaudio.sumToBuffer(offset, buffer, channel_multipliers),
        };
    }

};

pub const AudioSourceStreamedFromMemoryMiniaudio = struct {

    encoded: []const u8,
    decoder: *miniaudio.ma_decoder,
    sample_count: usize,

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

        const file_contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));

        return try fromMemAlloc(allocator, file_contents);

    }

    pub fn fromMemAlloc(allocator: std.mem.Allocator, bytes: []const u8) !@This() {

        const decoder_config = miniaudio.ma_decoder_config_init(AudioIO.format, AudioIO.channels, AudioIO.sample_rate);

        const decoder = blk: {
            const x = try allocator.create(miniaudio.ma_decoder);
            const result = miniaudio.ma_decoder_init_memory(bytes.ptr, @intCast(bytes.len), &decoder_config, x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioDecoderInitFailed;
            }
            break :blk x;
        };

        const sample_count = blk: {
            var x: miniaudio.ma_uint64 = undefined;
            const result = miniaudio.ma_decoder_get_length_in_pcm_frames(decoder, &x);
            if (result != miniaudio.MA_SUCCESS) {
                return error.MiniaudioDecoderGetLengthFailed;
            }
            break :blk x * AudioIO.channels;
        };

        return .{
            .encoded = bytes,
            .decoder = decoder,
            .sample_count = sample_count,
        };

    }

    pub fn free(self: *@This(), allocator: std.mem.Allocator) void {
        _ = miniaudio.ma_decoder_uninit(self.decoder);
        allocator.destroy(self.decoder);
        allocator.free(self.encoded);
    }

    pub inline fn sampleCount(self: *const @This()) usize {
        return self.sample_count;
    }

    pub fn sumToBuffer(self: *@This(), offset: usize, buffer: []AudioIO.SampleT, channel_multipliers: [AudioIO.channels]AudioIO.SampleT) usize {
        return maDecoderSumToBuffer(self.decoder, self.sample_count, offset, buffer, channel_multipliers);
    }

};

fn maDecodeThenFreeEncodedAndDecoder(allocator: std.mem.Allocator, out_buffer: []AudioIO.SampleT, in_bytes: []const u8, decoder: *miniaudio.ma_decoder, mutex: *std.Thread.Mutex) void {

    var frames_read: usize = undefined;

    mutex.lock();
    _ = miniaudio.ma_decoder_read_pcm_frames(decoder, @ptrCast(out_buffer), out_buffer.len/AudioIO.channels, &frames_read);
    mutex.unlock();

    std.debug.assert(frames_read*AudioIO.channels == out_buffer.len);

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