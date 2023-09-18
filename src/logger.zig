const std = @import("std");
const shared = @import("shared.zig");
const time = @import("lib/time.zig");

const Dir = std.fs.Dir;
const File = std.fs.File;
const Allocator = std.mem.Allocator;

const Level = enum {
    err,
    info,
    warn,

    fn toText(self: Level) []const u8 {
        switch (self) {
            .err => return "Error => ",
            .info => return "Info => ",
            .warn => return "Warn => ",
        }
    }
};

pub const Logger = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Logger {
        return .{ .allocator = allocator };
    }

    pub fn log(self: *Logger, comptime message: []const u8, level: Level) !void {
        const dir: Dir = try std.fs.cwd().openDir("logs", .{});
        const datetime = time.DateTime.initUnixMs(@intCast(std.time.milliTimestamp()));
        const now = try datetime.formatAlloc(self.allocator, "DD.MM.YY HH:mm:ss ");
        defer self.allocator.free(now);

        const concat = try std.mem.concat(self.allocator, u8, &.{ now, level.toText(), message ++ "\n" });
        defer self.allocator.free(concat);

        const file: File = try dir.openFile("log", .{ .mode = .write_only });
        defer file.close();

        try file.seekFromEnd(0);

        _ = try file.write(concat);
    }

    pub fn err(self: *Logger, comptime message: []const u8, args: anytype) !void {
        try log(self, message, .err);
        try shared.stdout.print(message, args);
    }

    pub fn info(self: *Logger, comptime message: []const u8, args: anytype) !void {
        try log(self, message, .info);
        try shared.stdout.print(message, args);
    }

    pub fn warn(self: *Logger, comptime message: []const u8, args: anytype) !void {
        try log(self, message, .warn);
        try shared.stdout.print(message, args);
    }
};
