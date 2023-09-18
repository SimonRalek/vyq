const std = @import("std");
const Logger = @import("logger.zig").Logger;

pub const ResultError = error{ compile, runtime };

pub const version = "0.0.1";

pub const stdout = std.io.getStdOut().writer();
pub const stdin = std.io.getStdIn().reader();
pub const stderr = std.io.getStdErr().writer();
pub var logger: Logger = undefined;

pub fn initLogger(allocator: std.mem.Allocator) !void {
    logger = Logger.init(allocator);
}
