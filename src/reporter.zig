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

pub const Item = struct { location: ?*Token = null, kind: Kind = .err, message: []const u8 };
pub const Note = struct { message: []const u8, kind: Kind = .hint };

pub const Report = struct {
    const Self = @This();

    item: Item,
    type: ?ResultError,
    notes: []const Note,

    /// Report pro kompilační chyby
    pub fn reportCompile(self: *Self) !void {
        try self.report();

        switch (self.item.location.?.type) {
            .eof => {
                try shared.stdout.print("na konci", .{});
            },
            .chyba => {
                try shared.stdout.print("'{s}'", .{self.item.location.?.lexeme});
            },
            else => {
                try shared.stdout.print("v '{}'", .{std.zig.fmtEscapes(self.item.location.?.lexeme)});
            },
        }

        try shared.stdout.print(", řádka {}:{} \n", .{ self.item.location.?.line, self.item.location.?.column });
    }

    /// Report pro runtime chyby
    pub fn reportRuntime(self: *Self, line: u32) !void {
        try self.report();

        try shared.stdout.print("na řádce {} ve skriptu\n", .{line});
        try self.printNotes();
    }

    /// Vytisknout poznámky
    fn printNotes(self: *Self) !void {
        for (self.notes) |note| {
            try shared.stdout.print("\x1b[{}mpoznámka\x1b[m", .{note.kind.getColor()});
            try shared.stdout.print(": {s}\n", .{note.message});
        }
    }

    /// Vytisknout zprávu
    fn report(self: *Self) !void {
        try shared.stdout.print("\x1b[{}m{s}\x1b[m: ", .{ self.item.kind.getColor(), self.item.kind.name() });
        try shared.stdout.print("{s} ", .{self.item.message});
    }
};

/// Report při parsování
pub fn report(self: *Reporter, err_type: ResultError, token: *Token, message: []const u8) void {
    if (self.panic_mode) {
        return;
    }

    self.panic_mode = true;
    self.had_error = true;

    var rep = Report{ .type = err_type, .item = .{ .location = token, .message = message }, .notes = &.{} };

    rep.reportCompile() catch {};
}

/// Varování
pub fn warn(self: *Reporter, token: *Token, message: []const u8) void {
    _ = self;
    var rep = Report{ .type = null, .item = .{ .kind = .warn, .location = token, .message = message }, .notes = &.{} };

    rep.reportCompile() catch {};
}
