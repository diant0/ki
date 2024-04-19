const AudioPlayer = @import("AudioPlayer.zig").AudioPlayer;
const DynArr = @import("../DynArr.zig").DynArr;
const std = @import("std");
const AudioIO = @import("AudioIO.zig").AudioIO;
const AudioSource = @import("AudioSource.zig").AudioSource;

pub const AudioGroup = struct {

    players: DynArr(?AudioPlayer, .{ .auto_shrink_capacity = false }) = .{},
    subgroups: DynArr(@This(), .{ .auto_shrink_capacity = false }) = .{},

    pub fn initAlloc(self: *@This(), allocator: std.mem.Allocator) !void {
        try self.players.init(allocator);
        try self.subgroups.init(allocator);
    }

    pub fn free(self: *const @This()) void {
        self.players.free();
        self.subgroups.free();
    }

    const PlayOptions = struct {
        starting_cursor: usize = 0,
        pan: f32 = 0,
        gain: f32 = 1,
    };

    /// NOTE: playing multiple instances of same .streamed audio sources will cause problems
    pub fn play(self: *@This(), audio: AudioSource, play_options: PlayOptions) !void {
        
        const player: AudioPlayer = .{
            .source = audio,
            .cursor = play_options.starting_cursor,
            .pan = play_options.pan,
            .gain = play_options.gain,
        };

        for (self.players.items(), 0..) | audio_player_slot, i | {
            if (audio_player_slot == null) {
                self.players.items()[i] = player;
                break;
            }
        } else try self.players.pushBack(player);

    }

    pub fn sumToBufferAdvance(self: *@This(), buffer: []AudioIO.SampleT) void {

        for (self.subgroups.items()) | *subgroup | {
            subgroup.sumToBufferAdvance(buffer);
        }

        for (self.players.items(), 0..) | _, i | {
            if (self.players.items()[i]) | *audio_player | {
                const advanced_by = audio_player.sumToBufferAdvance(buffer);
                if (advanced_by < buffer.len) {
                    self.players.items()[i] = null;
                }
            }
        }
        
    }

};