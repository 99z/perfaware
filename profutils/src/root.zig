const std = @import("std");
const timing = @import("rdtsc.zig");

var profiling_enabled: bool = false;

// Index 0 is reserved for the implicit root scope.
var used: usize = 1;
const Profiler = struct {
    records: [4096]ProfileRecord,
    start_tsc: usize,
    end_tsc: usize,
};

var Global_Profiler = std.mem.zeroInit(Profiler, .{});
var Global_Profiler_Parent: usize = 0;

pub const ProfileRecord = struct {
    name: []const u8,
    duration: usize,
    duration_children: usize,
    hit_count: usize,
};

pub fn beginProfiling() void {
    profiling_enabled = true;
    used = 1;
    Global_Profiler_Parent = 0;
    Global_Profiler = std.mem.zeroInit(Profiler, .{});
    Global_Profiler.start_tsc = timing.__rdtsc();
}

pub fn endProfiling() void {
    profiling_enabled = false;

    Global_Profiler.end_tsc = timing.__rdtsc();
    const total_elapsed = Global_Profiler.end_tsc - Global_Profiler.start_tsc;

    for (Global_Profiler.records) |r| {
        if (r.duration != 0) {
            printTimeElapsed(total_elapsed, r);
        }
    }
}

fn printTimeElapsed(total_elapsed: usize, record: ProfileRecord) void {
    const elapsed = record.duration - record.duration_children;
    const percent = 100.0 * (@as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(total_elapsed)));
    std.debug.print("{s}[{}]: {} ({d:.2}%", .{ record.name, record.hit_count, elapsed, percent });

    if (record.duration_children != 0) {
        const percent_with_children = 100.0 * (@as(f64, @floatFromInt(record.duration)) / @as(f64, @floatFromInt(total_elapsed)));
        std.debug.print(", {d:.2}% w/ children", .{percent_with_children});
    }

    std.debug.print(")\n", .{});
}

const ProfileScope = struct {
    name: []const u8,
    start: usize,
    parent_idx: usize,
    record_idx: usize,

    fn init(name: []const u8, record_idx: usize) ProfileScope {
        return .{ .name = name, .start = timing.__rdtsc(), .parent_idx = Global_Profiler_Parent, .record_idx = record_idx };
    }

    pub fn stopProfiling(self: *ProfileScope) void {
        if (!profiling_enabled) return;

        // OOB guard
        if (self.record_idx >= Global_Profiler.records.len) return;

        const elapsed = timing.__rdtsc() - self.start;
        Global_Profiler_Parent = self.parent_idx;

        const parent = &Global_Profiler.records[self.parent_idx];
        parent.duration_children += elapsed;

        const record = &Global_Profiler.records[self.record_idx];
        record.duration += elapsed;
        record.hit_count += 1;
        record.name = self.name;
    }
};

fn getOrCreateRecord(name: []const u8) usize {
    // Reuse an existing slot for the same function name to keep recursion bounded.
    var i: usize = 1;
    while (i < used) : (i += 1) {
        if (std.mem.eql(u8, Global_Profiler.records[i].name, name)) {
            return i;
        }
    }

    if (used >= Global_Profiler.records.len) return Global_Profiler.records.len;

    const idx = used;
    used += 1;
    Global_Profiler.records[idx].name = name;
    return idx;
}

pub fn timeFunction(comptime name: []const u8) ProfileScope {
    const idx = getOrCreateRecord(name);
    if (idx >= Global_Profiler.records.len) {
        return ProfileScope.init(name, idx);
    }
    const scope = ProfileScope.init(name, idx);
    Global_Profiler_Parent = scope.record_idx;
    return scope;
}
