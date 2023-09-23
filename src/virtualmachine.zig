const std = @import("std");

const Allocator = std.mem.Allocator;

const Block = @import("block.zig").Block;
const ResultError = @import("shared.zig").ResultError;
const Compiler = @import("compiler.zig").Compiler;

const BinaryOperation = enum { add, sub, mult, div };

pub const VirtualMachine = struct {
    const Self = @This();

    block: *Block = undefined,
    ip: usize,
    stack: [256]f64 = undefined,
    stack_top: usize,

    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator, .ip = 0, .stack_top = 0 };
    }

    pub fn deinit(self: *Self) void {
        self.block.deinit();
    }

    pub fn interpret(self: *Self, source: []const u8) ResultError!void {
        var block = Block.init(self.allocator);
        defer block.deinit();

        var compiler = Compiler.init(self.allocator);
        compiler.compile(source, &block) catch return ResultError.compile;

        self.block = &block;
        self.ip = 0;

        return self.run();
    }

    fn run(self: *Self) ResultError!void {
        while (true) {
            const instruction: Block.OpCode = @enumFromInt(self.readByte());

            switch (instruction) {
                .op_value => {
                    var value = self.readValue();
                    self.push(value);
                },
                .op_add => self.binary(.add),
                .op_sub => self.binary(.sub),
                .op_mult => self.binary(.mult),
                .op_div => self.binary(.div),
                // .op_add => self.opAdd(),
                .op_negate => self.push(-self.pop()),
                // .op_bit_not => self.push(~self.pop()),
                .op_return => return,
                else => unreachable,
            }
        }
    }

    fn push(self: *Self, val: f64) void {
        defer self.stack_top += 1;
        self.stack[self.stack_top] = val;
        std.debug.print("VAL: {}\n", .{val});
    }

    fn pop(self: *Self) f64 {
        self.stack_top -= 1;
        return self.stack[self.stack_top];
    }

    fn resetStack(self: *Self) void {
        self.stack_top = 0;
        self.ip = 0;
    }

    inline fn binary(self: *Self, operation: BinaryOperation) void {
        const b = self.pop();
        const a = self.pop();

        self.push(switch (operation) {
            .add => a + b,
            .sub => a - b,
            .mult => a * b,
            .div => a / b,
        });
    }

    inline fn readByte(self: *Self) u8 {
        const byte = self.block.code.items[self.ip];
        self.ip += 1;
        return byte;
    }

    inline fn readValue(self: *Self) f64 {
        return self.block.constants.items[self.readByte()];
    }
};
