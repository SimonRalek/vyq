const std = @import("std");

const _scanner = @import("scanner.zig");
const Scanner = _scanner.Scanner;

pub const Token = struct {
    pub const Type = enum(u8) { left_paren, right_paren, left_brace, right_brace, comma, dot, minus, decrement, plus, increment, semicolon, slash, star, bang, not_equal, assign, equal, greater, greater_equal, less, less_equal, identifier, string, number, hexadecimal, binary, zaroven, nebo, tiskni, vrat, super, this, ano, ne, trida, jinak, opakuj, funkce, pokud, nic, prm, konst, dokud, eof, chyba, pokracuj, vlastni, colon, zastav, shift_right, shift_left, bw_and, bw_or, bw_xor, bw_not };
    pub const Keywords = std.ComptimeStringMap(Token.Type, .{ .{ "ano", .ano }, .{ "ne", .ne }, .{ "pokud", .pokud }, .{ "jinak", .jinak }, .{ "prm", .prm }, .{ "konst", .konst }, .{ "opakuj", .opakuj }, .{ "dokud", .dokud }, .{ "nic", .nic }, .{ "nebo", .nebo }, .{ "zaroven", .zaroven }, .{ "pokracuj", .pokracuj }, .{ "vlastni", .vlastni }, .{ "tiskni", .tiskni }, .{ "zastav", .zastav } });

    type: Type,
    lexeme: []const u8,
    line: u32,
    column: usize,
};
