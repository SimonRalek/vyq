const std = @import("std");

const longestApprovedAlphabeticGrapheme = @import("utils/czechEncode.zig").longestApprovedAlphabeticGrapheme;

const TType = enum { eof, something, err };
const Token = struct { type: TType, lexeme: []const u8 };

pub const Scanner = struct {
    buff: []const u8,
    current: usize,

    pub fn init(source: []const u8) Scanner {
        return .{ .buff = source, .current = 0 };
    }

    pub fn scan(self: *Scanner) Token {
        if (self.isAtEnd()) return createToken(.eof);

        self.buff = self.buff[self.current..];
        self.current = 0;

        const char = self.buff[self.current];
        _ = self.advance();

        return switch (char) {
            '+' => createToken(.something), // make + token
            '-' => createToken(.something), // make - token
            ';' => createToken(.something), // make ; token
            else => {
                if (self.isAlpha(self.buff[self.current..])) return self.makeIdentifier();
                return errorToken("Unknow char");
            },
        };
    }

    fn advance(self: *Scanner) u8 {
        defer self.current += 1;
        std.debug.print("{s}\n", .{self.buff[self.current..]});
        return self.buff[self.current];
    }

    fn isAlpha(self: *Scanner, buff: []const u8) bool {
        if (!std.unicode.utf8ValidateSlice(buff)) return false;
        var string = longestApprovedAlphabeticGrapheme(buff) orelse return false;
        if (string.len > 1) {
            self.current += string.len - 1;
        }
        return true;
    }

    fn makeIdentifier(self: *Scanner) Token {
        return .{ .type = .something, .lexeme = self.buff[0..self.current] };
    }

    fn errorToken(msg: []const u8) Token {
        return .{ .type = .err, .lexeme = msg };
    }

    fn createToken(ttype: TType) Token {
        return .{ .lexeme = "", .type = ttype };
    }

    fn isAtEnd(self: *Scanner) bool {
        return self.buff.len <= self.current;
    }
};

pub fn main() !void {
    var scanner = Scanner.init("ࢸ;");

    while (true) {
        var token = scanner.scan();
        if (token.type == .eof) break;
    }
}
