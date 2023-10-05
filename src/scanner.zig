const std = @import("std");
const shared = @import("shared.zig");
const isDigit = std.ascii.isDigit;

const Token = @import("token.zig").Token;

pub const Location = struct { current: usize, line: u32, column: usize };

pub const Scanner = struct {
    const Self = @This();

    buf: []const u8,
    location: Location = .{ .current = 0, .line = 1, .column = 0 },

    pub fn init(source: []const u8) Self {
        return .{ .buf = source };
    }

    pub fn scan(self: *Self) Token {
        self.skipWhiteSpace();
        self.resetPointers();

        if (self.isEof()) return self.createToken(.eof);

        const char = self.peek();
        _ = self.advance();

        return switch (char) {
            '+' => self.createToken(if (self.match('+'))
                .increment
            else
                .plus),
            '-' => self.createToken(if (self.match('-'))
                .decrement
            else
                .minus),
            '*' => self.createToken(.star),
            '/' => self.createToken(.slash),
            ';' => self.createToken(.semicolon),
            ':' => self.createToken(.colon),
            ',' => self.createToken(.comma),
            '?' => self.createToken(.question_mark),
            '(' => self.createToken(.left_paren),
            ')' => self.createToken(.right_paren),
            '{' => self.createToken(.left_brace),
            '}' => self.createToken(.right_brace),
            '.' => self.createToken(.dot),

            '\'' => self.string(false),
            '"' => self.string(true),

            '=' => self.createToken(if (self.match('='))
                .equal
            else
                .assign),
            '>' => self.createToken(if (self.match('='))
                .greater_equal
            else if (self.match('>'))
                .shift_right
            else
                .greater),
            '<' => self.createToken(if (self.match('='))
                .less_equal
            else if (self.match('<'))
                .shift_left
            else
                .less),
            '!' => self.createToken(if (self.match('='))
                .not_equal
            else
                .bang),

            '&' => self.createToken(.bw_and),
            '|' => self.createToken(.bw_or),
            '^' => self.createToken(.bw_xor),
            '~' => self.createToken(.bw_not),

            '0' => {
                return if (self.match('b')) self.binary() else if (self.match('o')) self.octal() else if (self.match('x')) self.hexadecimal() else self.number();
            },

            else => {
                if (isDigit(char)) return self.number();
                if (isAlpha(char)) return self.identifier();
                if (char == 0) return self.createToken(.eof);
                return self.errorToken("Neznámý znak");
            },
        };
    }

    fn advance(self: *Self) u8 {
        defer self.location.current += 1;
        return self.buf[self.location.current];
    }

    fn peek(self: *Self) u8 {
        if (self.isEof()) return '\x00';

        return self.buf[self.location.current];
    }

    fn peekNext(self: *Self) u8 {
        if (self.location.current + 1 > self.buf.len) return '\x00';
        return self.buf[self.location.current + 1];
    }

    fn match(self: *Self, expected: u8) bool {
        if (self.isEof()) return false;
        if (self.buf[self.location.current] != expected) return false;

        _ = self.advance();
        return true;
    }

    fn number(self: *Self) Token {
        while (isDigit(self.peek())) _ = self.advance();

        if (self.peek() == ',' and isDigit(self.peekNext())) {
            _ = self.advance();

            while (isDigit(self.peek())) _ = self.advance();
        }

        return self.createToken(.number);
    }

    fn hexadecimal(self: *Self) Token {
        while (isHexa(self.peek())) {
            _ = self.advance();
        }

        // self.skipSpace(2);

        return self.createToken(.hexadecimal);
    }

    fn octal(self: *Self) Token {
        while (isOctal(self.peek())) {
            _ = self.advance();
        }

        return self.createToken(.octal);
    }

    fn binary(self: *Self) Token {
        while (self.peek() == '1' or self.peek() == '0') {
            _ = self.advance();
        }

        // self.skipSpace(2);

        return self.createToken(.binary);
    }

    fn string(self: *Self, isMultiline: bool) Token {
        const deli: u8 = if (isMultiline) '"' else '\'';
        var hadMultilineError = false;

        switch (deli) {
            '\'' => {
                while (self.peek() != deli and !self.isEof()) {
                    if (self.peek() == '\n') {
                        hadMultilineError = true;
                    }
                    _ = self.advance();
                }
            },
            '"' => {
                while (self.peek() != deli and !self.isEof()) {
                    if (self.peek() == '\n') self.location.line += 1;
                    _ = self.advance();
                }
            },
            else => unreachable,
        }

        if (self.isEof()) return self.errorToken("Neukončený string");

        _ = self.advance();

        if (hadMultilineError) return self.errorToken("String obalen v \" nemůže být víceřádkový, použijte \'");

        return self.createToken(.string);
    }

    fn identifier(self: *Self) Token {
        while (isAlpha(self.peek()) or isDigit(self.peek())) {
            _ = self.advance();
        }

        return self.createToken(self.identifierOrKeyword());
    }

    fn errorToken(self: Self, message: []const u8) Token {
        return .{ .type = .chyba, .lexeme = message, .line = self.location.line, .column = self.location.column };
    }

    fn identifierOrKeyword(self: *Self) Token.Type {
        const lexeme = self.buf[0..self.location.current];

        const isKeyword = Token.Keywords.get(lexeme);
        return if (isKeyword) |keyword|
            keyword
        else
            .identifier;
    }

    fn skipWhiteSpace(self: *Self) void {
        while (true) {
            var char = self.peek();

            switch (char) {
                '\n' => {
                    self.location.line += 1;
                    self.location.column = 0;
                    _ = self.advance();
                },
                ' ', '\r' => {
                    self.location.column += 1;
                    _ = self.advance();
                },
                '\t' => {
                    self.location.column += 4;
                    _ = self.advance();
                },
                '/' => {
                    switch (self.peekNext()) {
                        '/' => {
                            while (self.peek() != '\n' and !self.isEof()) {
                                _ = self.advance();
                            }
                        },
                        '*' => {
                            while (self.peek() != '*' and self.peekNext() != '/' and !self.isEof()) {
                                _ = self.advance();
                            }
                        },
                        else => return,
                    }
                },
                else => return,
            }
        }
    }

    fn skipSpace(self: *Self, space: u8) void {
        self.buf = self.buf[space..];
        self.location.current -= space;
    }

    fn isEof(self: Self) bool {
        return self.buf.len <= self.location.current;
    }

    fn createToken(self: *Self, token_type: Token.Type) Token {
        const lexeme = self.buf[0..self.location.current];
        self.location.column += lexeme.len;
        return Token{ .type = token_type, .lexeme = self.buf[0..self.location.current], .line = self.location.line, .column = self.location.column };
    }

    fn resetPointers(self: *Self) void {
        self.buf = self.buf[self.location.current..];
        self.location.current = 0;
    }
};

fn isHexa(c: u8) bool {
    return switch (c) {
        '0'...'9', 'A'...'F', 'a'...'f' => true,
        else => false,
    };
}

fn isOctal(c: u8) bool {
    return switch (c) {
        '0'...'7' => true,
        else => false,
    };
}

fn isAlpha(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

fn testScanner(source: []const u8, types: []const Token.Type) !void {
    var scanner: Scanner = Scanner.init(source);
    for (types) |token_type| {
        const token: Token = scanner.scan();
        try std.testing.expectEqual(token_type, token.type);
    }
    const last_token: Token = scanner.scan();
    try std.testing.expectEqual(last_token.type, .eof);
}

test "variable" {
    try testScanner("prm k = 3; .k = 4;", &.{ .prm, .identifier, .assign, .number, .semicolon, .dot, .identifier, .assign, .number, .semicolon });
    try testScanner("konst PI;", &.{ .konst, .identifier, .semicolon });
}

test "if" {
    try testScanner("pokud 2 > 1: {}", &.{ .pokud, .number, .greater, .number, .colon, .left_brace, .right_brace });
    try testScanner("pokud ne: {} jinak {}", &.{ .pokud, .ne, .colon, .left_brace, .right_brace, .jinak, .left_brace, .right_brace });
}

test "number" {
    try testScanner("3,14; 5,25; 25;", &.{ .number, .semicolon, .number, .semicolon, .number, .semicolon });
    try testScanner("0xFF00FF", &.{.hexadecimal});
    try testScanner("0b001", &.{.binary});
}

test "binary" {
    try testScanner(".a & .b", &.{ .dot, .identifier, .bw_and, .dot, .identifier });
    try testScanner(".a | .b", &.{ .dot, .identifier, .bw_or, .dot, .identifier });
    try testScanner(".a ^ .b", &.{ .dot, .identifier, .bw_xor, .dot, .identifier });
    try testScanner("~0b01101", &.{ .bw_not, .binary });

    try testScanner(".b >> 1", &.{ .dot, .identifier, .shift_right, .number });
    try testScanner(".b << 1", &.{ .dot, .identifier, .shift_left, .number });
}

test "string" {
    try testScanner(
        \\ 'This is a test of a single line string'
    , &.{.string});
    try testScanner(
        \\ "This is a multiline 
        \\ string"
    , &.{.string});
    try testScanner(
        \\ 'This is multiline string
        \\ using wrong quotes'
    , &.{.chyba});

    try testScanner(
        \\ 'This is test of unterminated string
    , &.{.chyba});
    try testScanner(
        \\ "This is test of unterminated string
    , &.{.chyba});
}

test "for loop" {
    try testScanner("opakuj prm i = 0; .i < .str/delka; .i++: {}", &.{ .opakuj, .prm, .identifier, .assign, .number, .semicolon, .dot, .identifier, .less, .dot, .identifier, .slash, .identifier, .semicolon, .dot, .identifier, .increment, .colon, .left_brace, .right_brace });
    try testScanner("opakuj .k; .k != 20,24; .k--: {}", &.{ .opakuj, .dot, .identifier, .semicolon, .dot, .identifier, .not_equal, .number, .semicolon, .dot, .identifier, .decrement, .colon, .left_brace, .right_brace });
}

test "while loop" {
    try testScanner("dokud .i >= 10: {}", &.{ .dokud, .dot, .identifier, .greater_equal, .number, .colon, .left_brace, .right_brace });
    try testScanner("dokud ano: { pokud .i == 10: {pokracuj;}}", &.{ .dokud, .ano, .colon, .left_brace, .pokud, .dot, .identifier, .equal, .number, .colon, .left_brace, .pokracuj, .semicolon, .right_brace, .right_brace });
}
