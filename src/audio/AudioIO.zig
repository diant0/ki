const miniaudio = @import("miniaudio");
const log = @import("../log.zig");
const std = @import("std");
const AudioGroup = @import("AudioGroup.zig").AudioGroup;

pub const AudioIO = struct {

    pub const SampleT = f32;
    pub const format = miniaudio.ma_format_f32;
    pub const sample_rate = miniaudio.ma_standard_sample_rate_48000;
    pub const channels = 2;

    device: miniaudio.ma_device = undefined,

    group: AudioGroup = .{},
    
    pub fn initAlloc(self: *@This(), allocator: std.mem.Allocator) !void {

        try self.group.initAlloc(allocator);

        const device_config = blk: {
            var x = miniaudio.ma_device_config_init(miniaudio.ma_device_type_playback);
            x.playback.format = format;
            x.playback.channels = channels;
            x.sampleRate = sample_rate;
            x.dataCallback = audioDataCallback;
            x.pUserData = self;
            break :blk x;
        };

        const device_init_result = miniaudio.ma_device_init(null, &device_config, &self.device);
        if (device_init_result != miniaudio.MA_SUCCESS) {
            return error.MiniaudioDeviceInitFailed;
        }

        const device_start_result = miniaudio.ma_device_start(&self.device);
        if (device_start_result != miniaudio.MA_SUCCESS) {
            return error.MiniaudioDeviceInitFailed;
        }

    }

    pub fn free(self: *@This()) void {
        self.group.free();
        _ = miniaudio.ma_device_stop(&self.device);
        miniaudio.ma_device_uninit(&self.device);
    }

};

fn audioDataCallback(device: [*c]miniaudio.ma_device, output_opaque: ?*anyopaque, _: ?*const anyopaque, frame_count: miniaudio.ma_uint32) callconv(.C) void {

    switch (miniaudio.ma_device_get_state(device)) {
        miniaudio.ma_device_state_starting, miniaudio.ma_device_state_stopping => return,
        else => {},
    }

    const audio_io: *AudioIO = if (device[0].pUserData) | ptr | @ptrCast(@alignCast(ptr)) else {
        log.print(.Error, "could not retrieve audio device data\n", .{});
        return;
    };

    const output: []AudioIO.SampleT = @as([*]AudioIO.SampleT, @ptrCast(@alignCast(output_opaque orelse return)))[0..frame_count*AudioIO.channels];

    audio_io.group.sumToBufferAdvance(output);

}