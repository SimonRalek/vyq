const std = @import("std");
const shared = @import("shared.zig");
const Allocator = std.mem.Allocator;

const VM = @import("virtualmachine.zig").VirtualMachine;

const ResultError = shared.ResultError;
const Val = @import("value.zig").Val;
const Token = @import("token.zig").Token;
const Scanner = @import("scanner.zig").Scanner;
const Block = @import("block.zig").Block;
const Emitter = @import("emitter.zig").Emitter;
const Reporter = @import("reporter.zig");
const Object = @import("value.zig").Object;

const Precedence = enum(u8) { none, assignment, nebo, zaroven, equal, compare, term, bit, shift, factor, unary, call, primary };

const ParseFn = *const fn (self: *Parser, canAssign: bool) anyerror!void;

const ParseRule = struct { infix: ?ParseFn = null, prefix: ?ParseFn = null, precedence: Precedence = .none };

pub const Parser = struct {
    const Self = @This();

    allocator: Allocator,
    previous: Token,
    current: Token,
    scanner: ?Scanner = null,
    emitter: ?*Emitter = null,
    vm: ?*VM = null,
    reporter: *Reporter,

    pub fn init(allocator: Allocator, emitter: *Emitter, vm: *VM, reporter: *Reporter) Parser {
        return .{ .allocator = allocator, .emitter = emitter, .vm = vm, .reporter = reporter, .current = undefined, .previous = undefined };
    }

    pub fn parse(self: *Self, source: []const u8) void {
        self.scanner = Scanner.init(source);
        self.advance();

        while (!self.check(.eof)) {
            self.declaration();
        }
    }

    fn advance(self: *Self) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.?.scan();
            if (self.current.type != .chyba) break;

            self.report(&self.current, self.current.message.?);
        }
    }

    fn eat(self: *Self, expected: Token.Type, message: []const u8) void {
        if (self.check(expected)) {
            self.advance();
            return;
        }

        self.report(&self.current, message);
    }

    fn match(self: *Self, expected: Token.Type) bool {
        const result = self.check(expected);
        defer {
            if (result) self.advance();
        }
        return result;
    }

    fn check(self: *Self, expected: Token.Type) bool {
        return expected == self.current.type;
    }

    fn emitOpCode(self: *Self, op_code: Block.OpCode) void {
        self.emitter.?.emitOpCode(op_code, self.previous.location);
    }

    fn emitVal(self: *Self, val: Val) void {
        self.emitter.?.emitValue(val, self.previous.location);
    }

    fn makeVal(self: *Self, val: Val) u8 {
        return self.emitter.?.makeValue(val);
    }

    fn report(self: *Self, token: *Token, message: []const u8) void {
        self.reporter.report(ResultError.parser, token, message);
    }

    fn declaration(self: *Self) void {
        if (self.match(.prm)) {
            self.variableDeclaration() catch {};
        } else if (self.match(.konst)) {
            self.constDeclaration() catch {};
        } else {
            self.statement();
        }

        if (self.reporter.panic_mode) self.synchronize();
    }

    fn expression(self: *Self) void {
        self.parsePrecedence(.assignment);
    }

    fn statement(self: *Self) void {
        if (self.match(.tiskni)) {
            self.printStmt();
        } else {
            self.exprStmt();
        }
    }

    fn variableDeclaration(self: *Self) !void {
        const glob = try self.parseVar("Očekávané jméno prvku po 'prm'");

        if (self.match(.assign)) {
            self.expression();
        } else {
            self.emitOpCode(.op_nic);
        }

        self.eat(.semicolon, "Očekávaná ';' za výrazem");

        self.defineVar(glob);
    }

    fn constDeclaration(self: *Self) !void {
        const glob = try self.parseVar("Očekávané jméno prvku po 'konst'");

        if (self.match(.assign)) {
            self.expression();
        } else {
            self.reporter.warn(&self.previous, "Incializace konstanty s prázdnou hodnotou");
            self.emitOpCode(.op_nic);
        }

        self.eat(.semicolon, "Chybí ';' za příkazem");

        self.defineConst(glob);
    }

    fn defineVar(self: *Self, glob: u8) void {
        return self.emitter.?.emitOpCodes(.op_def_glob_var, glob, self.previous.location);
    }

    fn defineConst(self: *Self, glob: u8) void {
        return self.emitter.?.emitOpCodes(.op_def_glob_const, glob, self.previous.location);
    }

    fn parseVar(self: *Self, message: []const u8) !u8 {
        if (self.match(.dot)) {
            self.report(&self.current, "Pro jméno prvku nelze použít '.'");
            return ResultError.parser;
        }
        self.eat(.identifier, message);
        const token = self.previous;
        return self.makeVal(Val{ .obj = Object.String.copy(self.vm.?, token.lexeme) });
    }

    fn variable(self: *Self, canAssign: bool) !void {
        self.advance();
        const token = &self.previous;
        try self.namedVar(token, canAssign);
    }

    fn namedVar(self: *Self, token: *Token, canAssign: bool) !void {
        const arg = self.makeVal(Val{ .obj = Object.String.copy(self.vm.?, token.lexeme) });

        if (canAssign and self.match(.assign)) {
            self.expression();
            self.emitter.?.emitOpCodes(.op_set_glob, arg, self.previous.location);
        } else if (canAssign and (self.match(.add_operator) or self.match(.min_operator) or self.match(.div_operator) or self.match(.mul_operator))) {
            const operator = self.previous.type;

            self.emitter.?.emitOpCodes(.op_get_glob, arg, self.previous.location);
            self.expression();

            self.emitOpCode(switch (operator) {
                .add_operator => .op_add,
                .min_operator => .op_sub,
                .div_operator => .op_div,
                .mul_operator => .op_mult,
                else => unreachable,
            });

            self.emitter.?.emitOpCodes(.op_set_glob, arg, self.previous.location);
        } else {
            self.emitter.?.emitOpCodes(.op_get_glob, arg, self.previous.location);
        }
    }

    fn printStmt(self: *Self) void {
        self.expression();
        self.eat(.semicolon, "Chybí ';' za příkazem");
        self.emitOpCode(.op_print);
    }

    fn exprStmt(self: *Self) void {
        self.expression();
        self.eat(.semicolon, "Chybí ';' za příkazem");
        self.emitOpCode(.op_pop);
    }

    fn synchronize(self: *Self) void {
        self.reporter.panic_mode = false;

        while (self.current.type != .eof) {
            if (self.previous.type == .semicolon) return;
            switch (self.current.type) {
                .trida, .funkce, .prm, .opakuj, .pokud, .dokud, .tiskni, .vrat => return,
                else => {},
            }
            self.advance();
        }
    }

    fn group(self: *Self, canAssign: bool) !void {
        _ = canAssign;

        self.expression();
        self.eat(.right_paren, "Očekávaná ')' nebyla nalezena");
    }

    fn unary(self: *Self, canAssign: bool) !void {
        _ = canAssign;

        const op_type = self.previous.type;

        self.parsePrecedence(.unary);

        switch (op_type) {
            .minus => self.emitOpCode(.op_negate),
            .bang => self.emitOpCode(.op_not),
            .bw_not => {
                self.emitOpCode(.op_bit_not);
            },
            else => unreachable,
        }
    }

    fn binary(self: *Self, canAssign: bool) !void {
        _ = canAssign;

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

    fn number(self: *Self, canAssign: bool) !void {
        _ = canAssign;

        var buff = try self.allocator.alloc(u8, self.previous.lexeme.len);
        defer self.allocator.free(buff);

        _ = std.mem.replace(u8, self.previous.lexeme, ",", ".", buff);
        const converted: std.fmt.ParseFloatError!f64 = std.fmt.parseFloat(f64, buff);
        if (converted) |value| {
            self.emitVal(Val{ .number = value });
        } else |err| {
            try shared.stdout.print("Nepovedlo se cislo zpracovat: {}", .{err});
        }
    }

    fn base(self: *Self, canAssign: bool) !void {
        _ = canAssign;

        const val = std.fmt.parseUnsigned(i64, self.previous.lexeme, 0) catch {
            @panic("Parsování nešlo");
        };
        self.emitVal(Val{ .number = @floatFromInt(val) });
    }

    fn crement(self: *Self, canAssign: bool) !void {
        _ = canAssign;

        switch (self.previous.type) {
            .increment => self.emitOpCode(.op_increment),
            .decrement => self.emitOpCode(.op_decrement),
            else => unreachable,
        }
    }

    fn string(self: *Self, canAssign: bool) !void {
        _ = canAssign;

        const source = self.previous.lexeme[1 .. self.previous.lexeme.len - 1];
        self.emitVal(Object.String.copy(self.vm.?, source).val());
    }

    fn literal(self: *Self, canAssign: bool) !void {
        _ = canAssign;

        switch (self.previous.type) {
            .ano => self.emitOpCode(.op_ano),
            .ne => self.emitOpCode(.op_ne),
            .nic => self.emitOpCode(.op_nic),
            else => unreachable,
        }
    }

    fn parsePrecedence(self: *Self, precedence: Precedence) void {
        self.advance();
        const prefix = getRule(self.previous.type).prefix orelse {
            self.report(&self.previous, "Neznámý vstup");
            return;
        };

        const canAssign = @intFromEnum(precedence) <= @intFromEnum(Precedence.assignment);
        prefix(self, canAssign) catch {};
        while (@intFromEnum(precedence) <= @intFromEnum(getRule(self.current.type).precedence)) {
            self.advance();
            const infix = getRule(self.previous.type).infix orelse unreachable;
            infix(self, canAssign) catch {};
        }

        if (canAssign and self.match(.assign)) {
            self.report(&self.previous, "K hodnotě nelze přiřadit hodnotu");
        }
    }

    fn special(self: *Self, canAssign: bool) !void {
        _ = canAssign;

        std.debug.print("{}", .{self.previous});
        self.expression();
        self.emitOpCode(.op_add);
        self.emitOpCode(.op_get_glob);
    }

    fn getRule(t_type: Token.Type) ParseRule {
        return switch (t_type) {
            .left_paren => .{ .prefix = Parser.group },
            .right_paren, .left_brace, .right_brace => .{},
            .identifier, .assign => .{},

            .increment, .decrement => .{ .infix = Parser.crement },

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

            .dot => .{ .prefix = Parser.variable },
            .semicolon, .eof => .{},

            else => {
                unreachable;
            },
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
