const std = @import("std");
const _block = @import("block.zig");
const Block = _block.Block;

pub const debugging = false;
pub const benchmark = false;
pub const test_alloc = false;
pub const allow_logging = true;

/// Výpis instrukcí s hodnoty v bloku
pub fn disBlock(block: *Block, name: []const u8) void {
    std.debug.print("--- {s} ---\n", .{name});

    var i: usize = 0;
    while (i < block.*.code.items.len) {
        i = disInstruction(block, i);
    }
}

/// Rozebrat instrukci
pub fn disInstruction(block: *Block, idx: usize) usize {
    std.debug.print("{} ", .{idx});

    // if (idx > 0 and block.*.locations.items[idx].line == block.*.locations.items[idx - 1].line) {
    //     std.debug.print("|    ", .{});
    // } else {
    //     std.debug.print("{:0>4} ", .{block.*.locations.items[idx].line});
    // }

    const instruction: Block.OpCode = @enumFromInt(block.*.code.items[idx]);

    std.debug.print("{}\n\n", .{instruction});
    return switch (instruction) {
        .op_value => value("op_value", block, idx),
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
        .op_def_glob_var => simple("op_define_global_var", idx),
        .op_def_glob_const => simple("op_define_global_const", idx),
        .op_get_glob => simple("op_get_global", idx),
        .op_set_glob => simple("op_set_global", idx),
        .op_pop => simple("op_pop", idx),
        .op_return => simple("op_return", idx),
    };
}

/// Výpis instrukce a zvednuti indexu
inline fn simple(name: []const u8, idx: usize) usize {
    _ = name;
    // std.debug.print("{s}\n", .{name});
    return idx + 1;
}

/// Výpis instrukce s hodnotou a zvednutí indexu
inline fn value(name: []const u8, block: *Block, idx: usize) usize {
    _ = name;
    var val = block.*.code.items[idx + 1];
    _ = val;
    // std.debug.print("{s} {} \n", .{ name, val });
    // std.debug.print("{}", .{val});
    // std.debug.print("{}\n", .{block.*.values.items[val - 1]});
    return idx + 2;
}
