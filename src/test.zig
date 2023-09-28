const std = @import("std");

pub fn main() !void {
    const val = 6.9;
    const ouput: i64 = @intFromFloat(val);
    std.debug.print("{any}", .{ouput});
}
