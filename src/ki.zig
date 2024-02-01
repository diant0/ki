pub const glfw = @import("glfw");
pub const stb = @import("stb");

pub const Version = struct {

    major: u32,
    minor: u32,
    patch: u32,

};

pub fn version() Version {

    return .{
        .major = 0,
        .minor = 0,
        .patch = 0,
    };

}