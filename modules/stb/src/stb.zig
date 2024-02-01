pub const config = @import("config");

pub const image = if (config.stb_image) @cImport({
    @cInclude("stb_image.h");
}) else @compileError("implementation not built, use 'zig build --help' for appropriate option");

pub const truetype = if (config.stb_truetype) @cImport({
    @cInclude("stb_truetype.h");
}) else @compileError("implementation not built, use 'zig build --help' for appropriate option");