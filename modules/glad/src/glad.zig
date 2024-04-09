const std = @import("std");
const glad = @cImport({
    @cInclude("glad.h");
});
pub usingnamespace glad;

pub fn load(getProcAddress: *const fn([*c]const u8) callconv(.C) ?*const fn() callconv(.C) void) void {
    _ = glad.gladLoadGL(getProcAddress);
}

pub fn clear(clear_info: struct { col: ?@Vector(4, f32) = null, depth: ?f64 = null }) void {
    var bitfield: glad.GLbitfield = 0;
    if (clear_info.col) | col | {
        bitfield |= glad.GL_COLOR_BUFFER_BIT;
        glad.glClearColor(col[0], col[1], col[2], col[3]);
    }
    if (clear_info.depth) | depth | {
        bitfield |= glad.GL_DEPTH_BUFFER_BIT;
        glad.glClearDepth(depth);
    }
    glad.glClear(bitfield);
}

pub fn __enableDebugOutput() void {

    const printMsg = struct {

        fn f(src: glad.GLenum, typ: glad.GLenum, id: glad.GLenum, sev: glad.GLenum, len: glad.GLsizei,
            message: [*c]const u8, param: ?*const anyopaque) callconv (.C) void {

            _ = param;
            _ = len;
            _ = id;
            _ = typ;
            _ = src;

            const sev_str: [*:0]const u8 = switch (sev) {

                glad.GL_DEBUG_SEVERITY_NOTIFICATION    => "Notification",
                glad.GL_DEBUG_SEVERITY_LOW             => "Low Severity",
                glad.GL_DEBUG_SEVERITY_MEDIUM          => "Medium Severity",
                glad.GL_DEBUG_SEVERITY_HIGH            => "High Severity",
                else => "Unknown Severity",

            };

            std.debug.print("[GL Debug : {s}] {s}\n", .{ sev_str, message });
        
        }

    }.f;

    glad.glDebugMessageCallback(printMsg, null);
    glad.glEnable(glad.GL_DEBUG_OUTPUT);

}
