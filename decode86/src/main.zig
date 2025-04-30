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

fn printRegisters(regs: *Registers) !void {
	std.debug.print("Final registers:\n", .{});
	std.debug.print("\tax: {?x}\n", .{regs.get("ax")});
	std.debug.print("\tbx: {?x}\n", .{regs.get("bx")});
	std.debug.print("\tcx: {?x}\n", .{regs.get("cx")});
	std.debug.print("\tdx: {?x}\n", .{regs.get("dx")});
	std.debug.print("\tsp: {?x}\n", .{regs.get("sp")});
	std.debug.print("\tbp: {?x}\n", .{regs.get("bp")});
	std.debug.print("\tsi: {?x}\n", .{regs.get("si")});
	std.debug.print("\tdi: {?x}\n", .{regs.get("di")});
}

fn doMOV(regs: *Registers, instr: sim86.Instruction) !void {
	var dest = instr.Operands[0];
	const src = instr.Operands[1];
	const reg_name = sim86.registerNameFromOperand(&dest.data.Register);

	const cur_value = regs.get(reg_name);
	std.debug.print("{s}:\t{?x} -> {?x}\n", .{reg_name, cur_value, src.data.Immediate.Value});

	try regs.put(reg_name, src.data.Immediate.Value);
}

pub fn main() !void {
    std.debug.print("sim86 reference version: {}\n", .{sim86.getVersion()});

    var args = std.process.args();
    _ = args.next();

    const filename = args.next() orelse return std.debug.print("usage: decode86 <BIN_FILENAME>\n", .{});
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
			try doMOV(&regs, decoded);
		}

		offset += decoded.Size;
	}
	
	std.debug.print("\n", .{});
	try printRegisters(&regs);
}
