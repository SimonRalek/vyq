const std = @import("std");

const Allocator = std.mem.Allocator;

const Block = @import("block.zig").Block;
const ResultError = @import("shared.zig").ResultError;
const Compiler = @import("compiler.zig").Compiler;

pub const VirtualMachine = struct {
    const Self = @This();

    block: *Block = undefined,
    ip: usize,
    stack: [256]f16 = undefined,
    stack_top: usize,

    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator, .ip = 0, .stack_top = 0 };
    }

    pub fn deinit(self: *Self) void {
        self.block.?.deinit();
    }

    // pub fn interpret(self: *Self, source: []const u8, allocator: Allocator) ResultError!void {
    //     var block = Block.init(allocator);
    //
    //     if (!Compiler.compile(source, &block)) {
    //         block.free();
    //         return .compile_error;
    //     }
    //
    //     self.block = &block;
    //     self.ip = self.block.code;
    //
    //     const result = self.run();
    //     return result;
    // }
    //
    pub fn interpret(self: *Self, block: *Block) ResultError!void {
        self.block = block;
        return self.run();
    }

    fn run(self: *Self) ResultError!void {
        while (true) {
            const instruction: Block.OpCode = @enumFromInt(self.readByte());

            switch (instruction) {
                .op_value => {
                    var value = self.readValue();
                    self.push(value);
                    std.debug.print("{}\n", .{value});
                },
                // .op_add => self.opAdd(),
                .op_negate => self.push(-self.pop()),
                .op_return => return,
                else => {},
            }
        }
    }

    fn push(self: *Self, val: f16) void {
        defer self.stack_top += 1;
        self.stack[self.stack_top] = val;
        std.debug.print("VAL: {}", .{val});
    }

    fn pop(self: *Self) f16 {
        self.stack_top -= 1;
        return self.stack[self.stack_top];
    }

    fn resetStack(self: *Self) void {
        self.stack_top = 0;
        self.ip = 0;
    }

    inline fn readByte(self: *Self) u8 {
        const byte = self.block.code.items[self.ip];
        self.ip += 1;
        return byte;
    }

    inline fn readValue(self: *Self) f16 {
        return self.block.constants.items[self.readByte()];
    }
};
