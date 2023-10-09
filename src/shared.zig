const std = @import("std");
const builtin = @import("builtin");

const Logger = @import("logger.zig").Logger;

pub const ResultError = error{ parser, compile, runtime };

pub const version = "0.0.1"; // TODO should take version from git

pub const stdout = switch (builtin.os.tag) {
    .windows => struct {
        pub fn print(comptime message: []const u8, args: anytype) !void {
            try std.io.getStdOut().writer().print(message, args);
        }
    },
    else => std.io.getStdOut().writer(),
};

pub var logger: Logger = undefined;
pub fn initLogger(allocator: std.mem.Allocator) !void {
    logger = Logger.init(allocator);
}
