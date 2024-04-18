const AudioIO = @import("AudioIO.zig").AudioIO;
const AudioSource = @import("AudioSource.zig").AudioSource;
const math = @import("math");

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

        const samples_left = self.source.sampleCount() - self.cursor;
        const result_sample_count = @min(samples_left, buffer.len);

        defer self.cursor += result_sample_count;

        switch (self.source) {
            .predecoded => | x | {
                for (0..result_sample_count) | i | {
                    const pan_gain = if (i%2==0) math.clamp(-self.pan+1, 0, 1) else math.clamp(self.pan+1, 0, 1);
                    buffer[i] += x.samples[self.cursor+i] * self.gain * pan_gain;
                }
            }
        }

        return result_sample_count;

    }

    pub fn fillBufferAdvance(self: *@This(), buffer: []AudioIO.SampleT) usize {

        const samples_left = self.source.sampleCount() - self.cursor;
        const result_sample_count = @min(samples_left, buffer.len);

        defer self.cursor += result_sample_count;

        switch (self.source) {
            .predecoded => | x | {
                for (0..result_sample_count) | i | {
                    const pan_gain = if (i%2==0) math.clamp(-self.pan+1, 0, 1) else math.clamp(self.pan+1, 0, 1);
                    buffer[i] = x.samples[self.cursor+i] * self.gain * pan_gain;
                }
            }
        }

        return result_sample_count;

    }

};