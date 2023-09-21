const std = @import("std");
const shared = @import("shared.zig");

const ResultError = shared.ResultError;
const Token = @import("token.zig").Token;
const Scanner = @import("scanner.zig").Scanner;
const Block = @import("block.zig").Block;
const Compiler = @import("compiler.zig").Compiler;

const Precedence = enum(u8) { none, assign, nebo, zaroven, equal, compare, term, bit, shift, factor, unary, call, primary };

const ParseFn = *const fn (self: *Parser) void;

const ParseRule = struct { infix: ?ParseFn = null, prefix: ?ParseFn = null, precedence: Precedence = .none };

pub const Parser = struct {
    const Self = @This();

    previous: Token,
    current: Token,
    hadError: bool,
    panicMode: bool,
    scanner: ?Scanner = null,
    compiler: ?Compiler = null,

    pub fn init() Parser {
        return .{ .current = undefined, .previous = undefined, .hadError = false, .panicMode = false };
    }

    pub fn parse(self: *Self, source: []const u8) void {
        self.scanner = Scanner.init(source);
        self.advance();
        self.expression();
        self.eat(.eof, "Očekávaný konec souboru");
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
        if (self.panicMode) return;
        self.panicMode = true;

        try shared.logger.err("Chyba: ", .{});
        try shared.logger.err("{s} - ", .{message});

        switch (token.type) {
            .eof => {
                try shared.logger.err("na konci", .{});
            },
            .chyba => {},
            else => {
                try shared.logger.err("v '{s}'", .{token.lexeme});
            },
        }

        try shared.logger.err(", řádka {}\n", .{token.line});
        self.hadError = true;
    }

    fn expression(self: *Self) void {
        self.parsePrecedence(.assign);
    }

    fn group(self: *Self) void {
        self.expression();
        self.eat(.right_paren, "Ocekavana ')' zavorka nebyla nalezena");
    }

    fn binary(self: *Self) void {
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
            else => {
                unreachable;
            },
        }
    }

    fn number(self: *Self) void {
        var buff: [self.previous.lexeme.len]u8 = undefined;
        _ = std.mem.replace(u8, self.previous.lexeme, ",", ".", &buff);
        const converted: f16 = std.fmt.parseFloat(f16, &buff);
        if (converted) |value| {
            _ = value;
            // emit const
        } else {
            shared.logger.err("Nepovedlo se cislo zpracovat", .{});
        }
    }

    fn string(self: *Self) !void {
        const source = self.previous.lexeme[1 .. self.previoius.lexeme.len - 1];
        // emit const
        _ = source;
    }

    fn parsePrecedence(self: *Self, precedence: Precedence) void {
        self.advance();
        const prefix = getRule(self.previous.type).prefix orelse {
            return;
        };

        prefix(self);
        while (@intFromEnum(precedence) <= @intFromEnum(getRule(self.previous.type).precedence)) {
            self.advance();
            const infix = getRule(self.previous.type).infix orelse unreachable;
            infix(self);
        }
    }

    fn getRule(t_type: Token.Type) ParseRule {
        return switch (t_type) {
            .left_paren => .{ .prefix = Parser.group },
            .right_paren => .{},
            .left_brace => .{},
            .right_brace => .{},

            .plus, .minus => .{ .infix = Parser.binary, .precedence = .term },
            .star, .slash => .{ .infix = Parser.binary, .precedence = .factor },

            else => unreachable,
        };
    }
};
