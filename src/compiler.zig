const std = @import("std");
const Allocator = std.mem.Allocator;

const Scanner = @import("scanner.zig").Scanner;
const Token = @import("token.zig").Token;
const Block = @import("block.zig").Block;

pub const Compiler = struct {
    const Self = @This();

    allocator: Allocator,
    block: *Block,

    pub fn init(block: *Block, allocator: Allocator) Self {
        return .{ .allocator = allocator, .block = block };
    }

    pub fn compile(source: []const u8) !void {
        var scanner = Scanner.init(source);
        var line: u32 = 0;
        while (true) {
            var token: Token = scanner.scan();
            if (token.line != line) {
                std.debug.print("{} ", .{token.line});
                line = token.line;
            } else {
                std.debug.print(" | ", .{});
            }

            std.debug.print("{s} {} {s}\n", .{ @tagName(token.type), token.lexeme.len, token.lexeme });

            if (token.type == .eof) break;
        }
    }

    pub fn getCurrentChunk(self: *Self) *Block {
        return self.block;
    }

    pub fn emitOpCode(self: *Self, op_code: Block.OpCode, line: u32) void {
        self.getCurrentChunk().writeOpCode(op_code, line) catch {};
    }
};
