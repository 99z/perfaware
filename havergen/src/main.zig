const std = @import("std");

const Point = struct {
    x: f32,
    y: f32,
};

const HaversinePair = struct {
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
};

const EARTH_RADIUS = 6372.8;
const NUM_CLUSTERS = 32;

fn square(a: f32) f32 {
    return a * a;
}

fn radiansFromDegrees(degrees: f32) f32 {
    return 0.01745329251994329577 * degrees;
}

fn unitIntervalToLat(coord: f32) f32 {
    return -90 + coord * 180;
}

fn generateClusteredPairs(rand: std.Random, num_points: usize, stdout: anytype) !f32 {
    const points_per_cluster = num_points / NUM_CLUSTERS;
    var sum: f32 = 0;

    // Generate cluster centers distributed across the globe
    var cluster_centers: [NUM_CLUSTERS]struct { long: f32, lat: f32 } = undefined;
    for (0..NUM_CLUSTERS) |i| {
        cluster_centers[i] = .{
            .long = unitIntervalToLong(rand.float(f32)),
            .lat = unitIntervalToLat(rand.float(f32)),
        };
    }

    for (0..NUM_CLUSTERS * points_per_cluster) |i| {
        const cluster_index = i / points_per_cluster;
        const center = cluster_centers[cluster_index];
        
        // Generate points within 20 degrees longitude and 10 degrees latitude of cluster center
        const x0 = center.long + (-20 + rand.float(f32) * 40);
        const x1 = center.long + (-20 + rand.float(f32) * 40);
        const y0 = center.lat + (-10 + rand.float(f32) * 20);
        const y1 = center.lat + (-10 + rand.float(f32) * 20);

        const haversine_pair: HaversinePair = .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 };

        const distance = referenceHaversine(haversine_pair.x0, haversine_pair.y0, haversine_pair.x1, haversine_pair.y1, EARTH_RADIUS);
        sum += distance;

        try std.json.Stringify.value(haversine_pair, .{ .whitespace = .minified }, stdout);
        if (i != num_points - 1) try stdout.print(",", .{});
    }

    return sum;
}

fn unitIntervalToLong(coord: f32) f32 {
    return -180 + coord * 360;
}

fn referenceHaversine(x0: f32, y0: f32, x1: f32, y1: f32, earth_radius: f32) f32 {
    var lat1 = y0;
    var lat2 = y1;
    const long1 = x0;
    const long2 = x1;

    const d_lat = radiansFromDegrees(lat2 - lat1);
    const d_lon = radiansFromDegrees(long2 - long1);
    lat1 = radiansFromDegrees(lat1);
    lat2 = radiansFromDegrees(lat2);

    const a = square(@sin(d_lat / 2.0)) + @cos(lat1) * @cos(lat2) * square(@sin(d_lon / 2));
    const c = 2.0 * std.math.asin(@sqrt(a));

    return earth_radius * c;
}

fn generatePairs(rand: std.Random, num_points: usize, stdout: anytype) !f32 {
    var sum: f32 = 0;

    for (0..num_points) |i| {
        const x0 = unitIntervalToLong(rand.float(f32));
        const x1 = unitIntervalToLong(rand.float(f32));
        const y0 = unitIntervalToLat(rand.float(f32));
        const y1 = unitIntervalToLat(rand.float(f32));

        const p1: Point = .{ .x = x0, .y = y0 };
        const p2: Point = .{ .x = x1, .y = y1 };

        const haversine_pair: HaversinePair = .{ .x0 = p1.x, .y0 = p1.y, .x1 = p2.x, .y1 = p2.y };

        const distance = referenceHaversine(haversine_pair.x0, haversine_pair.y0, haversine_pair.x1, haversine_pair.y1, EARTH_RADIUS);
        sum += distance;

        try std.json.Stringify.value(haversine_pair, .{ .whitespace = .minified }, stdout);
        if (i != num_points - 1) try stdout.print(",", .{});
    }

    return sum;
}

// Writes points to stdout, diagnostic data to stderr
// Use `havergen >points.json` to write to file but preserve
// stderr output
// I actually learned stderr is "for writing diagnostic output"
// https://pubs.opengroup.org/onlinepubs/9699919799/functions/stderr.html
// Helpful table of how to write to stdout/stderr and terminal output:
// https://unix.stackexchange.com/a/616754
//
// stdout approach:
//   - ./zig-out/bin/havergen > points.json  6.53s user 0.92s system 98% cpu 7.530 total
// file write approach: didn't see performance gain
pub fn main() !void {
    if (std.os.argv.len < 3) {
        std.debug.print("Usage: havergen <clustered|uniform> <num_points> <seed?>", .{});
        return error.InvalidArgLength;
    }

    const cluster_type = std.mem.span(std.os.argv[1]);
    const num_points_arg = std.mem.span(std.os.argv[2]);

    const num_points = std.fmt.parseInt(usize, num_points_arg, 10) catch {
        std.debug.print("Error: Invalid number format: {s}\n", .{num_points_arg});
        return error.BadNumPointsArg;
    };

    var seed: ?usize = null;
    if (std.os.argv.len == 4) {
        const seed_arg = std.mem.span(std.os.argv[3]);
        seed = std.fmt.parseInt(usize, seed_arg, 10) catch {
            std.debug.print("Error: Invalid seed format: {s}\n", .{seed_arg});
            return error.BadSeedArg;
        };
    }

    if (seed != null) {
        std.debug.print("seed: {?d}\n", .{seed});
    }

    var prng = std.Random.DefaultPrng.init(blk: {
        if (seed == null) try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed orelse undefined;
    });
    const rand = prng.random();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    try stdout.print("{{\"points\": [", .{});

    var sum: f32 = 0;
    if (std.mem.eql(u8, cluster_type, "clustered")) {
        sum = try generateClusteredPairs(rand, num_points, stdout);
    } else {
        sum = try generatePairs(rand, num_points, stdout);
    }

    try stdout.print("]}}", .{});

    const num_points_float: f32 = @floatFromInt(num_points);
    try stderr.print("\nAverage: {d}\n", .{sum / num_points_float});

    try stdout.flush();
    try stderr.flush();
}
