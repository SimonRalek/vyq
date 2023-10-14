const std = @import("std");
const shared = @import("shared.zig");
const Allocator = std.mem.Allocator;

const Token = @import("token.zig").Token;
const ResultError = shared.ResultError;

const Reporter = @This();

allocator: Allocator,
had_error: bool = false,
panic_mode: bool = false,

pub const Kind = enum {
    const Self = @This();

    err,
    warn,
    hint,

    pub fn name(self: Self) []const u8 {
        return switch (self) {
            .err => "Chyba",
            .warn => "Varování",
            .hint => "Poznámka",
        };
    }

    pub fn getColor(self: Self) u8 {
        return switch (self) {
            .err => 31,
            .warn => 33,
            .hint => 34,
        };
    }
};

pub const Item = struct { location: *Token, kind: Kind = .err, message: []const u8 };

pub const Report = struct {
    const Self = @This();

    items: []const Item,
    type: ResultError,
    message: []const u8,

    pub fn report(self: Self) !void {
        const item = self.items[0];

        try shared.logger.err("\x1b[{}m{s}\x1b[m: ", .{ item.kind.getColor(), item.kind.name() });
        try shared.logger.err("{s} ", .{self.message});

        switch (item.location.type) {
            .eof => {
                try shared.logger.err("na konci", .{});
            },
            .chyba => {},
            else => {
                try shared.logger.err("v '{}'", .{std.zig.fmtEscapes(item.location.lexeme)});
            },
        }

        try shared.logger.err(", řádka {}:{} \n", .{ item.location.line, item.location.column });
    }
};

/// Report při parsování
pub fn report(self: *Reporter, err_type: ResultError, token: *Token, message: []const u8) void {
    if (self.panic_mode) {
        return;
    }

    self.panic_mode = true;
    self.had_error = true;

    const rep = Report{ .message = message, .type = err_type, .items = &.{.{ .location = token, .message = message }} };

    rep.report() catch {};
}
