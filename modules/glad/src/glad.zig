const std = @import("std");
const glad = @cImport({
    @cInclude("glad.h");
});
pub usingnamespace glad;

pub fn load(getProcAddress: *const fn([*c]const u8) callconv(.C) ?*const fn() callconv(.C) void) void {
    _ = glad.gladLoadGL(getProcAddress);
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
