const AudioPlayer = @import("AudioPlayer.zig").AudioPlayer;
const DynArr = @import("dyn_arr.zig").DynArr;
const std = @import("std");
const AudioIO = @import("AudioIO.zig").AudioIO;
const AudioSource = @import("AudioSource.zig").AudioSource;

players: DynArr(?AudioPlayer, .{ .auto_shrink_capacity = false }) = .{},
children: DynArr(@This(), .{ .auto_shrink_capacity = false }) = .{},

pub fn initAlloc(self: *@This(), allocator: std.mem.Allocator) !void {
    try self.players.init(allocator);
    try self.children.init(allocator);
}

pub fn free(self: *const @This()) void {
    self.players.free();
    self.children.free();
}

const PlayOptions = struct {
    starting_cursor: usize = 0,
    pan: f32 = 0,
    gain: f32 = 1,
    loop: bool = false,
};

pub fn play(self: *@This(), audio: AudioSource, play_options: PlayOptions) !void {
    const player: AudioPlayer = .{
        .source = audio,
        .cursor = play_options.starting_cursor,
        .pan = play_options.pan,
        .gain = play_options.gain,
        .loop = play_options.loop,
    };

    for (self.players.items(), 0..) |audio_player_slot, i| {
        if (audio_player_slot == null) {
            self.players.items()[i] = player;
            break;
        }
    } else try self.players.pushBack(player);
}

pub fn sumToBufferAdvance(self: *@This(), buffer: []AudioIO.SampleT) void {
    for (self.children.items()) |*child| {
        child.sumToBufferAdvance(buffer);
    }

    for (self.players.items(), 0..) |_, i| {
        if (self.players.items()[i]) |*audio_player| {
            const advanced_by = audio_player.sumToBufferAdvance(buffer);
            if (advanced_by < buffer.len and !audio_player.loop) {
                self.players.items()[i] = null;
            }
        }
    }
}
