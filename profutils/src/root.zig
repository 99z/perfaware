const std = @import("std");
const timing = @import("rdtsc.zig");

var buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const alloc = fba.allocator();

var profiling_enabled: bool = false;
var profile_records: std.ArrayList(ProfileRecord) = .{};

var total_execution_time: u64 = 0;

pub const ProfileRecord = struct {
    name: []const u8,
    start: u64,
    end: u64,
    duration: u64,
};

pub fn beginProfiling() void {
    profiling_enabled = true;
}

pub fn endProfiling() void {
    profiling_enabled = false;
}

const ProfileScope = struct {
    name: []const u8,
    start: u64,

    pub fn startProfiling(name: []const u8) ProfileScope {
        return .{
            .name = name,
            .start = if (profiling_enabled) timing.__rdtsc() else 0,
        };
    }

    pub fn stopProfiling(self: *ProfileScope) void {
        if (!profiling_enabled) return;

        const end_time = timing.__rdtsc();
        const elapsed = end_time - self.start;

        total_execution_time += elapsed;

        profile_records.append(alloc, .{
            .name = self.name,
            .start = self.start,
            .end = end_time,
            .duration = elapsed,
        }) catch {
            std.log.warn("profile buffer full; dropping entry for {s}", .{self.name});
        };
    }
};

pub fn timeFunction(name: []const u8) ProfileScope {
    return ProfileScope.startProfiling(name);
}

pub fn getProfileRecords() []const ProfileRecord {
    return profile_records.items;
}

pub fn getTotalExecutionTime() u64 {
    return total_execution_time;
}

pub fn clearProfileRecords() void {
    profile_records.clearRetainingCapacity();
}

pub fn deinitProfileRecords() void {
    profile_records.deinit(alloc);
}
