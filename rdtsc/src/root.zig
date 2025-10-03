const std = @import("std");

pub inline fn __rdtsc() u64 {
    var hi: u64 = 0;
    var low: u64 = 0;

    asm volatile (
        \\rdtsc
        : [low] "={eax}" (low),
          [hi] "={edx}" (hi),
    );

    return (@as(u64, hi) << 32) | @as(u64, low);
}

pub fn getOSTimerFreq() u64 {
    return 1000000;
}

pub fn readOSTimer() !u64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch |err| switch (err) {
        error.UnsupportedClock, error.Unexpected => return 0,
    };

    // sec/nsec are isize, but since we call clock_gettime with .REALTIME
    // these will always be positive
    const sec: u64 = @intCast(ts.sec);
    const nsec: u64 = @intCast(ts.nsec);
    const result = getOSTimerFreq() * sec + @divFloor(nsec, 1000);

    return result;
}

pub fn estimateCPUTimerFreq() !u64 {
    const ms_to_wait = 100;

    const os_freq = getOSTimerFreq();
    std.debug.print("\t OS Freq: {}\n", .{os_freq});

    const os_start = try readOSTimer();
    const cpu_start = __rdtsc();

    var os_end: u64 = 0;
    var os_elapsed: u64 = 0;
    const os_wait_time = os_freq * ms_to_wait / 1000;

    while (os_elapsed < os_wait_time) {
        os_end = try readOSTimer();
        os_elapsed = os_end - os_start;
    }

    const cpu_end = __rdtsc();
    const cpu_elapsed = cpu_end - cpu_start;
    const cpu_freq = if (os_elapsed != 0)
        os_freq * (cpu_elapsed / os_elapsed)
    else
        0;

    return cpu_freq;
}
