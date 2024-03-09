const std = @import("std");
const shared = @import("shared.zig");
const isDigit = std.ascii.isDigit;

const Util = @import("utils/unicode.zig");
const _token = @import("token.zig");
const Token = _token.Token;

// Lokace tokenu - řádka, kde začíná a končí
pub const Location = struct {
    line: u32,
    start_column: usize,
    end_column: usize,

    pub fn init(
        line: u32,
        start_column: usize,
        end_column: usize,
    ) Location {
        return Location{
            .line = line,
            .start_column = start_column,
            .end_column = end_column,
        };
    }
};

pub const Scanner = struct {
    const Self = @This();

    buf: []const u8,
    current: usize,
    location: Location = .{
        .line = 1,
        .start_column = 1,
        .end_column = 0,
    },

    /// Inicializace scanneru
    pub fn init(source: []const u8) Self {
        return .{ .buf = source, .current = 0 };
    }

    /// Skenovat a vrátit token
    pub fn scan(self: *Self) Token {
        self.skipWhiteSpace();

        if (self.isEof()) return self.createToken(.eof);
        self.resetPointers();

        const char = self.advance();

        return switch (char) {
            '+' => self.createToken(if (self.match('='))
                .add_operator
            else
                .plus),
            '-' => self.createToken(if (self.match('='))
                .min_operator
            else if (self.match('>'))
                .arrow
            else
                .minus),
            '*' => self.createToken(if (self.match('='))
                .mul_operator
            else
                .star),
            '/' => self.createToken(if (self.match('='))
                .div_operator
            else
                .slash),
            '%' => self.createToken(if (self.match('='))
                .mod_operator
            else
                .modulo),
            ';' => self.createToken(.semicolon),
            ':' => self.createToken(.colon),
            ',' => self.createToken(.comma),
            '?' => self.createToken(.question_mark),
            '(' => self.createToken(.left_paren),
            ')' => self.createToken(.right_paren),
            '[' => self.createToken(.left_square),
            ']' => self.createToken(.right_square),
            '{' => self.createToken(.left_brace),
            '}' => self.createToken(.right_brace),
            '.' => self.createToken(if (self.match('.'))
                .until
            else
                .dot),

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
                if (self.isAlpha(self.buf[0..])) return self.identifier();
                return self.errorToken("Neznámý znak");
            },
        };
    }

    /// Posunout ukazatele
    fn advance(self: *Self) u8 {
        defer self.current += 1;
        return self.buf[self.current];
    }

    /// Zjistit znak na aktuálním ukazateli
    fn peek(self: *Self) u8 {
        if (self.isEof()) return '\x00';

        return self.buf[self.current];
    }

    /// Zjistit znak na následující pozici
    fn peekNext(self: *Self) u8 {
        if (self.current + 1 >= self.buf.len) return '\x00';
        return self.buf[self.current + 1];
    }

    /// Posunout ukazatele jestli je token jako očekávaný
    fn match(self: *Self, expected: u8) bool {
        if (self.isEof()) return false;
        if (self.buf[self.current] != expected) return false;

        _ = self.advance();
        return true;
    }

    /// Skenovat číslo do tokenu
    fn number(self: *Self) Token {
        while (isDigit(self.peek())) _ = self.advance();

        if (self.peek() == ',' and isDigit(self.peekNext())) {
            _ = self.advance();

            while (isDigit(self.peek())) _ = self.advance();
        }

        return self.createToken(.number);
    }

    /// Skenovat hexadecimální číslo do tokenu
    fn hexadecimal(self: *Self) Token {
        while (isHexa(self.peek())) {
            _ = self.advance();
        }

        return self.createToken(.hexadecimal);
    }

    /// Skenovat oktální číslo do tokenu
    fn octal(self: *Self) Token {
        while (isOctal(self.peek())) {
            _ = self.advance();
        }

        return self.createToken(.octal);
    }

    /// Skenovat binární číslo do tokenu
    fn binary(self: *Self) Token {
        while (self.peek() == '1' or self.peek() == '0') {
            _ = self.advance();
        }

        return self.createToken(.binary);
    }

    /// Skenovat string do tokenu
    fn string(self: *Self, isMultiline: bool) Token {
        const deli: u8 = if (isMultiline) '"' else '\'';
        var hadMultilineError = false;

        switch (deli) {
            '\'' => {
                while (!self.isEof() and self.delimeter(deli)) {
                    if (self.peek() == '\n') {
                        hadMultilineError = true;
                    }
                    _ = self.advance();
                }
            },
            '"' => {
                while (!self.isEof() and self.delimeter(deli)) {
                    if (self.peek() == '\n') self.location.line += 1;
                    _ = self.advance();
                }
            },
            else => unreachable,
        }

        if (self.isEof()) return self.errorToken("Neukončený string");

        _ = self.advance();

        if (hadMultilineError) return self.errorToken(
            "String obalen v \" nemůže být víceřádkový, použijte \'",
        );

        return self.createToken(.string);
    }

    /// Aby se neukončil řetězec při escapování sekvence začátku řetězce
    fn delimeter(self: *Self, deli: u8) bool {
        if (self.buf[self.current - 1] == '\\' and self.buf[self.current] == deli) {
            return true;
        }

        if (self.buf[self.current] == deli) {
            return false;
        }

        return true;
    }

    /// Skenovat identifikátor
    fn identifier(self: *Self) Token {
        while (!self.isEof() and (self.isAlpha(self.buf[self.current..]) or isDigit(self.peek()))) {
            _ = self.advance();
        }

        return self.createToken(self.identifierOrKeyword());
    }

    /// Vytvořit token s errorem
    fn errorToken(self: Self, message: []const u8) Token {
        return .{
            .type = .chyba,
            .lexeme = self.buf[0..self.current],
            .location = Location.init(
                self.location.line,
                self.location.start_column,
                self.location.end_column,
            ),
            .message = message,
        };
    }

    /// Získat typ tokenu, buď identifikátor nebo klíčové slovo
    fn identifierOrKeyword(self: *Self) _token.Type {
        const lexeme = self.buf[0..self.current];

        const isKeyword = _token.Keywords.get(lexeme);
        return if (isKeyword) |keyword|
            keyword
        else
            .identifier;
    }

    /// Přeskočit prázdné místo
    fn skipWhiteSpace(self: *Self) void {
        while (true) {
            const char = self.peek();

            switch (char) {
                '\n' => {
                    self.location.line += 1;
                    self.location.end_column = 0;
                    _ = self.advance();
                },
                ' ', '\r' => {
                    self.location.end_column += 1;
                    _ = self.advance();
                },
                '\t' => {
                    self.location.end_column += 4;
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
                            // skip /*
                            _ = self.advance();
                            _ = self.advance();
                            while ((self.peek() != '*' or self.peekNext() != '/') and !self.isEof()) {
                                _ = self.advance();
                            }
                            // skip */
                            _ = self.advance();
                            _ = self.advance();
                        },
                        else => return,
                    }
                },
                else => return,
            }
        }
    }

    /// Přeskočit znaky
    fn skipSpace(self: *Self, space: u8) void {
        self.buf = self.buf[space..];
        self.current -= space;
    }

    /// Je ukazatel na konci souboru
    fn isEof(self: Self) bool {
        return self.buf.len <= self.current;
    }

    /// Vytvořit token dle typu
    fn createToken(self: *Self, token_type: _token.Type) Token {
        const lexeme = self.buf[0..self.current];
        self.location.end_column += lexeme.len;
        return Token{
            .type = token_type,
            .lexeme = self.buf[0..self.current],
            .location = Location.init(
                self.location.line,
                self.location.start_column,
                self.location.end_column,
            ),
        };
    }

    /// Resetovat ukazatele
    fn resetPointers(self: *Self) void {
        self.buf = self.buf[self.current..];
        self.current = 0;
        self.location.start_column = self.location.end_column + 1;
    }

    /// Je znak písmeno či '_'
    fn isAlpha(self: *Self, buff: []const u8) bool {
        if (!std.unicode.utf8ValidateSlice(buff)) return false;
        const str = Util.longestApprovedAlphabeticGrapheme(buff) orelse {
            const len = Util.nonAllowedLenght(buff);
            self.current += len;
            return false;
        };
        if (str.len > 1) {
            self.current += str.len - 1;
        }
        return true;
    }
};

/// Je znak hexadecimální
fn isHexa(c: u8) bool {
    return switch (c) {
        '0'...'9', 'A'...'F', 'a'...'f' => true,
        else => false,
    };
}

/// Je znak oktální
fn isOctal(c: u8) bool {
    return switch (c) {
        '0'...'7' => true,
        else => false,
    };
}

/// Testování scanneru
fn testScanner(source: []const u8, types: []const _token.Type) !void {
    var scanner: Scanner = Scanner.init(source);
    for (types) |token_type| {
        const token: Token = scanner.scan();
        try std.testing.expectEqual(token_type, token.type);
    }
    const last_token: Token = scanner.scan();
    try std.testing.expectEqual(last_token.type, .eof);
}

test "variable" {
    try testScanner("prm k = 3; .k = 4;", &.{
        .prm,
        .identifier,
        .assign,
        .number,
        .semicolon,
        .dot,
        .identifier,
        .assign,
        .number,
        .semicolon,
    });
    try testScanner("konst PI;", &.{
        .konst,
        .identifier,
        .semicolon,
    });
}

test "if" {
    try testScanner("pokud 2 > 1: {}", &.{
        .pokud,
        .number,
        .greater,
        .number,
        .colon,
        .left_brace,
        .right_brace,
    });
    try testScanner("pokud ne: {} jinak {}", &.{
        .pokud,
        .ne,
        .colon,
        .left_brace,
        .right_brace,
        .jinak,
        .left_brace,
        .right_brace,
    });
}

test "number" {
    try testScanner("3,14; 5,25; 25;", &.{
        .number,
        .semicolon,
        .number,
        .semicolon,
        .number,
        .semicolon,
    });
    try testScanner("0xFF00FF", &.{.hexadecimal});
    try testScanner("0b001", &.{.binary});
}

test "binary" {
    try testScanner(".a & .b", &.{
        .dot,
        .identifier,
        .bw_and,
        .dot,
        .identifier,
    });
    try testScanner(".a | .b", &.{
        .dot,
        .identifier,
        .bw_or,
        .dot,
        .identifier,
    });
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
    try testScanner("opakuj 0..4 jako .j: {}", &.{
        .opakuj,
        .number,
        .until,
        .number,
        .jako,
        .dot,
        .identifier,
        .colon,
        .left_brace,
        .right_brace,
    });
    try testScanner("opakuj 9..3 jako .var: tiskni .var;", &.{
        .opakuj,
        .number,
        .until,
        .number,
        .jako,
        .dot,
        .identifier,
        .colon,
        .tiskni,
        .dot,
        .identifier,
        .semicolon,
    });
}

test "while loop" {
    try testScanner("dokud .i >= 10: {}", &.{
        .dokud,
        .dot,
        .identifier,
        .greater_equal,
        .number,
        .colon,
        .left_brace,
        .right_brace,
    });
    try testScanner("dokud ano: { pokud .i == 10: {pokracuj;}}", &.{
        .dokud,
        .ano,
        .colon,
        .left_brace,
        .pokud,
        .dot,
        .identifier,
        .equal,
        .number,
        .colon,
        .left_brace,
        .pokracuj,
        .semicolon,
        .right_brace,
        .right_brace,
    });
}
