const std = @import("std");

pub fn main() !void {
    var k: i128 = 3;
    var l: i128 = 3;
    var v = l << k;

    std.debug.print("{d}\n", .{v});
}
