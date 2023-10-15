const std = @import("std");
const builtin = @import("builtin");

pub const ResultError = error{ parser, compile, runtime };

pub const stdout = switch (builtin.os.tag) {
    .windows => struct {
        pub fn print(comptime message: []const u8, args: anytype) !void {
            try std.io.getStdOut().writer().print(message, args);
        }
    },
    else => std.io.getStdOut().writer(),
};
