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
    switch (instruction) {
        .op_value => return valueInstruction("OP_VALUE", block, offset),
        .op_negate => return simpleInstruction("OP_NEGATE", offset),
        .op_return => return simpleInstruction("OP_RETURN", offset),
        else => {
            std.debug.print("Unknown opcode", .{});
            return offset + 1;
        },
    }
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
