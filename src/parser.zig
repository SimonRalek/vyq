const std = @import("std");
const shared = @import("shared.zig");

const ResultError = shared.ResultError;
const Token = @import("token.zig").Token;
const Scanner = @import("scanner.zig").Scanner;

const Precedence = enum(u8) { none, assign, nebo, zaroven, equal, compare, term, bit, shift, factor, unary, call, primary };

const ParseFn = fn () ResultError!void;

const ParseRule = struct { infix: ?ParseFn, prefix: ?ParseFn, precedence: Precedence };

pub const Parser = struct {
    const Self = @This();

    previous: Token,
    current: Token,
    hadError: bool,
    panicMode: bool,
    // parseRule: ?ParseRule,
    scanner: ?Scanner = null,

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

    fn binary() void {}

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
        const prefix = self.getRule(self.previous.type).prefix orelse {
            return;
        };

        prefix();
        while (precedence <= self.getRule(self.previous.type).precedence) {
            self.advance();
            const infix = getRule(self.previous.type).infix orelse unreachable;
            infix();
        }
    }

    fn getRule(self: *Self, t_type: Token.Type) ParseRule {
        return switch (t_type) {
            .left_paren => .{ .prefix = self.group },
            .right_paren => .{},

            .plus => .{ .infix = self.binary, .precedence = .term },
            .minus => .{ .infix = self.binary, .precedence = .term },
            .star => .{ .infix = self.binary, .precedence = .factor },
            .slash => .{ .infix = self.binary, .precedence = .factor },

            else => unreachable,
        };
    }
};
