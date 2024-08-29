const std = @import("std");
const glfw = @import("glfw");
const math = @import("math");
const DynArr = @import("dyn_arr.zig").DynArr;

var log = &@import("ki.zig").log;

pub const ID = c_int;

pub const Button = State.Button;
pub const Axis = State.Axis;

pub const context = struct {
    pub const ConnectionEvent = union(enum) {
        connected: ID,
        disconnected: ID,
    };

    var connection_event_queue: DynArr(ConnectionEvent, .{
        .auto_shrink_capacity = false,
    }) = .{};

    pub fn initAlloc(allocator: std.mem.Allocator) !void {
        _ = glfw.glfwSetJoystickCallback(__onJoystick);

        try connection_event_queue.init(allocator);

        for (glfw.GLFW_JOYSTICK_1..glfw.GLFW_JOYSTICK_16) |id| {
            if (glfw.glfwJoystickPresent(@intCast(id)) == glfw.GLFW_TRUE) {
                try connection_event_queue.pushBack(.{ .connected = @intCast(id) });
            }
        }
    }

    pub fn terminateFree() void {
        connection_event_queue.free();
    }

    pub fn consumeConnectionEvent() ?ConnectionEvent {
        const event = connection_event_queue.popFront();
        if (event == null) {
            connection_event_queue.clear();
        }
        return event;
    }
};

id: ID,
name: [*c]const u8,

state_raw: StateRaw = .{},
state: State = .{},

deadzone: f32 = 0.3,
quantize_step: f32 = 0.1,
axis_to_button_threshold: f32 = 0.4,

event_queue: DynArr(Event, .{ .auto_shrink_capacity = false }) = .{},

pub fn fromIDAlloc(allocator: std.mem.Allocator, id: ID) !@This() {
    if (glfw.glfwJoystickPresent(id) == glfw.GLFW_FALSE) {
        return error.DeviceNotConnected;
    }
    if (glfw.glfwJoystickIsGamepad(id) == glfw.GLFW_FALSE) {
        return error.DeviceMappingNotAvailable;
    }

    if (StateRaw.get(id)) |state_raw| {
        var gamepad: @This() = .{
            .id = id,
            .name = glfw.glfwGetGamepadName(id),
            .state_raw = state_raw,
        };
        try gamepad.event_queue.init(allocator);
        try gamepad.pollState();
        return gamepad;
    } else return error.CouldNotPollGameState;
}

pub fn free(self: *const @This()) void {
    self.event_queue.free();
}

pub fn isConnected(self: *const @This()) bool {
    return glfw.glfwJoystickPresent(self.id) != glfw.GLFW_FALSE;
}

pub fn pollState(self: *@This()) !void {
    if (!self.isConnected()) return;

    if (StateRaw.get(self.id)) |new_state_raw| {
        inline for (@typeInfo(StateRaw.Button).Enum.fields) |raw_button_enum_field_info| {
            const button_raw: StateRaw.Button = @enumFromInt(raw_button_enum_field_info.value);
            const new_value = new_state_raw.buttons.get(button_raw);

            if (State.Button.fromRawButton(button_raw)) |button| {
                const previous_value = self.state.buttons.get(button);
                if (previous_value != new_value) {
                    self.state.buttons.set(button, new_value);
                    try self.event_queue.pushBack(.{ .button = .{
                        .button = button,
                        .down = new_value,
                    } });
                }
            }

            if (State.Axis.fromRawButton(button_raw)) |axis| {
                if (axis.buttonPair()) |button_pair| {
                    const negative_value: f32 = if (self.state.buttons.get(button_pair.neg)) 1.0 else 0.0;
                    const postivie_value: f32 = if (self.state.buttons.get(button_pair.pos)) 1.0 else 0.0;
                    const axis_value = postivie_value - negative_value;
                    const previous_value = self.state.axes.get(axis);
                    if (previous_value != axis_value) {
                        self.state.axes.set(axis, axis_value);
                        try self.event_queue.pushBack(.{ .axis = .{
                            .axis = axis,
                            .value = axis_value,
                        } });
                    }
                }
            }
        }

        inline for (@typeInfo(StateRaw.Axis).Enum.fields) |raw_axis_enum_field_info| {
            const axis_raw: StateRaw.Axis = @enumFromInt(raw_axis_enum_field_info.value);
            const value_raw = new_state_raw.axes.get(axis_raw);

            if (State.Axis.fromRawAxis(axis_raw)) |axis| {
                const value = self.processAxisValue(axis_raw, value_raw);
                const previous_value = self.state.axes.get(axis);
                if (previous_value != value) {
                    self.state.axes.set(axis, value);
                    try self.event_queue.pushBack(.{ .axis = .{
                        .axis = axis,
                        .value = value,
                    } });
                }
            }

            if (State.Button.fromRawAxis(axis_raw)) |button| {
                const previous_down = self.state.buttons.get(button);
                const button_down = value_raw >= self.axis_to_button_threshold;
                if (previous_down != button_down) {
                    self.state.buttons.set(button, button_down);
                    try self.event_queue.pushBack(.{ .button = .{
                        .button = button,
                        .down = button_down,
                    } });
                }
            }

            if (State.Button.directionalPairFromRawAxis(axis_raw)) |button_pair| {
                const adjusted_raw_value = if (axis_raw.inverted()) -value_raw else value_raw;
                const previous_neg_down = self.state.buttons.get(button_pair.neg);
                const neg_down = adjusted_raw_value <= -self.axis_to_button_threshold;
                if (previous_neg_down != neg_down) {
                    self.state.buttons.set(button_pair.neg, neg_down);
                    try self.event_queue.pushBack(.{ .button = .{
                        .button = button_pair.neg,
                        .down = neg_down,
                    } });
                }
                const previous_pos_down = self.state.buttons.get(button_pair.pos);
                const pos_down = adjusted_raw_value >= self.axis_to_button_threshold;
                if (previous_pos_down != pos_down) {
                    self.state.buttons.set(button_pair.pos, pos_down);
                    try self.event_queue.pushBack(.{ .button = .{
                        .button = button_pair.pos,
                        .down = pos_down,
                    } });
                }
            }
        }

        self.state_raw = new_state_raw;
    }
}

pub fn consumeEvent(self: *@This()) ?Event {
    const event = self.event_queue.popFront();
    if (event == null) {
        self.event_queue.clear();
    }
    return event;
}

fn processAxisValue(self: *const @This(), axis: StateRaw.Axis, value: f32) f32 {
    switch (axis) {
        .L2, .R2 => {
            const mapped = value * 0.5 + 0.5;
            if (mapped < self.deadzone) {
                return 0;
            }
            return math.quantize(mapped, self.quantize_step);
        },
        else => {
            const sign = math.sign(value) * @as(f32, if (axis.inverted()) -1.0 else 1.0);
            const magnitude = math.abs(value);
            if (magnitude < self.deadzone) {
                return 0;
            }
            const quantized = math.quantize(magnitude, self.quantize_step);
            return quantized * sign;
        },
    }
}

pub const Event = union(enum) {
    pub const Button = struct {
        button: State.Button,
        down: bool,
    };

    pub const Axis = struct {
        axis: State.Axis,
        value: f32,
    };

    button: @This().Button,
    axis: @This().Axis,
};

pub const State = struct {
    buttons: std.EnumArray(@This().Button, bool) = std.EnumArray(@This().Button, bool).initFill(false),
    axes: std.EnumArray(@This().Axis, f32) = std.EnumArray(@This().Axis, f32).initFill(0),

    pub const Button = enum {
        LLeft,
        LRight,
        LUp,
        LDown,
        RLeft,
        RRight,
        RUp,
        RDown,
        South,
        East,
        West,
        North,
        L1,
        R1,
        L2,
        R2,
        L3,
        R3,
        Back,
        Start,
        Guide,
        DPadUp,
        DPadDown,
        DPadLeft,
        DPadRight,

        fn fromRawButton(raw: StateRaw.Button) ?@This() {
            return switch (raw) {
                .South => .South,
                .East => .East,
                .West => .West,
                .North => .North,
                .L1 => .L1,
                .R1 => .R1,
                .L3 => .L3,
                .R3 => .R3,
                .Back => .Back,
                .Start => .Start,
                .Guide => .Guide,
                .DPadUp => .DPadUp,
                .DPadDown => .DPadDown,
                .DPadLeft => .DPadLeft,
                .DPadRight => .DPadRight,
            };
        }

        fn fromRawAxis(raw: StateRaw.Axis) ?@This() {
            return switch (raw) {
                .L2 => .L2,
                .R2 => .R2,
                else => null,
            };
        }

        fn directionalPairFromRawAxis(raw: StateRaw.Axis) ?struct { neg: State.Button, pos: State.Button } {
            return switch (raw) {
                .LeftX => .{ .neg = .LLeft, .pos = .LRight },
                .LeftY => .{ .neg = .LDown, .pos = .LUp },
                .RightX => .{ .neg = .RLeft, .pos = .RRight },
                .RightY => .{ .neg = .RDown, .pos = .RUp },
                else => null,
            };
        }
    };

    pub const Axis = enum {
        LeftX,
        LeftY,
        RightX,
        RightY,
        L2,
        R2,
        DPadX,
        DPadY,

        fn fromRawAxis(raw: StateRaw.Axis) ?@This() {
            return switch (raw) {
                .LeftX => .LeftX,
                .LeftY => .LeftY,
                .RightX => .RightX,
                .RightY => .RightY,
                .L2 => .L2,
                .R2 => .R2,
            };
        }

        fn fromRawButton(raw: StateRaw.Button) ?@This() {
            return switch (raw) {
                .DPadLeft, .DPadRight => .DPadX,
                .DPadUp, .DPadDown => .DPadY,
                else => null,
            };
        }

        fn buttonPair(self: @This()) ?struct { neg: State.Button, pos: State.Button } {
            return switch (self) {
                .DPadX => .{ .neg = .DPadLeft, .pos = .DPadRight },
                .DPadY => .{ .neg = .DPadDown, .pos = .DPadUp },
                else => null,
            };
        }
    };
};

pub const StateRaw = struct {
    pub const Button = enum(@TypeOf(glfw.GLFW_GAMEPAD_BUTTON_A)) {
        South = glfw.GLFW_GAMEPAD_BUTTON_A,
        East = glfw.GLFW_GAMEPAD_BUTTON_B,
        West = glfw.GLFW_GAMEPAD_BUTTON_X,
        North = glfw.GLFW_GAMEPAD_BUTTON_Y,
        L1 = glfw.GLFW_GAMEPAD_BUTTON_LEFT_BUMPER,
        R1 = glfw.GLFW_GAMEPAD_BUTTON_RIGHT_BUMPER,
        Back = glfw.GLFW_GAMEPAD_BUTTON_BACK,
        Start = glfw.GLFW_GAMEPAD_BUTTON_START,
        Guide = glfw.GLFW_GAMEPAD_BUTTON_GUIDE,
        L3 = glfw.GLFW_GAMEPAD_BUTTON_LEFT_THUMB,
        R3 = glfw.GLFW_GAMEPAD_BUTTON_RIGHT_THUMB,
        DPadUp = glfw.GLFW_GAMEPAD_BUTTON_DPAD_UP,
        DPadDown = glfw.GLFW_GAMEPAD_BUTTON_DPAD_DOWN,
        DPadLeft = glfw.GLFW_GAMEPAD_BUTTON_DPAD_LEFT,
        DPadRight = glfw.GLFW_GAMEPAD_BUTTON_DPAD_RIGHT,
    };

    pub const Axis = enum(@TypeOf(glfw.GLFW_GAMEPAD_AXIS_LEFT_X)) {
        LeftX = glfw.GLFW_GAMEPAD_AXIS_LEFT_X,
        LeftY = glfw.GLFW_GAMEPAD_AXIS_LEFT_Y,
        RightX = glfw.GLFW_GAMEPAD_AXIS_RIGHT_X,
        RightY = glfw.GLFW_GAMEPAD_AXIS_RIGHT_Y,
        L2 = glfw.GLFW_GAMEPAD_AXIS_LEFT_TRIGGER,
        R2 = glfw.GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER,

        pub fn inverted(self: @This()) bool {
            return switch (self) {
                .LeftY, .RightY => true,
                else => false,
            };
        }
    };

    buttons: std.EnumArray(@This().Button, bool) = std.EnumArray(@This().Button, bool).initFill(false),
    axes: std.EnumArray(@This().Axis, f32) = std.EnumArray(@This().Axis, f32).initFill(0),

    pub fn get(id: ID) ?@This() {
        var glfw_state: glfw.GLFWgamepadstate = undefined;
        if (glfw.glfwGetGamepadState(id, &glfw_state) == glfw.GLFW_FALSE) {
            return null;
        }

        var state: @This() = undefined;

        inline for (@typeInfo(@This().Button).Enum.fields) |button_enum_field_info| {
            const button: @This().Button = @enumFromInt(button_enum_field_info.value);
            state.buttons.set(button, glfw_state.buttons[@intFromEnum(button)] != glfw.GLFW_RELEASE);
        }

        inline for (@typeInfo(@This().Axis).Enum.fields) |axis_enum_field_info| {
            const axis: @This().Axis = @enumFromInt(axis_enum_field_info.value);
            state.axes.set(axis, glfw_state.axes[@intFromEnum(axis)]);
        }

        return state;
    }
};

fn __onJoystick(event_id: c_int, event: c_int) callconv(.C) void {
    switch (event) {
        glfw.GLFW_CONNECTED => {
            context.connection_event_queue.pushBack(.{ .connected = @intCast(event_id) }) catch |e| {
                log.print(.Error, "could not push gamepad connection event to queue: {s}\n", .{@errorName(e)});
            };
        },

        glfw.GLFW_DISCONNECTED => {
            context.connection_event_queue.pushBack(.{ .disconnected = @intCast(event_id) }) catch |e| {
                log.print(.Error, "could not push gamepad connection event to queue: {s}\n", .{@errorName(e)});
            };
        },

        else => {},
    }
}
