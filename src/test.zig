const std = @import("std");

pub fn main() !void {
    const color = 34;
    std.debug.print("\x1b{}mtest test", .{color});
}
