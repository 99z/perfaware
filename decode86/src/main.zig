const std = @import("std");
const sim86 = @import("sim86.zig");

const Registers = struct {
    ax: u16,
    bx: u16,
    cx: u16,
    dx: u16,
    si: u16,
    di: u16,
    bp: u16,
    sp: u16,
    ip: u16,
    flags: u16,
};

var Memory = std.mem.zeroes([1024 * 1024]u8);

// Helper function to get register value by name
fn getRegister(regs: *const Registers, reg_name: []const u8) !u16 {
    if (std.mem.eql(u8, reg_name, "ax")) {
        return regs.ax;
    } else if (std.mem.eql(u8, reg_name, "bx")) {
        return regs.bx;
    } else if (std.mem.eql(u8, reg_name, "cx")) {
        return regs.cx;
    } else if (std.mem.eql(u8, reg_name, "dx")) {
        return regs.dx;
    } else if (std.mem.eql(u8, reg_name, "si")) {
        return regs.si;
    } else if (std.mem.eql(u8, reg_name, "di")) {
        return regs.di;
    } else if (std.mem.eql(u8, reg_name, "bp")) {
        return regs.bp;
    } else if (std.mem.eql(u8, reg_name, "sp")) {
        return regs.sp;
    } else if (std.mem.eql(u8, reg_name, "ip")) {
        return regs.ip;
    } else if (std.mem.eql(u8, reg_name, "flags")) {
        return regs.flags;
    } else return 0;
}

// Helper function to set register value by name
fn setRegister(regs: *Registers, reg_name: []const u8, value: u16) !void {
    if (std.mem.eql(u8, reg_name, "ax")) {
        regs.ax = value;
    } else if (std.mem.eql(u8, reg_name, "bx")) {
        regs.bx = value;
    } else if (std.mem.eql(u8, reg_name, "cx")) {
        regs.cx = value;
    } else if (std.mem.eql(u8, reg_name, "dx")) {
        regs.dx = value;
    } else if (std.mem.eql(u8, reg_name, "si")) {
        regs.si = value;
    } else if (std.mem.eql(u8, reg_name, "di")) {
        regs.di = value;
    } else if (std.mem.eql(u8, reg_name, "bp")) {
        regs.bp = value;
    } else if (std.mem.eql(u8, reg_name, "sp")) {
        regs.sp = value;
    } else if (std.mem.eql(u8, reg_name, "ip")) {
        regs.ip = value;
    } else if (std.mem.eql(u8, reg_name, "flags")) {
        regs.flags = value;
    } else return error.InvalidRegisterName;
}

fn printRegisters(w: anytype, regs: *Registers) !void {
    try w.print("Final registers:\n", .{});
    try w.print("\tax: {?x}\n", .{regs.ax});
    try w.print("\tbx: {?x}\n", .{regs.bx});
    try w.print("\tcx: {?x}\n", .{regs.cx});
    try w.print("\tdx: {?x}\n", .{regs.dx});
    try w.print("\tsp: {?x}\n", .{regs.sp});
    try w.print("\tbp: {?x}\n", .{regs.bp});
    try w.print("\tsi: {?x}\n", .{regs.si});
    try w.print("\tdi: {?x}\n", .{regs.di});
    try w.print("\tip: {?x}\n", .{regs.ip});

    const flags = regs.flags;
    const sf = (flags >> 7) & 1;
    const zf = (flags >> 6) & 1;

    try w.print("\tflags: {s}{s}\n", .{
        if (sf == 1) "S" else "",
        if (zf == 1) "Z" else "",
    });
}

fn setFlags(w: anytype, result: u16, regs: *Registers) !void {
    const flags = regs.flags;

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
        regs.flags = updated_flags;
        try w.print(" flags: {s}{s} -> {s}{s}", .{ if (sf == 1) "S" else "", if (zf == 1) "Z" else "", if (new_sf == 1) "S" else "", if (new_zf == 1) "Z" else "" });
    }
}

fn doMov(w: anytype, regs: *Registers, instr: sim86.Instruction) !void {
    var dest = instr.Operands[0];
    var src = instr.Operands[1];

    // Store
    if (dest.Type == .OperandMemory) {
        const dest_address_reg1 = sim86.registerNameFromOperand(&dest.data.Address.Terms[0].Register);
        const dest_address_reg_val1 = try getRegister(regs, dest_address_reg1);

        const dest_address_reg2 = sim86.registerNameFromOperand(&dest.data.Address.Terms[1].Register);
        const dest_address_reg_val2 = try getRegister(regs, dest_address_reg2);

        const disp_imm = @as(u16, @intCast(dest.data.Address.Displacement));
        const disp_full = disp_imm + dest_address_reg_val1 + dest_address_reg_val2;

        var src_val = if (src.data.Register.Count != 0)
            try getRegister(regs, sim86.registerNameFromOperand(&src.data.Register))
        else
            src.data.Immediate.Value;
        src_val = @as(u16, @intCast(src_val));

        // TODO Use mnemonicFromOperationType?
        try w.print("{any} mem[{d}] -> {d}\n", .{ instr.Op, disp_full, src_val });
        Memory[disp_full] = @intCast(src_val & 0xFF); // Low byte
        Memory[disp_full + 1] = @intCast((src_val >> 8) & 0xFF); // High byte

        return;
    }

    // Load
    if (src.Type == .OperandMemory) {
        const src_address_reg1 = sim86.registerNameFromOperand(&src.data.Address.Terms[0].Register);
        const src_address_reg_val1 = try getRegister(regs, src_address_reg1);

        const src_address_reg2 = sim86.registerNameFromOperand(&src.data.Address.Terms[1].Register);
        const src_address_reg_val2 = try getRegister(regs, src_address_reg2);

        const disp_imm = @as(u16, @intCast(src.data.Address.Displacement));
        const disp_full = disp_imm + src_address_reg_val1 + src_address_reg_val2;

        const dest_reg_name = sim86.registerNameFromOperand(&dest.data.Register);

        const low = Memory[disp_full];
        const high = Memory[disp_full + 1];
        const val = low | (@as(u16, high) << 8);

        try w.print("{any} {s} -> mem[{d}] ({d})\n", .{ instr.Op, dest_reg_name, disp_full, val });

        try setRegister(regs, dest_reg_name, val);

        return;
    }

    const dest_reg_name = sim86.registerNameFromOperand(&dest.data.Register);
    const dest_reg_val = try getRegister(regs, dest_reg_name);

    const src_reg_val_full = if (src.data.Register.Count != 0)
        try getRegister(regs, sim86.registerNameFromOperand(&src.data.Register))
    else
        src.data.Immediate.Value;
    const src_reg_val = @as(u16, @intCast(src_reg_val_full));

    try w.print("{any} {s}:\t{?x} -> {?x}\n", .{ instr.Op, dest_reg_name, dest_reg_val, src_reg_val });

    setRegister(regs, dest_reg_name, src_reg_val) catch std.debug.print("catch: {s}\n", .{dest_reg_name});
}

fn doAddSubCmp(w: anytype, regs: *Registers, instr: sim86.Instruction) !void {
    var dest = instr.Operands[0];
    var src = instr.Operands[1];

    const dest_reg_name = sim86.registerNameFromOperand(&dest.data.Register);
    const dest_reg_val = try getRegister(regs, dest_reg_name);

    const src_reg_val_full = if (src.data.Register.Count != 0)
        try getRegister(regs, sim86.registerNameFromOperand(&src.data.Register))
    else
        src.data.Immediate.Value;
    const src_reg_val = @as(u16, @intCast(src_reg_val_full));

    const result = switch (instr.Op) {
        .Op_sub, .Op_cmp => @subWithOverflow(dest_reg_val, src_reg_val)[0],
        .Op_add => src_reg_val + dest_reg_val,
        else => return error.SimNotImplemented,
    };

    try w.print("{any} {s}:\t{?d} -> {?d}", .{ instr.Op, dest_reg_name, dest_reg_val, result });
    try setFlags(w, result, regs);

    if (instr.Op != .Op_cmp) try setRegister(regs, dest_reg_name, result);
    try w.print("\n", .{});
}

fn doJne(w: anytype, regs: *Registers, instr: sim86.Instruction, offset: usize) !usize {
    const flags = regs.flags;
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

    var regs = std.mem.zeroInit(Registers, .{});

    const stat = try file.stat();
    const buffer = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(buffer);

    var offset: usize = 0;
    while (offset < buffer.len) {
        const decoded = try sim86.decode8086Instruction(buffer[offset..buffer.len]);

        regs.ip = @addWithOverflow(regs.ip, @as(u16, @intCast(decoded.Size)))[0];

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
