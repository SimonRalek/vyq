const std = @import("std");
const shared = @import("shared.zig");
const Allocator = std.mem.Allocator;

const VM = @import("virtualmachine.zig").VirtualMachine;

const ResultError = shared.ResultError;
const Val = @import("value.zig").Val;
const Token = @import("token.zig").Token;
const Scanner = @import("scanner.zig").Scanner;
const Block = @import("block.zig").Block;
const Compiler = @import("compiler.zig").Compiler;
const Reporter = @import("reporter.zig");
const Object = @import("value.zig").Object;

const Precedence = enum(u8) { none, assign, nebo, zaroven, equal, compare, term, bit, shift, factor, unary, call, primary };

const ParseFn = *const fn (self: *Parser) anyerror!void;

const ParseRule = struct { infix: ?ParseFn = null, prefix: ?ParseFn = null, precedence: Precedence = .none };

pub const Parser = struct {
    const Self = @This();

    allocator: Allocator,
    previous: Token,
    current: Token,
    scanner: ?Scanner = null,
    compiler: ?*Compiler = null,
    vm: ?*VM = null,
    reporter: *Reporter,

    pub fn init(allocator: Allocator, compiler: *Compiler, vm: *VM, reporter: *Reporter) Parser {
        return .{ .allocator = allocator, .compiler = compiler, .vm = vm, .reporter = reporter, .current = undefined, .previous = undefined };
    }

    pub fn parse(self: *Self, source: []const u8) void {
        self.scanner = Scanner.init(source);
        self.advance();
        self.expression();
        self.eat(.semicolon, "Očekávaný konec souboru");
    }

    fn advance(self: *Self) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.?.scan();
            if (self.current.type != .chyba) break;

            self.report(&self.previous, self.current.lexeme) catch {};
        }
    }

    fn eat(self: *Self, expected: Token.Type, message: []const u8) void {
        if (self.check(expected)) {
            self.advance();
            return;
        }

        self.report(&self.previous, message) catch {};
    }

    fn check(self: *Self, expected: Token.Type) bool {
        return expected == self.current.type;
    }

    fn emitOpCode(self: *Self, op_code: Block.OpCode) void {
        self.compiler.?.emitOpCode(op_code, self.previous.line);
    }

    fn report(self: *Self, token: *Token, message: []const u8) !void {
        self.reporter.report(ResultError.parser, token, message);
    }

    fn expression(self: *Self) void {
        self.parsePrecedence(.assign);
    }

    fn group(self: *Self) !void {
        self.expression();
        self.eat(.right_paren, "Ocekavana ')' zavorka nebyla nalezena");
    }

    fn unary(self: *Self) !void {
        const op_type = self.previous.type;

        self.parsePrecedence(.unary);

        switch (op_type) {
            .minus => self.compiler.?.emitOpCode(.op_negate, self.previous.line),
            .bang => self.compiler.?.emitOpCode(.op_not, self.previous.line),
            .bw_not => {
                self.compiler.?.emitOpCode(.op_bit_not, self.previous.line);
            },
            else => unreachable,
        }
    }

    fn binary(self: *Self) !void {
        const op_type = self.previous.type;
        const rule = getRule(op_type);

        self.parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

        switch (op_type) {
            .plus => {
                self.emitOpCode(.op_add);
            },
            .minus => {
                self.emitOpCode(.op_sub);
            },
            .star => {
                self.emitOpCode(.op_mult);
            },
            .slash => {
                self.emitOpCode(.op_div);
            },
            .equal => {
                self.emitOpCode(.op_equal);
            },
            .not_equal => {
                self.emitOpCode(.op_equal);
                self.emitOpCode(.op_not);
            },
            .greater => {
                self.emitOpCode(.op_greater);
            },
            .greater_equal => {
                self.emitOpCode(.op_less);
                self.emitOpCode(.op_not);
            },
            .less => {
                self.emitOpCode(.op_less);
            },
            .less_equal => {
                self.emitOpCode(.op_greater);
                self.emitOpCode(.op_not);
            },
            .bw_and => {
                self.emitOpCode(.op_bit_and);
            },
            .bw_or => {
                self.emitOpCode(.op_bit_or);
            },
            .bw_xor => {
                self.emitOpCode(.op_bit_xor);
            },
            .shift_left => {
                self.emitOpCode(.op_shift_left);
            },
            .shift_right => {
                self.emitOpCode(.op_shift_right);
            },
            else => {
                unreachable;
            },
        }
    }

    fn number(self: *Self) !void {
        var buff = try self.allocator.alloc(u8, self.previous.lexeme.len);
        defer self.allocator.free(buff);

        _ = std.mem.replace(u8, self.previous.lexeme, ",", ".", buff);
        const converted: std.fmt.ParseFloatError!f64 = std.fmt.parseFloat(f64, buff);
        if (converted) |value| {
            try self.compiler.?.emitValue(Val{ .number = value }, self.previous.line);
        } else |err| {
            try shared.logger.err("Nepovedlo se cislo zpracovat: {}", .{err});
        }
    }

    fn base(self: *Self) !void {
        const val = std.fmt.parseUnsigned(i64, self.previous.lexeme, 0) catch blk: {
            // reporter
            break :blk 0;
        };
        try self.compiler.?.emitValue(Val{ .number = @floatFromInt(val) }, self.previous.line);
    }

    fn string(self: *Self) !void {
        const source = self.previous.lexeme[1 .. self.previous.lexeme.len - 1];
        try self.compiler.?.emitValue(Object.String.copy(self.vm.?, source).val(), self.previous.line);
    }

    fn literal(self: *Self) !void {
        const line = self.previous.line;

        switch (self.previous.type) {
            .ano => self.compiler.?.emitOpCode(.op_ano, line),
            .ne => self.compiler.?.emitOpCode(.op_ne, line),
            .nic => self.compiler.?.emitOpCode(.op_nic, line),
            else => unreachable,
        }
    }

    fn parsePrecedence(self: *Self, precedence: Precedence) void {
        self.advance();
        const prefix = getRule(self.previous.type).prefix orelse {
            // TODO
            return;
        };

        prefix(self) catch {};
        while (@intFromEnum(precedence) <= @intFromEnum(getRule(self.current.type).precedence)) {
            self.advance();
            const infix = getRule(self.previous.type).infix orelse unreachable;
            infix(self) catch {};
        }
    }

    fn getRule(t_type: Token.Type) ParseRule {
        return switch (t_type) {
            .left_paren => .{ .prefix = Parser.group },
            .right_paren => .{},
            .left_brace => .{},
            .right_brace => .{},

            .number => .{ .prefix = Parser.number },
            .binary, .octal, .hexadecimal => .{ .prefix = Parser.base },

            .ano, .ne, .nic => .{ .prefix = Parser.literal },

            .string => .{ .prefix = Parser.string },

            .plus => .{ .infix = Parser.binary, .precedence = .term },
            .minus => .{ .prefix = Parser.unary, .infix = Parser.binary, .precedence = .term },
            .star, .slash => .{ .infix = Parser.binary, .precedence = .factor },

            .bang => .{ .prefix = Parser.unary },

            .equal, .not_equal => .{ .infix = Parser.binary, .precedence = .equal },
            .greater, .greater_equal, .less, .less_equal => .{ .infix = Parser.binary, .precedence = .compare },

            .bw_and, .bw_or, .bw_xor => .{ .infix = Parser.binary, .precedence = .bit },
            .shift_right, .shift_left => .{ .infix = Parser.binary, .precedence = .shift },

            .semicolon, .eof => .{},

            else => unreachable,
        };
    }
};

fn testParser(source: []const u8, expected: f64) !void {
    var allocator = std.testing.allocator;
    var vm = VM.init(allocator);
    try vm.interpret(source);

    try std.testing.expectEqual(expected, vm.stack[0].number);
}

test "simple expressions" {
    try testParser("1 + 2;", 3);
    try testParser("7 - 2 * 3;", 1);
    try testParser("-(4 + (-6)) * 10 /5;", 4);
}
