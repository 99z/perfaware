const std = @import("std");
const sim86 = @import("sim86.zig");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("sim86 version: {}\n", .{sim86.getVersion()});
}
