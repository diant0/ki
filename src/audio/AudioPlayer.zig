const AudioIO = @import("AudioIO.zig").AudioIO;
const AudioSource = @import("AudioSource.zig").AudioSource;
const math = @import("math");
const miniaudio = @import("miniaudio");
const std = @import("std");

pub const AudioPlayer = struct {
    
    source: AudioSource,
    // cursor is in samples, not frames
    cursor: usize,
    // from -1 to 1
    pan: f32 = 1.0,
    gain: f32 = 1.0,

    pub fn reset(self: *@This()) void {
        self.cursor = 0;
    }

    pub fn sumToBufferAdvance(self: *@This(), buffer: []AudioIO.SampleT) usize {

        const channel_multipliers = [AudioIO.channels]AudioIO.SampleT {
            math.clamp(-self.pan+1, 0, 1) * self.gain,
            math.clamp(self.pan+1, 0, 1) * self.gain,
        };

        const result_sample_count = self.source.sumToBuffer(self.cursor, buffer, channel_multipliers);

        self.cursor += result_sample_count;

        return result_sample_count;

    }

};