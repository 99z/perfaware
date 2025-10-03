const std = @import("std");
const timing = @import("root.zig");

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();

    const ms_to_wait = if (args.next()) |arg|
        std.fmt.parseInt(u32, arg, 10) catch 1000
    else
        1000;

    const os_freq = timing.getOSTimerFreq();
    std.debug.print("\t OS Freq: {}\n", .{os_freq});

    const os_start = try timing.readOSTimer();
    const cpu_start = timing.__rdtsc();

    var os_end: u64 = 0;
    var os_elapsed: u64 = 0;
    const os_wait_time = os_freq * ms_to_wait / 1000;

    while (os_elapsed < os_wait_time) {
        os_end = try timing.readOSTimer();
        os_elapsed = os_end - os_start;
    }

    const cpu_end = timing.__rdtsc();
    const cpu_elapsed = cpu_end - cpu_start;
    const cpu_freq = if (os_elapsed != 0)
        os_freq * (cpu_elapsed / os_elapsed)
    else
        0;

    std.debug.print("\tOS Timer: {} -> {} = {} elapsed\n", .{ os_start, os_end, os_elapsed });
    std.debug.print("OS Seconds: {}\n", .{@divFloor(os_elapsed, os_freq)});

    std.debug.print("CPU Timer: {} -> {} = {} elapsed\n", .{ cpu_start, cpu_end, cpu_elapsed });
    std.debug.print("\tCPU Freq: {} (guessed)\n", .{cpu_freq});
}
