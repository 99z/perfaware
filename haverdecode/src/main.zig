const std = @import("std");
const json = @import("json.zig");

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

fn printJsonTree(node: *json.NXJson, depth: usize) void {
    // Print indentation
    var i: usize = 0;
    while (i < depth) : (i += 1) {
        std.debug.print("  ", .{});
    }

    std.debug.print("{s}: {d}\n", .{ node.key, node.dbl_value });

    // Traverse children
    var child = node.children.first;
    while (child) |c| {
        printJsonTree(c, depth + 1);
        child = c.next;
    }
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var args = std.process.args();
    _ = args.next();

    const filename = args.next() orelse return try stdout.print("usage: havercode <filename>\n", .{});
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    const file_size = try file.getEndPos();
    const content = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(content);

    var result = try json.parse(allocator, content);
    defer result.arena.deinit();

    // printJsonTree(&result, 0);

    try bw.flush();
}
