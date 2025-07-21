const std = @import("std");

const Point = struct {
    x: f32,
    y: f32,
};

const HaversinePair = struct {
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    distance: f32,
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
// file write approach:
//   - ./zig-out/bin/havergen  6.61s user 1.09s system 98% cpu 7.791 total
pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const points_file = try std.fs.cwd().createFile("points.json", .{});
    defer points_file.close();
    var points_file_bw = std.io.bufferedWriter(points_file.writer());
    var points_bw = points_file_bw.writer();

    const num_points = 10_000_000;
    var sum: f32 = 0;

    for (0..num_points) |_| {
        var prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();
        const x0 = unitIntervalToLong(rand.float(f32));
        const x1 = unitIntervalToLong(rand.float(f32));
        const y0 = unitIntervalToLat(rand.float(f32));
        const y1 = unitIntervalToLat(rand.float(f32));

        const p1: Point = .{ .x = x0, .y = y0 };
        const p2: Point = .{ .x = x1, .y = y1 };

        const distance = referenceHaversine(p1.x, p1.y, p2.x, p2.y, EARTH_RADIUS);
        sum += distance;

        const haversine_pair: HaversinePair = .{ .x1 = p1.x, .y1 = p1.y, .x2 = p2.x, .y2 = p2.y, .distance = distance };

        try std.json.stringify(haversine_pair, .{ .whitespace = .indent_tab }, points_bw);
        _ = try points_bw.write(",\n");
    }

    try stdout.print("Average: {d}\n", .{sum / num_points});
    try bw.flush();
    try points_file_bw.flush();
}
