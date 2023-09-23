const std = @import("std");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Block = struct {
    const Self = @This();

    pub const OpCode = enum(u8) {
        op_value,
        op_negate,
        op_bit_not,
        op_add,
        op_sub,
        op_mult,
        op_div,
        op_return,
    };

    code: ArrayList(u8),
    lines: ArrayList(u32),
    constants: ArrayList(f64),

    pub fn init(allocator: Allocator) Self {
        return .{ .code = ArrayList(u8).init(allocator), .lines = ArrayList(u32).init(allocator), .constants = ArrayList(f64).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
        self.lines.deinit();
        self.constants.deinit();
    }

    pub fn writeOpCode(self: *Self, op_code: OpCode, line: u32) !void {
        try self.writeByte(@intFromEnum(op_code), line);
    }

    pub fn writeByte(self: *Block, byte: u8, line: u32) !void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    pub fn addValue(self: *Self, value: f64) !u8 {
        const index = self.constants.items.len;
        try self.constants.append(value);
        return @intCast(index);
    }
};
