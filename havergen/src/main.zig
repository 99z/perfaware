const std = @import("std");

const Point = struct {
    x: f64,
    y: f64,
};

const EARTH_RADIUS = 6372.8;

fn square(a: f64) f64 {
    return a * a;
}

fn radiansFromDegrees(degrees: f64) f64 {
    return 0.01745329251994329577 * degrees;
}

fn unitIntervalToLat(coord: f64) f64 {
    return -90 + coord * 180;
}

fn unitIntervalToLong(coord: f64) f64 {
    return -180 + coord * 360;
}

fn referenceHaversine(x0: f64, y0: f64, x1: f64, y1: f64, earth_radius: f64) f64 {
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

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    const x0 = unitIntervalToLong(rand.float(f64));
    const x1 = unitIntervalToLong(rand.float(f64));
    const y0 = unitIntervalToLat(rand.float(f64));
    const y1 = unitIntervalToLat(rand.float(f64));

    const p1: Point = .{ .x = x0, .y = y0 };
    const p2: Point = .{ .x = x1, .y = y1 };

    const distance = referenceHaversine(p1.x, p1.y, p2.x, p2.y, EARTH_RADIUS);

    try stdout.print("x1: {d}, y1: {d}, x2: {d}, y2: {d} -> distance: {d}\n", .{ p1.x, p1.y, p2.x, p2.y, distance });

    try bw.flush();
}
