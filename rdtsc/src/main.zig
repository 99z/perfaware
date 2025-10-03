const std = @import("std");
const timing = @import("timing");

pub fn main() !void {
    const result = timing.__rdtsc();
    std.debug.print("rdtsc: {}\n", .{result});

    const os_timer = try timing.readOSTimer();
    std.debug.print("os timer: {}\n", .{os_timer});

    const cpu_freq = try timing.estimateCPUTimerFreq();
    std.debug.print("cpu freq: {}\n", .{cpu_freq});
}
