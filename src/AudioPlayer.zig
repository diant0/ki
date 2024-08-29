const AudioIO = @import("AudioIO.zig").AudioIO;
const AudioSource = @import("AudioSource.zig").AudioSource;
const math = @import("math");
const miniaudio = @import("miniaudio");
const std = @import("std");

source: AudioSource,
// cursor is in samples, not frames
cursor: usize,
// from -1 to 1
pan: f32 = 1.0,
gain: f32 = 1.0,
loop: bool = false,

pub fn reset(self: *@This()) void {
    self.cursor = 0;
}

pub fn sumToBufferAdvance(self: *@This(), buffer: []AudioIO.SampleT) usize {
    const channel_multipliers = [AudioIO.channels]AudioIO.SampleT{
        math.clamp(-self.pan + 1, 0, 1) * self.gain,
        math.clamp(self.pan + 1, 0, 1) * self.gain,
    };

    if (self.loop) {
        var samples_left_to_fill_buffer = buffer.len;
        var buffer_offset: usize = 0;
        while (samples_left_to_fill_buffer > 0) {
            const pass_sample_count = self.source.sumToBuffer(self.cursor, buffer[buffer_offset..buffer.len], channel_multipliers);
            samples_left_to_fill_buffer -= pass_sample_count;
            buffer_offset += pass_sample_count;
            self.cursor = (self.cursor + pass_sample_count) % self.source.sampleCount();
        }
        return buffer.len;
    } else {
        const first_pass_sample_count = self.source.sumToBuffer(self.cursor, buffer, channel_multipliers);
        self.cursor += first_pass_sample_count;
        return first_pass_sample_count;
    }
}
