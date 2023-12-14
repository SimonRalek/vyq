const std = @import("std");
const shared = @import("shared.zig");
const Allocator = std.mem.Allocator;
const Color = std.io.tty.Color;

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

pub fn init(allocator: Allocator) Reporter {
    return .{ .allocator = allocator };
}

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

    pub fn getColor(self: Self) Color {
        return switch (self) {
            .err => .red,
            .warn => .yellow,
            .hint => .blue,
        };
    }
};

pub const Item = struct {
    token: ?*Token = null,
    kind: Kind = .err,
    message: []const u8,
};

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

    /// Report pro kompilační chyby
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
                    "v '{}'\n",
                    .{std.zig.fmtEscapes(self.item.token.?.lexeme)},
                );
            },
        }

        // try self.getSource(self.item.token.?.location);
    }

    /// Report pro runtime chyby
    fn reportRuntime(self: *Self, loc: Location) !void {
        _ = loc;
        try shared.stdout.print("\"{s}\"\n", .{self.item.message});

        // TODO callstack
        try self.printNotes();
        // try self.getSource(loc);
    }

    fn getSource(self: *Self, loc: Location) !void {
        var it = std.mem.splitSequence(u8, self.reporter.source, "\n");

        var count: usize = 1;
        while (it.next()) |line| : (count += 1) {
            if (count == loc.line) {
                // try shared.stdout.print("\n  {s}\n", .{if (line.len > 10) line[(if (loc.start_column > 4) loc.start_column - 4 else 0)..if (loc.end_column + 5 < line.len) loc.end_column + 5 else line.len] else line});
                try shared.stdout.print("{s}", .{line});

                for (0..loc.start_column - 1) |_| {
                    try shared.stdout.print(" ", .{});
                }

                for (loc.start_column..loc.end_column + 1) |_| {
                    const stdout = std.io.getStdOut();
                    var config = std.io.tty.detectConfig(stdout);
                    try config.setColor(stdout, .green);
                    try stdout.writer().print("^", .{});
                    try config.setColor(stdout, .reset);
                }

                try shared.stdout.print("\n\n", .{});

                break;
            }
        }
    }

    /// Vytisknout poznámky
    fn printNotes(self: *Self) !void {
        for (self.notes) |note| {
            var stdout = std.io.getStdOut();
            const config = std.io.tty.detectConfig(stdout);
            if (!self.reporter.nocolor)
                try config.setColor(stdout, note.kind.getColor());
            try stdout.writer().print(
                "poznámka",
                .{},
            );
            if (!self.reporter.nocolor)
                try config.setColor(stdout, .reset);
            try shared.stdout.print(": {s}\n", .{note.message});
        }
    }

    /// Vytisknout zprávu
    fn report(self: *Self, loc: Location) !void {
        try shared.stdout.print("{s}:{}:{} ", .{
            self.reporter.file,
            loc.line,
            loc.end_column,
        });
        var stdout = std.io.getStdOut();
        var config = std.io.tty.detectConfig(stdout);
        if (!self.reporter.nocolor)
            try config.setColor(stdout, self.item.kind.getColor());
        try stdout.writer().print("{s}: ", .{
            self.item.kind.name(),
        });
        if (!self.reporter.nocolor)
            try config.setColor(stdout, .reset);

        switch (self.type.?) {
            ResultError.runtime => {
                try self.reportRuntime(loc);
            },
            ResultError.parser => {
                try self.reportCompile();
            },
            else => unreachable,
        }
    }
};

/// Report při parsování
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

/// Report při běhu programu
pub fn reportRuntime(self: *Reporter, message: []const u8, notes: []const Note, loc: Location) void {
    var rep = Report{
        .reporter = self,
        .type = ResultError.runtime,
        .item = .{ .message = message },
        .notes = notes,
    };
    rep.report(loc) catch @panic("Nepodařilo se hodnotu vypsat");
}

/// Varování
pub fn warn(self: *Reporter, token: *Token, message: []const u8) void {
    var rep = Report{
        .reporter = self,
        .type = ResultError.parser,
        .item = .{ .kind = .warn, .token = token, .message = message },
        .notes = &.{},
    };
    rep.report(token.location) catch {};
}

///
pub fn printErr(
    comptime message: []const u8,
    args: anytype,
) !void {
    const stdout = std.io.getStdOut();
    const config = std.io.tty.detectConfig(stdout);
    try config.setColor(stdout, .red);
    try stdout.writer().print("Chyba", .{});
    try config.setColor(stdout, .reset);
    try stdout.writer().print(": ", .{});
    try shared.stdout.print(message ++ "\n", args);
}
