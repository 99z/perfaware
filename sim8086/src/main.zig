const std = @import("std");

const Mode = enum(u2) { memory, memory_8bit_disp, memory_16bit_disp, register };

const RegToReg = packed struct(u16) {
    word: bool,
    is_destination: bool,
    _op: u6,
    rm: u3,
    reg: u3,
    mode: Mode,
};

const ImmediateToReg = packed struct(u8) {
    reg: u3,
    word: bool,
    _op: u4,
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

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();

    const filename = args.next() orelse return std.debug.print("usage: sim8086 <BIN_FILENAME>\n", .{});
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const reader = file.reader();

    std.debug.print("bits 16\n\n", .{});

    while (reader.readByte()) |byte| {
        // Imm -> reg mov
        if (((byte >> 4) & 0b1111) == 0b1011) {
            const instr: ImmediateToReg = @bitCast(byte);

            const data = if (instr.word) try reader.readInt(i16, .little) else @as(i8, @bitCast(try reader.readByte()));

            std.debug.print("mov\t{s}, {}\n", .{ getRegisterName(instr.word, instr.reg), data });
        } else {
            const instr: RegToReg = @bitCast([2]u8{ byte, try reader.readByte() });
            const displacement: u16 = switch (instr.mode) {
                .register => 0,
                .memory => if (instr.rm == 0b110) try reader.readInt(u16, .little) else 0,
                .memory_8bit_disp => @as(u16, try reader.readByte()),
                .memory_16bit_disp => try reader.readInt(u16, .little),
            };

            const reg_name = getRegisterName(instr.word, instr.reg);
            switch (instr.mode) {
                .register => {
                    const data = getRegisterName(instr.word, instr.rm);
                    std.debug.print("mov\t{s}, {s}\n", .{ data, reg_name });
                },
                .memory, .memory_8bit_disp, .memory_16bit_disp => {
                    const data = getMemoryModeNameEAC(instr.rm);

                    if (displacement != 0) {
                        std.debug.print("mov\t{s}, {s} + {}]\n", .{ reg_name, data, displacement });
                    } else {
                        if (instr.is_destination) {
                            std.debug.print("mov\t{s}, {s}]\n", .{ reg_name, data });
                        } else {
                            std.debug.print("mov\t{s}], {s}\n", .{ data, reg_name });
                        }
                    }
                },
            }
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => std.debug.print("Error reading instr: {}\n", .{err}),
    }
}
