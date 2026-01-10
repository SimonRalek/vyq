const std = @import("std");
const builtin = @import("builtin");
const shared = @import("shared.zig");
const Allocator = std.mem.Allocator;

const Token = @import("token.zig").Token;
const Location = @import("scanner.zig").Location;
const ResultError = shared.ResultError;

const Reporter = @This();

allocator: Allocator,
had_error: bool = false,
panic_mode: bool = false,
file: []const u8 = undefined,
source: []const u8 = undefined,
nocolor: bool = false,
is_wasm: bool = false,

/// Init reporteru
pub fn init(allocator: Allocator) Reporter {
    return .{ .allocator = allocator };
}

/// Resetování hodnot
pub fn reset(self: *Reporter) void {
    self.had_error = false;
    self.panic_mode = false;
}

pub const Kind = enum {
    const Self = @This();

    err,
    warn,
    hint,

    /// Získat jméno
    pub fn name(self: Self) []const u8 {
        return switch (self) {
            .err => "Chyba",
            .warn => "Varování",
            .hint => "Poznámka",
        };
    }

    /// Získat barvu
    pub fn getAnsiColor(self: Self) []const u8 {
        return switch (self) {
            .err => "\x1b[31m", // Red
            .warn => "\x1b[33m", // Yellow
            .hint => "\x1b[34m", // Blue
        };
    }
};

/// Položka zprávy
pub const Item = struct {
    token: ?*Token = null,
    kind: Kind = .err,
    message: []const u8,
};

/// Poznámka (u runtime)
pub const Note = struct {
    message: []const u8,
    kind: Kind = .hint,
};

pub const Report = struct {
    const Self = @This();

    reporter: *Reporter = undefined,
    item: Item,
    type: ?ResultError = null,
    notes: []const Note,

    fn reportCompile(self: *Self) !void {
        try shared.stdout.print("\"{s}\"\n - ", .{self.item.message});

        switch (self.item.token.?.type) {
            .eof => {
                try shared.stdout.print("na konci\n", .{});
            },
            .chyba => {
                try shared.stdout.print(
                    "'{s}'\n",
                    .{self.item.token.?.lexeme},
                );
            },
            else => {
                try shared.stdout.print(
                    "v '{s}'\n",
                    .{self.item.token.?.lexeme},
                );
            },
        }
        if (!shared.isFreestanding() and self.item.token.?.type != .eof) {
            try self.getSource(self.item.token.?);
        }
    }

    fn reportRuntime(self: *Self) !void {
        try shared.stdout.print("\"{s}\"\n", .{self.item.message});
        try self.printNotes();
    }

    fn getSource(self: *Self, token: *Token) !void {
        const source = self.reporter.source;
        const token_start = @intFromPtr(token.lexeme.ptr) - @intFromPtr(source.ptr);
        const token_len = token.lexeme.len;
        const token_end = token_start + token_len;

        // Find line start
        var line_start: usize = 0;
        if (token_start > 0) {
            if (std.mem.lastIndexOfScalar(u8, source[0..token_start], '\n')) |idx| {
                line_start = idx + 1;
            }
        }

        // Find line end
        var line_end: usize = source.len;
        if (std.mem.indexOfScalar(u8, source[token_end..], '\n')) |idx| {
            line_end = token_end + idx;
        }

        const line = source[line_start..line_end];
        const count = token.location.line;

        // Offsets relative to line
        const start_idx = token_start - line_start;
        const end_idx = token_end - line_start;

        if (!shared.isFreestanding() and !self.reporter.nocolor) {
            // Calculate visual width of the line prefix (e.g. "12: ")
            const line_digits = if (count == 0) 1 else std.math.log10_int(count) + 1;
            const prefix_width = line_digits + 2;

            try shared.stdout.print("\x1b[2m{}: {s}\n\x1b[0m", .{ count, line });

            // Visual width before token
            const pre_slice = line[0..start_idx];
            var pre_width: usize = 0;
            var pre_it = std.unicode.Utf8View.initUnchecked(pre_slice).iterator();
            while (pre_it.nextCodepoint()) |cp| {
                if (cp == '\t') pre_width += 4 else pre_width += 1;
            }

            for (0..(prefix_width + pre_width)) |_| {
                try shared.stdout.print(" ", .{});
            }

            try shared.stdout.print("\x1b[32m", .{}); // Green

            // Visual width of token
            const token_slice = line[start_idx..end_idx];
            var token_width: usize = 0;
            var token_it = std.unicode.Utf8View.initUnchecked(token_slice).iterator();
            while (token_it.nextCodepoint()) |cp| {
                if (cp == '\t') token_width += 4 else token_width += 1;
            }
            if (token_width == 0) token_width = 1;

            for (0..token_width) |_| {
                try shared.stdout.print("^", .{});
            }
            try shared.stdout.print("\x1b[0m\n", .{});
        } else {
            // Plain text version
            const line_digits = if (count == 0) 1 else std.math.log10_int(count) + 1;
            const prefix_width = line_digits + 2;

            try shared.stdout.print(" {}: {s}\n", .{ count, line });

            const pre_slice = line[0..start_idx];
            var pre_width: usize = 0;
            var pre_it = std.unicode.Utf8View.initUnchecked(pre_slice).iterator();
            while (pre_it.nextCodepoint()) |cp| {
                if (cp == '\t') pre_width += 4 else pre_width += 1;
            }

            for (0..(prefix_width + pre_width)) |_| {
                try shared.stdout.print(" ", .{});
            }

            const token_slice = line[start_idx..end_idx];
            var token_width: usize = 0;
            var token_it = std.unicode.Utf8View.initUnchecked(token_slice).iterator();
            while (token_it.nextCodepoint()) |cp| {
                if (cp == '\t') token_width += 4 else token_width += 1;
            }
            if (token_width == 0) token_width = 1;

            for (0..token_width) |_| {
                try shared.stdout.print("^", .{});
            }
            try shared.stdout.print("\n", .{});
        }
    }

    fn printNotes(self: *Self) !void {
        for (self.notes) |note| {
            if (!shared.isFreestanding()) {
                if (!self.reporter.nocolor) {
                    try shared.stdout.print("{s}poznámka\x1b[0m: {s}\n", .{ note.kind.getAnsiColor(), note.message });
                } else {
                    try shared.stdout.print("poznámka: {s}\n", .{note.message});
                }
            } else {
                try shared.stdout.print("poznámka", .{});
                try shared.stdout.print(": {s}\n", .{note.message});
            }
        }
    }

    fn report(self: *Self, loc: Location) !void {
        try shared.stdout.print("{s}:{}:{} ", .{
            self.reporter.file,
            loc.line,
            loc.end_column,
        });

        if (!shared.isFreestanding()) {
            if (!self.reporter.nocolor) {
                try shared.stdout.print("{s}{s}: \x1b[0m", .{
                    self.item.kind.getAnsiColor(),
                    self.item.kind.name(),
                });
            } else {
                try shared.stdout.print("{s}: ", .{self.item.kind.name()});
            }
        } else {
            try shared.stdout.print("{s}: ", .{self.item.kind.name()});
        }

        switch (self.type.?) {
            ResultError.runtime => {
                try self.reportRuntime();
            },
            ResultError.parser => {
                try self.reportCompile();
            },
            else => unreachable,
        }
    }

    fn reportGeneral(self: *Self) !void {
        try shared.stdout.print("{s} ", .{
            self.reporter.file,
        });

        if (!shared.isFreestanding()) {
            if (!self.reporter.nocolor) {
                try shared.stdout.print("{s}{s}: \x1b[0m{s}\n", .{ self.item.kind.getAnsiColor(), self.item.kind.name(), self.item.message });
            } else {
                try shared.stdout.print("{s}: {s}\n", .{ self.item.kind.name(), self.item.message });
            }
        } else {
            try shared.stdout.print("{s}: ", .{self.item.kind.name()});
            try shared.stdout.print("{s}\n", .{self.item.message});
        }
    }
};

pub fn report(
    self: *Reporter,
    err_type: ResultError,
    token: *Token,
    message: []const u8,
) void {
    if (self.panic_mode) {
        return;
    }

    self.panic_mode = true;
    self.had_error = true;

    var rep = Report{
        .reporter = self,
        .type = err_type,
        .item = .{ .token = token, .message = message },
        .notes = &.{},
    };
    rep.report(token.location) catch @panic("Nepodařilo se hodnotu vypsat");
}

pub fn reportCompile(self: *Reporter, message: []const u8) void {
    if (self.had_error) return;

    var rep = Report{
        .reporter = self,
        .type = ResultError.compile,
        .item = .{ .message = message },
        .notes = &.{},
    };

    rep.reportGeneral() catch {};

    self.panic_mode = true;
    self.had_error = true;
}

pub fn reportRuntime(self: *Reporter, message: []const u8, notes: []const Note, loc: Location) void {
    var rep = Report{
        .reporter = self,
        .type = ResultError.runtime,
        .item = .{ .message = message },
        .notes = notes,
    };
    rep.report(loc) catch @panic("Nepodařilo se hodnotu vypsat");
}

pub fn warn(self: *Reporter, token: *Token, message: []const u8) void {
    var rep = Report{
        .reporter = self,
        .type = ResultError.parser,
        .item = .{ .kind = .warn, .token = token, .message = message },
        .notes = &.{},
    };
    rep.report(token.location) catch {};
}

pub fn printErr(
    self: *Reporter,
    comptime message: []const u8,
    args: anytype,
) !void {
    if (self.nocolor) {
        try shared.stdout.print("Chyba: ", .{});
        try shared.stdout.print(message ++ "\n", args);
    } else {
        try shared.stdout.print("\x1b[31mChyba:\x1b[0m ", .{});
        try shared.stdout.print(message ++ "\n", args);
    }
}
