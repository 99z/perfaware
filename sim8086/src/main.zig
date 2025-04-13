const std = @import("std");

const Mode = enum(u2) { memory, memory_8bit_disp, memory_16bit_disp, register };

const RegToReg = packed struct(u16) {
    word: bool,
    is_destination: bool,
    op: u6,
    rm: u3,
    reg: u3,
    mode: Mode,
};

const ImmediateToRegMOV = packed struct(u8) {
    reg: u3,
    word: bool,
    op: u4,
};

const ImmediateToReg = packed struct(u8) {
    rm: u3,
    // middle 3 bits indicates which instr (add/sub/cmp)
    instr: u3,
    mode: Mode,
};

// Jump instructions
const Jumps = enum(u8) {
    je = 0b01110100,
    jl = 0b01111100,
    jle = 0b01111110,
    jb = 0b01110010,
    jbe = 0b01110110,
    jp = 0b01111010,
    jo = 0b01110000,
    js = 0b01111000,
    jne = 0b01110101,
    jnl = 0b01111101,
    jg = 0b01111111,
    jnb = 0b01110011,
    ja = 0b01110111,
    jnp = 0b01111011,
    jno = 0b01110001,
    jns = 0b01111001,
    loop = 0b11100010,
    loopz = 0b11100001,
    loopnz = 0b11100000,
    jcxz = 0b11100011,
};

fn getRegisterName(word: bool, reg: u3) []const u8 {
    const index: u4 = (@as(u4, @intFromBool(word)) << 3) | @as(u4, reg);

    return switch (index) {
        // Byte
        0b0000 => "al",
        0b0001 => "cl",
        0b0010 => "dl",
        0b0011 => "bl",
        0b0100 => "ah",
        0b0101 => "ch",
        0b0110 => "dh",
        0b0111 => "bh",

        // Word
        0b1000 => "ax",
        0b1001 => "cx",
        0b1010 => "dx",
        0b1011 => "bx",
        0b1100 => "sp",
        0b1101 => "bp",
        0b1110 => "si",
        0b1111 => "di",
    };
}

fn getMemoryModeNameEAC(rm: u3) []const u8 {
    return switch (rm) {
        0b000 => "[bx + si",
        0b001 => "[bx + di",
        0b010 => "[bp + si",
        0b011 => "[bp + di",
        0b100 => "[si",
        0b101 => "[di",
        0b110 => "[bp",
        0b111 => "[bx",
    };
}

fn isRegMemAndRegToEither(byte: u8) bool {
    if (
        // movs
        byte >= 0b10001000 and byte <= 0b10001011 or
        byte >= 0b10100000 and byte <= 0b10100101 or
        byte == 0b10001100 or
        byte == 0b10001110 or
        ((byte & 0b11110000) == 0b10110000) or
        // add
        ((byte >> 2) & 0b111111) == 0b000000 or
        // sub
        ((byte >> 2) & 0b111111) == 0b001010 or
        // cmp
        ((byte >> 2) & 0b111111) == 0b001110)
    {
        return true;
    }

    return false;
}

fn isImmToAccum(byte: u8) bool {
    if (
    // add
    (byte >> 1) & 0b1111111 == 0b0000010 or
        // sub
        (byte >> 1) & 0b1111111 == 0b0010110 or
        // cmp
        (byte >> 1) & 0b1111111 == 0b0011110)
    {
        return true;
    }

    return false;
}

fn decodeImmToAccum(byte: u8, reader: *std.fs.File.Reader) !void {
    const w: bool = (byte & 0b1) != 0;
    const instr_code: u3 = @intCast((byte >> 3) & 0b111);

    const data = if (w) try reader.readInt(i16, .little) else try reader.readInt(i8, .little);
    const verb = switch (instr_code) {
        0b000 => "add",
        0b101 => "sub",
        0b111 => "cmp",
        else => "not_impl",
    };

    const accum = if (w) "ax" else "al";
    std.debug.print("{s}\t{s}, {}\n", .{ verb, accum, data });
}

// add/sub/cmp imm -> reg decode
fn decodeImmToRegOrMem(byte: u8, reader: *std.fs.File.Reader) !void {
    const second_byte: ImmediateToReg = @bitCast(try reader.readByte());
    const sw: u2 = @intCast(byte & 0b11);

    const displacement = switch (second_byte.mode) {
        .register, .memory => 0,
        .memory_8bit_disp => try reader.readInt(i8, .little),
        .memory_16bit_disp => try reader.readInt(i16, .little),
    };

    const data = if (sw == 0b01) try reader.readInt(i16, .little) else try reader.readInt(i8, .little);

    const verb = switch (second_byte.instr) {
        0b000 => "add",
        0b101 => "sub",
        0b111 => "cmp",
        else => "not_impl",
    };

    const reg_name = getRegisterName((sw << 1) != 0, second_byte.rm);
    std.debug.print("{s}\t{s}, {} + {}\n", .{ verb, reg_name, data, displacement });
}

fn decodeRmOrImm(byte: u8, reader: *std.fs.File.Reader) !void {
    const instr_code = (byte >> 3) & 0b111;
    const verb = switch (instr_code) {
        0b000 => "add",
        0b101 => "sub",
        0b111 => "cmp",
        else => "mov",
    };

    const instr: RegToReg = @bitCast([2]u8{ byte, try reader.readByte() });
    const displacement = switch (instr.mode) {
        .register => 0,
        .memory => if (instr.rm == 0b110) try reader.readInt(i16, .little) else 0,
        .memory_8bit_disp => try reader.readInt(i8, .little),
        .memory_16bit_disp => try reader.readInt(i16, .little),
    };

    const reg_name = getRegisterName(instr.word, instr.reg);
    switch (instr.mode) {
        .register => {
            const data = getRegisterName(instr.word, instr.rm);
            std.debug.print("{s}\t{s}, {s}\n", .{ verb, data, reg_name });
        },
        .memory, .memory_8bit_disp, .memory_16bit_disp => {
            const data = getMemoryModeNameEAC(instr.rm);

            if (displacement != 0) {
                std.debug.print("{s}\t{s}, {s} + {}]\n", .{ verb, reg_name, data, displacement });
            } else {
                if (instr.is_destination) {
                    std.debug.print("{s}\t{s}, {s}]\n", .{ verb, reg_name, data });
                } else {
                    std.debug.print("{s}\t{s}], {s}\n", .{ verb, data, reg_name });
                }
            }
        },
    }
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();

    const filename = args.next() orelse return std.debug.print("usage: sim8086 <BIN_FILENAME>\n", .{});
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var reader = file.reader();

    std.debug.print("bits 16\n\n", .{});

    while (reader.readByte()) |byte| {
        // shortest opcode: mov imm -> reg
        if (((byte >> 4) & 0b1111) == 0b1011) {
            const instr: ImmediateToRegMOV = @bitCast(byte);
            const data = if (instr.word) try reader.readInt(i16, .little) else @as(i8, @bitCast(try reader.readByte()));
            std.debug.print("mov\t{s}, {}\n", .{ getRegisterName(instr.word, instr.reg), data });
            continue;
        }

        // subset of movs
        if (isRegMemAndRegToEither(byte)) {
            _ = try decodeRmOrImm(byte, &reader);
        }

        // add/sub/cmp imm -> reg
        // same instruction byte for all 3
        if ((byte >> 2) & 0b111111 == 0b100000) {
            _ = try decodeImmToRegOrMem(byte, &reader);
        }

        // add/sub/cmp imm -> accum
        if (isImmToAccum(byte)) {
            _ = try decodeImmToAccum(byte, &reader);
        }

        // jumps are easier - static opcode followed by label
        if (std.meta.intToEnum(Jumps, byte)) |jmp| {
            std.debug.print("{s} label\n", .{@tagName(jmp)});
            _ = try reader.readByte();
        } else |err| switch (err) {
            else => {},
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => std.debug.print("Error reading instr: {}\n", .{err}),
    }
}
