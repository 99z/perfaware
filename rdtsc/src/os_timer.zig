const std = @import("std");
const timing = @import("root.zig");

pub fn main() !void {
    const os_freq = timing.getOSTimerFreq();
    std.debug.print("\t OS Freq: {}\n", .{os_freq});

    const os_start = try timing.readOSTimer();
    var os_end: isize = 0;
    var os_elapsed: isize = 0;

    while (os_elapsed < os_freq) {
        os_end = try timing.readOSTimer();
        os_elapsed = os_end - os_start;
    }

    std.debug.print("\tOS Timer: {} -> {} = {} elapsed\n", .{ os_start, os_end, os_elapsed });
    std.debug.print("OS Seconds: {}\n", .{@divFloor(os_elapsed, os_freq)});
}
