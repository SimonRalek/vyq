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
};

pub const Item = struct { location: *Token, kind: Kind = .err, message: []const u8 };

pub const Report = struct {
    const Self = @This();

    items: []const Item,
    type: ResultError,
    message: []const u8,

    pub fn report(self: Self) !void {
        const item = self.items[0];

        try shared.logger.err("{s}: ", .{item.kind.name()});
        try shared.logger.err("{s} ", .{self.message});

        switch (item.location.type) {
            .eof => {
                try shared.logger.err("na konci", .{});
            },
            .chyba => {},
            else => {
                try shared.logger.err("v '{s}'", .{item.location.lexeme});
            },
        }

        try shared.logger.err(", řádka {}:{} \n", .{ item.location.line, item.location.column });
        // const first = self.items[0];
        // _ = first;
        //
        // try shared.stdout.print("", .{});
        //
        // for (self.items) |item| {
        //     _ = item;
        // }
    }
};

pub fn report(self: *Reporter, err_type: ResultError, token: *Token, message: []const u8) void {
    if (self.panic_mode) {
        return;
    }

    self.panic_mode = true;
    self.had_error = true;

    const rep = Report{ .message = message, .type = err_type, .items = &.{.{ .location = token, .message = message }} };

    rep.report() catch {};
}
