const std = @import("std");
const _block = @import("block.zig");
const Block = _block.Block;

pub const debugging = true;
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
    std.debug.print("{:0>3} ", .{idx});

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
        .op_mod => simple("op_mod", idx),
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
        .op_jmp => jmp("op_jmp", 1, block, idx),
        .op_jmp_on_true => jmp("op_jmp_on_true", 1, block, idx),
        .op_jmp_on_false => jmp("op_jmp_on_false", 1, block, idx),
        .op_loop => jmp("op_loop", -1, block, idx),
        .op_case => simple("op_case", idx),
        .op_call => byte("op_call", block, idx),
        .op_closure => blk: {
            const val = block.code.items[idx + 1];
            std.debug.print("{s} {} ", .{ "OP_CLOSURE", val });
            block.values.items[val].print(allocator);
            std.debug.print("\n", .{});

            const func = block.values.items[val].obj.function();
            var count: usize = idx;
            for (0..func.elv_count) |i| {
                _ = i;
                const loc = block.code.items[count + 2];
                const index = block.code.items[count + 3];
                std.debug.print("{:0>3} |                {s} {d}\n", .{ count + 2, if (loc == 1) "local" else "elv", index });
                count += 2;
            }

            break :blk idx + 2 + func.elv_count * 2;
        },
        .op_set_elv => byte("op_set_elv", block, idx),
        .op_get_elv => byte("op_get_elv", block, idx),
        .op_close_elv => simple("op_close_elv", idx),

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

inline fn jmp(name: []const u8, sign: i8, block: *Block, idx: usize) usize {
    const b1 = @as(u16, block.code.items[idx + 1]);
    const b2 = block.code.items[idx + 2];
    const jump = (b1 << 8) | b2;
    const addr = switch (sign) {
        1 => idx + 3 + jump,
        -1 => idx + 3 - jump,
        else => unreachable,
    };
    std.debug.print("{s} {d:4} -> {d}\n", .{ name, jump, addr });
    return idx + 3;
}
