const std = @import("std");
const _block = @import("block.zig");
const Block = _block.Block;

pub const debugging = true;
pub const test_allocator = true;
pub const allow_logging = true;

pub fn disassembleBlock(block: *Block, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    var i: usize = 0;
    while (i < block.*.code.items.len) {
        i = disassembleInstruction(block, i);
    }
}

pub fn disassembleInstruction(block: *Block, offset: usize) usize {
    std.debug.print("{} ", .{offset});

    if (offset > 0 and block.*.lines.items[offset] == block.*.lines.items[offset - 1]) {
        std.debug.print("| ", .{});
    } else {
        std.debug.print("{} ", .{block.*.lines.items[offset]});
    }

    const instruction: Block.OpCode = @enumFromInt(block.*.code.items[offset]);
    return switch (instruction) {
        .op_value => valueInstruction("op_value", block, offset),
        .op_negate => simpleInstruction("op_negate", offset),
        .op_add => simpleInstruction("op_add", offset),
        .op_sub => simpleInstruction("op_minus", offset),
        .op_mult => simpleInstruction("op_mult", offset),
        .op_div => simpleInstruction("op_div", offset),
        .op_not => simpleInstruction("op_not", offset),
        .op_nic => simpleInstruction("op_nic", offset),
        .op_ano => simpleInstruction("op_ano", offset),
        .op_ne => simpleInstruction("op_ne", offset),
        .op_equal => simpleInstruction("op_equal", offset),
        .op_greater => simpleInstruction("op_greater", offset),
        .op_less => simpleInstruction("op_less", offset),
        .op_bit_and => return simpleInstruction("op_bit_and", offset),
        .op_bit_or => return simpleInstruction("op_bit_or", offset),
        .op_bit_xor => return simpleInstruction("op_bit_xor", offset),
        .op_shift_left => return simpleInstruction("op_shift_left", offset),
        .op_shift_right => return simpleInstruction("op_shift_right", offset),
        .op_bit_not => return simpleInstruction("op_bit_not", offset),
        .op_print => return simpleInstruction("op_print", offset),
        .op_define_global => return simpleInstruction("op_define_global", offset),
        .op_get_global => return simpleInstruction("op_get_global", offset),
        .op_pop => return simpleInstruction("op_pop", offset),
        .op_return => return simpleInstruction("op_return", offset),
        // else => {
        //     std.debug.print("Unknown opcode", .{});
        //     return offset + 1;
        // },
    };
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}

fn valueInstruction(name: []const u8, block: *Block, offset: usize) usize {
    var val = block.*.code.items[offset + 1];
    std.debug.print("{s} {} ", .{ name, val });
    std.debug.print("{}\n", .{block.*.constants.items[val]});
    return offset + 2;
}
