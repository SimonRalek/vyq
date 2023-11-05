const std = @import("std");
const builtin = @import("builtin");

extern "kernel32" fn SetConsoleCP(wCodePageID: std.os.windows.UINT) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub fn main() !void {
    // if (builtin.os.tag == .windows) {
    //     std.debug.assert(SetConsoleCP(65001) != 0);
    //     std.debug.assert(std.os.windows.kernel32.SetConsoleOutputCP(65001) != 0);
    // }

    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();

    var input_buf: [512]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&input_buf, '\n')) |input| {
        try stdout.writeAll(input);
        try stdout.writeAll("\n");
    }
}
