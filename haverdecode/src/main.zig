const std = @import("std");
const json = @import("json.zig");
const builtin = @import("builtin");

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

    std.debug.print("{s}: {d} -> {}\n", .{ node.key, node.float_value, node.type });

    // Traverse children
    var child = node.children.first;
    while (child) |c| {
        printJsonTree(c, depth + 1);
        child = c.next;
    }
}

fn parseResults(node: *json.NXJson) struct { usize, f32 } {
    var sum: f32 = 0;
    var num_points: usize = 0;

    // Find the "points" array
    var child = node.children.first;
    while (child) |c| {
        if (c.type == json.NXJsonType.NX_JSON_ARRAY and std.mem.eql(u8, c.key, "points")) {

            // Iterate through each point object in the array
            var point_obj = c.children.first;
            while (point_obj) |point| {
                if (point.type == json.NXJsonType.NX_JSON_OBJECT) {

                    // Extract x0, y0, x1, y1 by finding them by key
                    var x0: f64 = 0;
                    var y0: f64 = 0;
                    var x1: f64 = 0;
                    var y1: f64 = 0;

                    var coord = point.children.first;
                    while (coord) |c_coord| {
                        if (std.mem.eql(u8, c_coord.key, "x0")) {
                            x0 = c_coord.float_value;
                        } else if (std.mem.eql(u8, c_coord.key, "y0")) {
                            y0 = c_coord.float_value;
                        } else if (std.mem.eql(u8, c_coord.key, "x1")) {
                            x1 = c_coord.float_value;
                        } else if (std.mem.eql(u8, c_coord.key, "y1")) {
                            y1 = c_coord.float_value;
                        }
                        coord = c_coord.next;
                    }

                    const distance = referenceHaversine(@floatCast(x0), @floatCast(y0), @floatCast(x1), @floatCast(y1), EARTH_RADIUS);
                    sum += distance;
                    num_points += 1;
                }

                point_obj = point.next;
            }
            break; // Found the points array, we're done
        }
        child = c.next;
    }

    return .{ num_points, sum };
}

pub fn main() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

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

    // printJsonTree(&result.json, 0);
    const parsed = parseResults(&result.json);
    const num_points_float: f32 = @floatFromInt(parsed[0]);

    try stdout.print("num points: {}\nsum:{}\n", .{ parsed[0], parsed[1] });
    try stdout.print("average: {d}\n", .{parsed[1] / num_points_float});

    try stdout.flush();
}
