const std = @import("std");

const Allocator = std.mem.Allocator;

const Val = @import("value.zig").Val;
const Block = @import("block.zig").Block;
const ResultError = @import("shared.zig").ResultError;
const Compiler = @import("compiler.zig").Compiler;

const BinaryOp = enum { add, sub, mult, div, greater, less, bit_and, bit_or, bit_xor };
const ShiftOp = enum { left, right };

pub const VirtualMachine = struct {
    const Self = @This();

    block: *Block = undefined,
    ip: usize,
    stack: [256]Val = undefined,
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

            try switch (instruction) {
                .op_value => {
                    var value = self.readValue();
                    self.push(value);
                },
                .op_ano => self.push(Val{ .boolean = true }),
                .op_ne => self.push(Val{ .boolean = false }),
                .op_nic => self.push(Val.nic),

                .op_add => self.binary(.add),
                .op_sub => self.binary(.sub),
                .op_mult => self.binary(.mult),
                .op_div => self.binary(.div),

                .op_greater => self.binary(.greater),
                .op_less => self.binary(.less),
                .op_equal => {
                    var a = self.pop();
                    var b = self.pop();

                    self.push(Val{ .boolean = Val.isEqual(a, b) });
                },

                .op_not => self.push(Val{ .boolean = isFalsey(self.pop()) }),
                .op_negate => {
                    if (self.peek(0) != .number) {
                        self.runtimeErr("", .{});
                        return ResultError.runtime;
                    }
                    const val = Val{ .number = -(self.pop().number) };
                    self.push(val);
                },

                .op_bit_and => self.binary(.bit_and),
                .op_bit_or => self.binary(.bit_or),
                .op_bit_xor => self.binary(.bit_xor),
                .op_shift_left => self.shift(.left),
                .op_shift_right => self.shift(.right),
                .op_bit_not => {
                    const val: i64 = @intFromFloat(self.pop().number);
                    const result: f64 = @floatFromInt(~val);
                    self.push(Val{ .number = result });
                },

                .op_return => return,
            };
        }
    }

    fn push(self: *Self, val: Val) void {
        defer self.stack_top += 1;
        self.stack[self.stack_top] = val;
        val.print();
    }

    fn pop(self: *Self) Val {
        self.stack_top -= 1;
        return self.stack[self.stack_top];
    }

    fn peek(self: *Self, distance: u16) Val {
        return self.stack[self.stack_top - 1 - distance];
    }

    fn resetStack(self: *Self) void {
        self.stack_top = 0;
        self.ip = 0;
    }

    fn isFalsey(val: Val) bool {
        return val == .nic or (val == .boolean and !val.boolean);
    }

    inline fn binary(self: *Self, operation: BinaryOp) ResultError!void {
        if (self.peek(0) != .number or self.peek(1) != .number) {
            std.debug.print("runtime error", .{});
            self.runtimeErr("", .{});
            return ResultError.runtime;
        }

        const b = self.pop().number;
        const a = self.pop().number;

        const result = switch (operation) {
            .add => a + b,
            .sub => a - b,
            .mult => a * b,
            .div => a / b,

            .greater => a > b,
            .less => a < b,

            else => blk: {
                const a_bit: i64 = @intFromFloat(a);
                const b_bit: i64 = @intFromFloat(b);

                const op = switch (operation) {
                    .bit_and => a_bit & b_bit,
                    .bit_or => a_bit | b_bit,
                    .bit_xor => a_bit ^ b_bit,
                    else => unreachable,
                };

                const res: f64 = @floatFromInt(op);

                break :blk res;
            },
        };

        if (@TypeOf(result) == bool) {
            self.push(Val{ .boolean = result });
        } else {
            self.push(Val{ .number = result });
        }
    }

    inline fn shift(self: *Self, operation: ShiftOp) ResultError!void {
        const b = self.pop().number;

        if (b >= 64.0 or b < 0.0) {
            // report
            return ResultError.runtime;
        }

        const a_bit: i64 = @intFromFloat(self.pop().number);
        const b_bit: u6 = @intFromFloat(b);

        const op = switch (operation) {
            .right => a_bit >> b_bit,
            .left => a_bit << b_bit,
        };

        const result: f64 = @floatFromInt(op);

        self.push(Val{ .number = result });
    }

    inline fn readByte(self: *Self) u8 {
        const byte = self.block.code.items[self.ip];
        self.ip += 1;
        return byte;
    }

    inline fn readValue(self: *Self) Val {
        return self.block.constants.items[self.readByte()];
    }

    fn runtimeErr(self: *Self, comptime message: []const u8, args: anytype) void {
        _ = args;
        _ = message;
        _ = self;
        // reporter
    }
};
