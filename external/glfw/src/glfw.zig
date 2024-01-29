pub const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const Version = struct {

    major: u32,
    minor: u32,
    patch: u32,

};

pub fn version() Version {

    var major: c_int = undefined;
    var minor: c_int = undefined;
    var patch: c_int = undefined;

    c.glfwGetVersion(&major, &minor, &patch);

    return .{
        .major = @intCast(major),
        .minor = @intCast(minor),
        .patch = @intCast(patch),
    };

}