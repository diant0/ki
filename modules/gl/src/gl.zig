const glad = @cImport({
    @cInclude("glad.h");
});

pub usingnamespace glad;

pub inline fn load(getProcAddress: *const fn(name: [*c]const u8) callconv(.C) ?*const fn() callconv(.C) void) !void {
    _ = glad.gladLoadGL(getProcAddress);
}