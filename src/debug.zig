const std = @import("std");
const _block = @import("block.zig");
const Block = _block.Block;

pub const debugging = false;
pub const benchmark = false;
pub const test_alloc = true;

/// Výpis instrukcí s hodnoty v bloku
pub fn disBlock(block: *Block, name: []const u8) void {
    std.debug.print("--- {s} ---\n", .{name});
    var allocator = std.heap.page_allocator;

    var i: usize = 0;
    while (i < block.code.items.len) {
        i = disInstruction(block, i, allocator);
    }
}

/// Rozebrat instrukci
pub fn disInstruction(block: *Block, idx: usize, allocator: std.mem.Allocator) usize {
    std.debug.print("{} ", .{idx});

    if (idx > 0 and block.*.locations.items[idx].line == block.*.locations.items[idx - 1].line) {
        std.debug.print("|    ", .{});
    } else {
        std.debug.print("{:0>4} ", .{block.*.locations.items[idx].line});
    }

    const instruction: Block.OpCode = @enumFromInt(block.*.code.items[idx]);
    return switch (instruction) {
        .op_value => value("op_value", block, idx, allocator),
        .op_negate => simple("op_negate", idx),
        .op_add => simple("op_add", idx),
        .op_sub => simple("op_minus", idx),
        .op_mult => simple("op_mult", idx),
        .op_div => simple("op_div", idx),
        .op_increment => simple("op_increment", idx),
        .op_decrement => simple("op_decrement", idx),
        .op_not => simple("op_not", idx),
        .op_nic => simple("op_nic", idx),
        .op_ano => simple("op_ano", idx),
        .op_ne => simple("op_ne", idx),
        .op_equal => simple("op_equal", idx),
        .op_greater => simple("op_greater", idx),
        .op_less => simple("op_less", idx),
        .op_bit_and => simple("op_bit_and", idx),
        .op_bit_or => simple("op_bit_or", idx),
        .op_bit_xor => simple("op_bit_xor", idx),
        .op_shift_left => simple("op_shift_left", idx),
        .op_shift_right => simple("op_shift_right", idx),
        .op_bit_not => simple("op_bit_not", idx),
        .op_print => simple("op_print", idx),
        .op_println => simple("op_println", idx),
        .op_def_glob_var => value("op_define_global_var", block, idx, allocator),
        .op_def_glob_const => value("op_define_global_const", block, idx, allocator),
        .op_get_glob => value("op_get_global", block, idx, allocator),
        .op_set_glob => value("op_set_global", block, idx, allocator),
        .op_get_loc => byte("op_get_loc", block, idx),
        .op_set_loc => byte("op_set_loc", block, idx),
        .op_pop => simple("op_pop", idx),
        .op_popn => byte("op_popn", block, idx),
        .op_return => simple("op_return", idx),
    };
}

/// Výpis instrukce a zvednuti indexu
inline fn simple(name: []const u8, idx: usize) usize {
    std.debug.print("{s}\n", .{name});
    return idx + 1;
}

/// Výpis instrukce s hodnotou a zvednutí indexu
inline fn value(
    name: []const u8,
    block: *Block,
    idx: usize,
    allocator: std.mem.Allocator,
) usize {
    var val = block.*.code.items[idx + 1];
    std.debug.print("{s} {} ", .{ name, val });

    block.*.values.items[val].print(allocator);
    std.debug.print("\n", .{});
    return idx + 2;
}

inline fn byte(name: []const u8, block: *Block, idx: usize) usize {
    var k = block.code.items[idx + 1];
    std.debug.print("{s} {}\n", .{ name, k });
    return idx + 2;
}
