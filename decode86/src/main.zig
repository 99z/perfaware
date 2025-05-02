const std = @import("std");
const sim86 = @import("sim86.zig");

const Registers = std.StringHashMap(i32);

fn initRegisters(allocator: std.mem.Allocator) !Registers {
    var regs = Registers.init(allocator);
    try regs.put("ax", 0);
    try regs.put("bx", 0);
    try regs.put("cx", 0);
    try regs.put("dx", 0);
    try regs.put("si", 0);
    try regs.put("di", 0);
    try regs.put("bp", 0);
    try regs.put("sp", 0);
    return regs;
}

fn printRegisters(w: anytype, regs: *Registers) !void {
	try w.print("Final registers:\n", .{});
	try w.print("\tax: {?x}\n", .{regs.get("ax")});
	try w.print("\tbx: {?x}\n", .{regs.get("bx")});
	try w.print("\tcx: {?x}\n", .{regs.get("cx")});
	try w.print("\tdx: {?x}\n", .{regs.get("dx")});
	try w.print("\tsp: {?x}\n", .{regs.get("sp")});
	try w.print("\tbp: {?x}\n", .{regs.get("bp")});
	try w.print("\tsi: {?x}\n", .{regs.get("si")});
	try w.print("\tdi: {?x}\n", .{regs.get("di")});
}

fn doMOV(w: anytype, regs: *Registers, instr: sim86.Instruction) !void {
	var dest = instr.Operands[0];
	var src = instr.Operands[1];
	const reg_name = sim86.registerNameFromOperand(&dest.data.Register);

	const cur_value = regs.get(reg_name);

	// Nonzero when reg->reg mov, otherwise 0
	// ...at least, I think that's the best way to tell :)
	if (src.data.Register.Count != 0) {
		const src_reg_name = sim86.registerNameFromOperand(&src.data.Register);
		try w.print("{s}:\t{?x} -> {?s}\n", .{reg_name, cur_value, src_reg_name});

		const src_reg_val = regs.get(src_reg_name) orelse return error.SrcRegDoesNotExist;

		try regs.put(reg_name, src_reg_val);
	} else {
		try w.print("{s}:\t{?x} -> {?x}\n", .{reg_name, cur_value, src.data.Immediate.Value});

		try regs.put(reg_name, src.data.Immediate.Value);
	}

}

pub fn main() !void {
	// I had to do a bit of reading to figure out the "correct"
	// way of writing to stdout efficiently:
	// https://github.com/ziglang/zig/issues/21566
	// https://zig.news/kristoff/how-to-add-buffering-to-a-writer-reader-in-zig-7jd
	//
	// This comment in particular was enlightening:
	// > That buffering is done by libc not the OS. So no buffering if you write
	// > directly to stdout's OS file descriptor. In C, you'll observe the buffered IO
	// > if you use printf(3)/fprintf(3)/fwrite(3), but not if you used write(2) directly.
	const stdout = std.io.getStdOut();
	var bw = std.io.bufferedWriter(stdout.writer());
	var w = bw.writer();
		
    try w.print("sim86 reference version: {}\n", .{sim86.getVersion()});

    var args = std.process.args();
    _ = args.next();

    const filename = args.next() orelse return try w.print("usage: decode86 <BIN_FILENAME>\n", .{});
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
	defer {
		_ = gpa.deinit();
	}

	var regs = try initRegisters(allocator);
	defer regs.deinit();

	const stat = try file.stat();
	const buffer = try file.readToEndAlloc(allocator, stat.size);
	defer allocator.free(buffer);

	var offset: usize = 0;
	while (offset < buffer.len) {
		const decoded = try sim86.decode8086Instruction(buffer[offset..buffer.len]);

		if (decoded.Op == sim86.OperationType.Op_mov) {
			try doMOV(w, &regs, decoded);
		}

		offset += decoded.Size;
	}
	
	try w.print("\n", .{});
	try printRegisters(w, &regs);

	try bw.flush();
}
