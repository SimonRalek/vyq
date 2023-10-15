const std = @import("std");

const Val = @import("value.zig").Val;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const charList = ArrayList(u8);
const valList = ArrayList(Val);
const intList = ArrayList(u32);

pub const Block = struct {
    const Self = @This();

    pub const OpCode = enum(u8) {
        op_value,
        op_ano,
        op_ne,
        op_nic,

        op_not,
        op_negate,

        op_equal,
        op_greater,
        op_less,
        op_shift_left,
        op_shift_right,
        op_bit_and,
        op_bit_or,
        op_bit_xor,
        op_bit_not,

        op_add,
        op_sub,
        op_mult,
        op_div,
        op_return,

        op_print,
        op_def_glob_var,
        op_def_glob_const,
        op_get_glob,
        op_set_glob,
        op_pop,
    };

    code: charList,
    lines: intList,
    values: valList,

    /// Inicializace bloku
    pub fn init(allocator: Allocator) Self {
        return .{ .code = charList.init(allocator), .lines = intList.init(allocator), .values = valList.init(allocator) };
    }

    /// Free blok
    pub fn deinit(self: *Self) void {
        self.code.deinit();
        self.lines.deinit();
        self.values.deinit();
    }

    /// Zapsat instrukci
    pub fn writeOp(self: *Self, op_code: OpCode, line: u32) !void {
        try self.writeOpByte(@intFromEnum(op_code), line);
    }

    /// Zapsat instrukce
    pub fn writeOpByte(self: *Block, byte: u8, line: u32) !void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    /// Přidat hodnotu do bloku
    pub fn addValue(self: *Self, value: Val) !u8 {
        const index = self.values.items.len;
        try self.values.append(value);
        return @intCast(index);
    }
};
