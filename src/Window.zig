const std = @import("std");
const glfw = @import("glfw");
const log = @import("log.zig");
const DynArr = @import("DynArr.zig").DynArr;
const utf = @import("utf.zig");

const toplevel = @This();

pub const Window = struct {

    pub const context = struct {

        pub fn init() !void {

            const version: @Vector(3, c_int) = blk: {
                var x: @Vector(3, c_int) = undefined;
                glfw.glfwGetVersion(&x[0], &x[1], &x[2]);
                break :blk x;
            };
            log.print(.Info, "initializing glfw\n\tversion: {}.{}.{}\n", .{ version[0], version[1], version[2] });

            const ret_code = glfw.glfwInit();
            if (ret_code != glfw.GLFW_TRUE) {
                var glfw_error_description_buffer: [2048]u8 = undefined;
                var glfw_error_description_ptr: [*c]u8 = @ptrCast(&glfw_error_description_buffer);
                const glfw_error_number = glfw.glfwGetError(&glfw_error_description_ptr);
                log.print(.Error, "glfw error {}: {s}\n", .{ glfw_error_number, glfw_error_description_ptr });
                return error.GLFWInitFailed;
            }

        }

        pub fn terminate() void {
            glfw.glfwTerminate();
        }

        pub fn pollEvents() void {
            glfw.glfwPollEvents();
        }

        pub const getProcAddress = glfw.glfwGetProcAddress;

    };

    handle: *glfw.GLFWwindow = undefined,

    size:       @Vector(2, u32) = @splat(0),
    cursor_pos: @Vector(2, f32) = @splat(0),

    event_queue: DynArr(Event, .{
        .auto_shrink_capacity = false,
    }) = .{},

    pub fn initAlloc(self: *@This(), allocator: std.mem.Allocator, title: [:0]const u8, size: @Vector(2, u32)) !void {

        glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glfw.GLFW_TRUE);
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4);
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 5);
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

        const handle = glfw.glfwCreateWindow(@intCast(size[0]), @intCast(size[1]), title, null, null)
            orelse return error.GLFWCreateWindowFailed;

        self.handle   = handle;
        self.size     = size;

        try self.event_queue.init(allocator);

        if (glfw.glfwRawMouseMotionSupported() == glfw.GLFW_TRUE) {
            glfw.glfwSetInputMode(self.handle, glfw.GLFW_RAW_MOUSE_MOTION, glfw.GLFW_TRUE);
        } else {
            log.print(.Warning, "raw mouse motion not supported\n", .{});
        }

        _ = glfw.glfwSetWindowUserPointer(handle, self);
        _ = glfw.glfwSetWindowSizeCallback(handle, __onResize);
        _ = glfw.glfwSetKeyCallback(handle, __onKeyboard);
        _ = glfw.glfwSetCharCallback(handle, __onChar);
        _ = glfw.glfwSetCursorPosCallback(handle, __onCursorMove);
        _ = glfw.glfwSetMouseButtonCallback(handle, __onCursorButton);
        _ = glfw.glfwSetScrollCallback(handle, __onScroll);
        _ = glfw.glfwSetWindowFocusCallback(handle, __onFocus);
        _ = glfw.glfwSetWindowCloseCallback(handle, __onTerminationRequest);

    }

    pub fn free(self: *const @This()) void {
        glfw.glfwDestroyWindow(self.handle);
        self.event_queue.free();
    }

    pub fn getEvent(self: *@This()) ?Event {
        const event = self.event_queue.popFront();
        if (event == null) {
            self.event_queue.clear();
        }
        return event;
    }

    pub fn terminationRequested(self: *const @This()) bool {
        return glfw.glfwWindowShouldClose(self.handle) != 0;
    }

    pub fn makeContextCurrent(self: *const @This()) void {
        glfw.glfwMakeContextCurrent(self.handle);
    }

    pub fn swapBuffers(self: *const @This()) void {
        glfw.glfwSwapBuffers(self.handle);
    }

};

pub const Event = union(enum) {
    resize:         @Vector(2, u32),
    key:            struct {
        key: Key,
        down: bool,
        repeat: bool,
    },
    char:           utf.Codepoint,
    cursor_move:    @Vector(2, f32),
    cursor_button: struct {
        button: CursorButton,
        down: bool,
    },
    scroll:         @Vector(2, f32),
    focus:          bool,
    termination_request: void,
};

pub const Key = enum(@TypeOf(glfw.GLFW_KEY_UNKNOWN)) {

    Unknown      = glfw.GLFW_KEY_UNKNOWN,
    Space        = glfw.GLFW_KEY_SPACE,
    Apostrophe   = glfw.GLFW_KEY_APOSTROPHE,
    Comma        = glfw.GLFW_KEY_COMMA,
    Minus        = glfw.GLFW_KEY_MINUS,
    Period       = glfw.GLFW_KEY_PERIOD,
    Slash        = glfw.GLFW_KEY_SLASH,
    Number0      = glfw.GLFW_KEY_0,
    Number1      = glfw.GLFW_KEY_1,
    Number2      = glfw.GLFW_KEY_2,
    Number3      = glfw.GLFW_KEY_3,
    Number4      = glfw.GLFW_KEY_4,
    Number5      = glfw.GLFW_KEY_5,
    Number6      = glfw.GLFW_KEY_6,
    Number7      = glfw.GLFW_KEY_7,
    Number8      = glfw.GLFW_KEY_8,
    Number9      = glfw.GLFW_KEY_9,
    Semicolon    = glfw.GLFW_KEY_SEMICOLON,
    Equal        = glfw.GLFW_KEY_EQUAL,
    A            = glfw.GLFW_KEY_A,
    B            = glfw.GLFW_KEY_B,
    C            = glfw.GLFW_KEY_C,
    D            = glfw.GLFW_KEY_D,
    E            = glfw.GLFW_KEY_E,
    F            = glfw.GLFW_KEY_F,
    G            = glfw.GLFW_KEY_G,
    H            = glfw.GLFW_KEY_H,
    I            = glfw.GLFW_KEY_I,
    J            = glfw.GLFW_KEY_J,
    K            = glfw.GLFW_KEY_K,
    L            = glfw.GLFW_KEY_L,
    M            = glfw.GLFW_KEY_M,
    N            = glfw.GLFW_KEY_N,
    O            = glfw.GLFW_KEY_O,
    P            = glfw.GLFW_KEY_P,
    Q            = glfw.GLFW_KEY_Q,
    R            = glfw.GLFW_KEY_R,
    S            = glfw.GLFW_KEY_S,
    T            = glfw.GLFW_KEY_T,
    U            = glfw.GLFW_KEY_U,
    V            = glfw.GLFW_KEY_V,
    W            = glfw.GLFW_KEY_W,
    X            = glfw.GLFW_KEY_X,
    Y            = glfw.GLFW_KEY_Y,
    Z            = glfw.GLFW_KEY_Z,
    LeftBracket  = glfw.GLFW_KEY_LEFT_BRACKET,
    Backslash    = glfw.GLFW_KEY_BACKSLASH,
    RightBracket = glfw.GLFW_KEY_RIGHT_BRACKET,
    GraveAccent  = glfw.GLFW_KEY_GRAVE_ACCENT,
    World1       = glfw.GLFW_KEY_WORLD_1,
    World2       = glfw.GLFW_KEY_WORLD_2,
    Escape       = glfw.GLFW_KEY_ESCAPE,
    Enter        = glfw.GLFW_KEY_ENTER,
    Tab          = glfw.GLFW_KEY_TAB,
    Backspace    = glfw.GLFW_KEY_BACKSPACE,
    Insert       = glfw.GLFW_KEY_INSERT,
    Delete       = glfw.GLFW_KEY_DELETE,
    Right        = glfw.GLFW_KEY_RIGHT,
    Left         = glfw.GLFW_KEY_LEFT,
    Down         = glfw.GLFW_KEY_DOWN,
    Up           = glfw.GLFW_KEY_UP,
    PageUp       = glfw.GLFW_KEY_PAGE_UP,
    PageDown     = glfw.GLFW_KEY_PAGE_DOWN,
    Home         = glfw.GLFW_KEY_HOME,
    End          = glfw.GLFW_KEY_END,
    CapsLock     = glfw.GLFW_KEY_CAPS_LOCK,
    ScrollLock   = glfw.GLFW_KEY_SCROLL_LOCK,
    NumLock      = glfw.GLFW_KEY_NUM_LOCK,
    PrintScreen  = glfw.GLFW_KEY_PRINT_SCREEN,
    Pause        = glfw.GLFW_KEY_PAUSE,
    F1           = glfw.GLFW_KEY_F1,
    F2           = glfw.GLFW_KEY_F2,
    F3           = glfw.GLFW_KEY_F3,
    F4           = glfw.GLFW_KEY_F4,
    F5           = glfw.GLFW_KEY_F5,
    F6           = glfw.GLFW_KEY_F6,
    F7           = glfw.GLFW_KEY_F7,
    F8           = glfw.GLFW_KEY_F8,
    F9           = glfw.GLFW_KEY_F9,
    F10          = glfw.GLFW_KEY_F10,
    F11          = glfw.GLFW_KEY_F11,
    F12          = glfw.GLFW_KEY_F12,
    F13          = glfw.GLFW_KEY_F13,
    F14          = glfw.GLFW_KEY_F14,
    F15          = glfw.GLFW_KEY_F15,
    F16          = glfw.GLFW_KEY_F16,
    F17          = glfw.GLFW_KEY_F17,
    F18          = glfw.GLFW_KEY_F18,
    F19          = glfw.GLFW_KEY_F19,
    F20          = glfw.GLFW_KEY_F20,
    F21          = glfw.GLFW_KEY_F21,
    F22          = glfw.GLFW_KEY_F22,
    F23          = glfw.GLFW_KEY_F23,
    F24          = glfw.GLFW_KEY_F24,
    F25          = glfw.GLFW_KEY_F25,
    Kp0          = glfw.GLFW_KEY_KP_0,
    Kp1          = glfw.GLFW_KEY_KP_1,
    Kp2          = glfw.GLFW_KEY_KP_2,
    Kp3          = glfw.GLFW_KEY_KP_3,
    Kp4          = glfw.GLFW_KEY_KP_4,
    Kp5          = glfw.GLFW_KEY_KP_5,
    Kp6          = glfw.GLFW_KEY_KP_6,
    Kp7          = glfw.GLFW_KEY_KP_7,
    Kp8          = glfw.GLFW_KEY_KP_8,
    Kp9          = glfw.GLFW_KEY_KP_9,
    KpDecimal    = glfw.GLFW_KEY_KP_DECIMAL,
    KpDivide     = glfw.GLFW_KEY_KP_DIVIDE,
    KpMultiply   = glfw.GLFW_KEY_KP_MULTIPLY,
    KpSubtract   = glfw.GLFW_KEY_KP_SUBTRACT,
    KpAdd        = glfw.GLFW_KEY_KP_ADD,
    KpEnter      = glfw.GLFW_KEY_KP_ENTER,
    KpEqual      = glfw.GLFW_KEY_KP_EQUAL,
    LeftShift    = glfw.GLFW_KEY_LEFT_SHIFT,
    LeftControl  = glfw.GLFW_KEY_LEFT_CONTROL,
    LeftAlt      = glfw.GLFW_KEY_LEFT_ALT,
    LeftSuper    = glfw.GLFW_KEY_LEFT_SUPER,
    RightShift   = glfw.GLFW_KEY_RIGHT_SHIFT,
    RightControl = glfw.GLFW_KEY_RIGHT_CONTROL,
    RightAlt     = glfw.GLFW_KEY_RIGHT_ALT,
    RightSuper   = glfw.GLFW_KEY_RIGHT_SUPER,
    Menu         = glfw.GLFW_KEY_MENU,

};

pub const CursorButton = enum(@TypeOf(glfw.GLFW_MOUSE_BUTTON_LEFT)) {

    Left   = glfw.GLFW_MOUSE_BUTTON_LEFT,
    Right  = glfw.GLFW_MOUSE_BUTTON_RIGHT,
    Middle = glfw.GLFW_MOUSE_BUTTON_MIDDLE,

    Button4 = glfw.GLFW_MOUSE_BUTTON_4,
    Button5 = glfw.GLFW_MOUSE_BUTTON_5,
    Button6 = glfw.GLFW_MOUSE_BUTTON_6,
    Button7 = glfw.GLFW_MOUSE_BUTTON_7,
    Button8 = glfw.GLFW_MOUSE_BUTTON_8,

};

fn __onResize(handle: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {

    var window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(handle)));

    window.size[0] = @intCast(width);
    window.size[1] = @intCast(height);

    window.event_queue.pushBack(.{
        .resize = window.size,
    }) catch | e | { log.print(.Error, "could not push to window's event queue on resize event: {s}\n", .{ @errorName(e) }); };

}

fn __onKeyboard(handle: ?*glfw.GLFWwindow, glfw_key: c_int, _: c_int, action: c_int, _: c_int) callconv(.C) void {

    var window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(handle)));

    const repeat = action == glfw.GLFW_REPEAT;
    const down = action == glfw.GLFW_PRESS or repeat;
    const key: Key = @enumFromInt(glfw_key);

    window.event_queue.pushBack(.{
        .key = .{
            .key = key,
            .down = down,
            .repeat = repeat, 
    } }) catch | e | { log.print(.Error, "could not push to window's event queue on key event: {s}\n", .{ @errorName(e) }); };

}

fn __onChar(handle: ?*glfw.GLFWwindow, glfw_char: c_uint) callconv(.C) void {

    var window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(handle)));

    const codepoint: utf.Codepoint = @intCast(glfw_char);

    window.event_queue.pushBack(.{
        .char = codepoint,
    }) catch | e | { log.print(.Error, "could not push to window's event queue on char event: {s}\n", .{ @errorName(e) }); };

}

fn __onCursorMove(handle: ?*glfw.GLFWwindow, x: f64, y: f64) callconv(.C) void {

    var window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(handle)));

    window.cursor_pos[0] = @floatCast(x);
    window.cursor_pos[1] = @floatCast(y);

    window.event_queue.pushBack(.{
        .cursor_move = window.cursor_pos,
    }) catch | e | { log.print(.Error, "could not push to window's event queue on cursor move event: {s}\n", .{ @errorName(e) }); };

}

fn __onCursorButton(handle: ?*glfw.GLFWwindow, glfw_button: c_int, action: c_int, _: c_int) callconv(.C) void {

    var window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(handle)));

    const button: CursorButton = @enumFromInt(glfw_button);
    const down = action == glfw.GLFW_PRESS;

    window.event_queue.pushBack(.{
        .cursor_button = .{
            .button = button,
            .down = down,
        }
    }) catch | e | { log.print(.Error, "could not push to window's event queue on cursor button event: {s}\n", .{ @errorName(e) }); };

}

fn __onScroll(handle: ?*glfw.GLFWwindow, x: f64, y: f64) callconv(.C) void {

    var window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(handle)));

    const scroll: @Vector(2, f32) = .{ @floatCast(x), @floatCast(y) };

    window.event_queue.pushBack(.{
        .scroll = scroll,
    }) catch | e | { log.print(.Error, "could not push to window's event queue on scroll event: {s}\n", .{ @errorName(e) }); };

}

fn __onFocus(handle: ?*glfw.GLFWwindow, focused_int: c_int) callconv(.C) void {

    var window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(handle)));

    const focused = focused_int != 0;

    window.event_queue.pushBack(.{
        .focus = focused,
    }) catch | e | { log.print(.Error, "could not push to window's event queue on focus event: {s}\n", .{ @errorName(e) }); };

}

fn __onTerminationRequest(handle: ?*glfw.GLFWwindow) callconv(.C) void {

    var window: *Window = @ptrCast(@alignCast(glfw.glfwGetWindowUserPointer(handle)));

    window.event_queue.pushBack(.{
        .termination_request = {},
    }) catch | e | { log.print(.Error, "could not push to window's event queue on termination request event: {s}\n", .{ @errorName(e) }); };

}