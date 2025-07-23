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

fn square(a: f32) f32 {
    return a * a;
}

fn radiansFromDegrees(degrees: f32) f32 {
    return 0.01745329251994329577 * degrees;
}

fn unitIntervalToLat(coord: f32) f32 {
    return -90 + coord * 180;
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

fn generatePairs(rand: std.Random) HaversinePair {
    const x0 = unitIntervalToLong(rand.float(f32));
    const x1 = unitIntervalToLong(rand.float(f32));
    const y0 = unitIntervalToLat(rand.float(f32));
    const y1 = unitIntervalToLat(rand.float(f32));

    const p1: Point = .{ .x = x0, .y = y0 };
    const p2: Point = .{ .x = x1, .y = y1 };

    const haversine_pair: HaversinePair = .{ .x0 = p1.x, .y0 = p1.y, .x1 = p2.x, .y1 = p2.y };

    return haversine_pair;
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
// TODO file write approach
pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();

    const num_points_arg = args.next() orelse {
        std.debug.print("usage: havergen <num_points> <seed?>\n", .{});
        return error.NoNumPoints;
    };
    const num_points = try std.fmt.parseInt(usize, num_points_arg, 10);

    const seed_arg = args.next() orelse &.{};
    var seed: usize = undefined;

    if (seed_arg.len != 0) {
        seed = std.fmt.parseInt(usize, seed_arg, 10) catch {
            std.debug.print("seed must be an integer\n", .{});
            return error.BadSeed;
        };
    }

    var prng = std.Random.DefaultPrng.init(blk: {
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    const stdout_file = std.io.getStdOut().writer();
    const stderr_file = std.io.getStdErr().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    var bw_err = std.io.bufferedWriter(stderr_file);

    const stdout = bw.writer();
    const stderr = bw_err.writer();

    var sum: f32 = 0;

    try stdout.print("[\"points\": ", .{});
    for (0..num_points) |i| {
        const pair = generatePairs(rand);
        const distance = referenceHaversine(pair.x0, pair.y0, pair.x1, pair.y1, EARTH_RADIUS);
        sum += distance;

        try std.json.stringify(pair, .{ .whitespace = .minified }, stdout);
        if (i != num_points - 1) try stdout.print(",", .{});
    }
    try stdout.print("]", .{});

    const num_points_float: f32 = @floatFromInt(num_points);
    try stderr.print("\nAverage: {d}\n", .{sum / num_points_float});
    try bw.flush();
    try bw_err.flush();
}
