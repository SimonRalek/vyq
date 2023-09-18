const std = @import("std");
const Allocator = std.mem.Allocator;

const Scanner = @import("scanner.zig").Scanner;
const Token = @import("token.zig").Token;

pub const Compiler = struct {
    pub fn compile(allocator: Allocator, source: []const u8) !void {
        _ = allocator;
        var scanner = Scanner.init(source);
        _ = scanner;
        // var line: u32 = 0;
        // while (true) {
        //     var token: Token = scanner.scan();
        //     if (token.line != line) {
        //         std.debug.print("{} ", .{token.line});
        //         line = token.line;
        //     } else {
        //         std.debug.print(" | ", .{});
        //     }
        //
        //     std.debug.print("{s} {} {s}\n", .{ @tagName(token.type), token.lexeme.len, token.lexeme });
        //
        //     if (token.type == .eof) break;
        // }
    }
};
