const std = @import("std");
const _block = @import("block.zig");
const Block = _block.Block;

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
        .op_value => valueInstruction("OP_VALUE", block, offset),
        .op_negate => simpleInstruction("OP_NEGATE", offset),
        .op_add => simpleInstruction("OP_ADD", offset),
        .op_sub => simpleInstruction("OP_MINUS", offset),
        .op_mult => simpleInstruction("OP_MULT", offset),
        .op_div => simpleInstruction("OP_DIV", offset),
        .op_not => simpleInstruction("OP_NOT", offset),
        .op_nic => simpleInstruction("OP_NIC", offset),
        .op_ano => simpleInstruction("OP_ANO", offset),
        .op_ne => simpleInstruction("OP_NE", offset),
        .op_equal => simpleInstruction("OP_EQUAL", offset),
        .op_greater => simpleInstruction("OP_GREATER", offset),
        .op_less => simpleInstruction("OP_LESS", offset),
        // .op_bit_and => return simpleInstruction("op_bit_and", offset),
        // .op_bit_or => return simpleInstruction("op_bit_or", offset),
        // .op_shift_left => return simpleInstruction("op_shift_left", offset),
        // .op_shift_right => return simpleInstruction("op_shift_right", offset),
        // .op_bit_not => return simpleInstruction("OP_BIT_NOT", offset),
        .op_return => return simpleInstruction("OP_RETURN", offset),
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
