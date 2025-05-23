const std = @import("std");
const sim86 = @import("sim86.zig");

const Registers = std.StringHashMap(u16);
var Memory = std.mem.zeroes([1024 * 1024]u8);

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
    try regs.put("ip", 0);
    try regs.put("flags", 0);
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
    try w.print("\tip: {?x}\n", .{regs.get("ip")});

    const flags = regs.get("flags") orelse return error.FlagsRegDoesNotExist;
    const sf = (flags >> 7) & 1;
    const zf = (flags >> 6) & 1;

    try w.print("\tflags: {s}{s}\n", .{
        if (sf == 1) "S" else "",
        if (zf == 1) "Z" else "",
    });
}

fn setFlags(w: anytype, result: u16, regs: *Registers) !void {
    const flags = regs.get("flags") orelse return error.FlagsRegDoesNotExist;

    const sf = (flags >> 7) & 1;
    const zf = (flags >> 6) & 1;

    const new_sf = (result >> 15) & 1;
    const new_zf: u16 = @intFromBool(result == 0);

    var updated_flags = flags;
    var print_sf = false;
    var print_zf = false;

    if (sf != new_sf) {
        updated_flags = (updated_flags & 0xFF7F) | (new_sf << 7);
        print_sf = true;
    }

    if (zf != new_zf) {
        updated_flags = (updated_flags & 0xFFBF) | (new_zf << 6);
        print_zf = true;
    }

    if (print_sf or print_zf) {
        try regs.put("flags", updated_flags);
        try w.print(" flags: {s}{s} -> {s}{s}", .{ if (sf == 1) "S" else "", if (zf == 1) "Z" else "", if (new_sf == 1) "S" else "", if (new_zf == 1) "Z" else "" });
    }
}

fn doMov(w: anytype, regs: *Registers, instr: sim86.Instruction) !void {
    var dest = instr.Operands[0];
    var src = instr.Operands[1];

    // Store
    if (dest.Type == .OperandMemory) {
	const dest_address_reg1 = sim86.registerNameFromOperand(&dest.data.Address.Terms[0].Register);
	const dest_address_reg_val1 = regs.get(dest_address_reg1) orelse 0;

	const dest_address_reg2 = sim86.registerNameFromOperand(&dest.data.Address.Terms[1].Register);
	const dest_address_reg_val2 = regs.get(dest_address_reg2) orelse 0;

	const disp_imm = @as(u16, @intCast(dest.data.Address.Displacement));
	const disp_full = disp_imm + dest_address_reg_val1 + dest_address_reg_val2;

	var src_val = if (src.data.Register.Count != 0)
	    regs.get(sim86.registerNameFromOperand(&src.data.Register)) orelse return error.SrcRegDoesNotExist
	else
	    src.data.Immediate.Value;
	src_val = @as(u16, @intCast(src_val));

	try w.print("{any} mem[{d}] -> {d}\n", .{instr.Op, disp_full, src_val});
	Memory[disp_full] = @intCast(src_val & 0xFF); // Low byte
	Memory[disp_full + 1] = @intCast((src_val >> 8) & 0xFF); // High byte

	return;
    }

    // Load
    if (src.Type == .OperandMemory) {
	const dest_reg_name = sim86.registerNameFromOperand(&dest.data.Register);
	const disp = @as(u16, @intCast(src.data.Address.Displacement));

	const low = Memory[disp];
	const high = Memory[disp + 1];
	const val = low | (@as(u16, high) << 8);

	try w.print("{any} {s} -> mem[{d}] ({d})\n", .{instr.Op, dest_reg_name, disp, val});

	try regs.put(dest_reg_name, val);

	return;
    }

    const dest_reg_name = sim86.registerNameFromOperand(&dest.data.Register);
    const dest_reg_val = regs.get(dest_reg_name) orelse return error.DestRegDoesNotExist;

    const src_reg_val_full = if (src.data.Register.Count != 0)
        regs.get(sim86.registerNameFromOperand(&src.data.Register)) orelse return error.SrcRegDoesNotExist
    else
        src.data.Immediate.Value;
    const src_reg_val = @as(u16, @intCast(src_reg_val_full));

    try w.print("{any} {s}:\t{?x} -> {?x}\n", .{ instr.Op, dest_reg_name, dest_reg_val, src_reg_val });

    try regs.put(dest_reg_name, src_reg_val);
}

fn doAddSubCmp(w: anytype, regs: *Registers, instr: sim86.Instruction) !void {
    var dest = instr.Operands[0];
    var src = instr.Operands[1];

    const dest_reg_name = sim86.registerNameFromOperand(&dest.data.Register);
    const dest_reg_val = regs.get(dest_reg_name) orelse return error.DestRegDoesNotExist;

    const src_reg_val_full = if (src.data.Register.Count != 0)
        regs.get(sim86.registerNameFromOperand(&src.data.Register)) orelse return error.SrcRegDoesNotExist
    else
        src.data.Immediate.Value;
    const src_reg_val = @as(u16, @intCast(src_reg_val_full));

    const result = switch (instr.Op) {
        .Op_sub, .Op_cmp => @subWithOverflow(dest_reg_val, src_reg_val)[0],
        .Op_add => src_reg_val + dest_reg_val,
        else => return error.SimNotImplemented,
    };

    try w.print("{any} {s}:\t{?x} -> {?x}", .{ instr.Op, dest_reg_name, dest_reg_val, result });
    try setFlags(w, result, regs);

    if (instr.Op != .Op_cmp) try regs.put(dest_reg_name, result);
    try w.print("\n", .{});
}

fn doJne(w: anytype, regs: *Registers, instr: sim86.Instruction, offset: usize) !usize {
    const flags = regs.get("flags") orelse return error.FlagsRegDoesNotExist;
    const zf = (flags >> 6) & 1;
    const jne_value = instr.Operands[0].data.Immediate.Value;
    try w.print("{any} {?d}\n", .{ instr.Op, jne_value });

    // TODO use @abs?
    var new_offset = offset;
    if (zf == 0) {
        new_offset = if (jne_value < 0)
            // Subtract the absolute value of b
            offset - @as(usize, @intCast(-jne_value))
        else
            offset + @as(usize, @intCast(jne_value));
    }

    return new_offset;
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

        const ip = regs.get("ip") orelse return error.IpRegDoesNotExist;
        try regs.put("ip", ip + @as(u16, @intCast(decoded.Size)));

        switch (decoded.Op) {
            .Op_mov => try doMov(w, &regs, decoded),
            .Op_add, .Op_cmp, .Op_sub => try doAddSubCmp(w, &regs, decoded),
            .Op_jne => offset = try doJne(w, &regs, decoded, offset),
            else => {
                try w.print("unhandled: {any}\n", .{decoded.Op});
            },
        }

        offset += decoded.Size;
    }

    try w.print("\n", .{});
    try printRegisters(w, &regs);

    try bw.flush();
}
