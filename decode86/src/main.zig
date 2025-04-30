const std = @import("std");
const sim86 = @import("sim86.zig");

pub fn main() !void {
    std.debug.print("sim86 reference version: {}\n", .{sim86.getVersion()});

    var args = std.process.args();
    _ = args.next();
	// const exec = std.mem.eql(u8, args.next() orelse "", "-exec");

    const filename = args.next() orelse return std.debug.print("usage: decode86 <BIN_FILENAME>\n", .{});
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
	defer {
		_ = gpa.deinit();
	}

    const stat = try file.stat();
    const buffer = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(buffer);

	const decoded = sim86.decode8086Instruction(buffer);
	std.debug.print("{any}\n", .{decoded});
}
