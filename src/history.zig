const std = @import("std");
const Allocator = std.mem.Allocator;
const Keywords = @import("token.zig").Keywords;

fn isBoundary(char: u8) bool {
    switch (char) {
        ' ', '\t', '\r', '\n', '.', ',', ';', ':', '!', '?', '=' => return true,
        else => return false,
    }
}

// const arr = Keywords.kvs;
// var result = std.ArrayList([]const u8).init(alloc);
// defer result.deinit();
// var res = std.ArrayList(u8).init(alloc);
// defer res.deinit();
//
// for (0..buf.len) |i| {
//     if (!isBoundary(buf[buf.len - i - 1])) {
//         try res.append(buf[buf.len - i - 1]);
//     } else {
//         break;
//     }
// }
//
// const buff = res.toOwnedSlice() catch @panic("");
// std.mem.reverse(u8, buff);
//
// if (buff.len != 0) {
//     for (0..arr.len) |i| {
//         if (std.mem.startsWith(u8, arr[i].key, buff)) {
//             const conc = try std.mem.concat(alloc, u8, &.{ buf[0..buf.len -| buff.len], arr[i].key });
//             try result.append(try alloc.dupe(u8, conc));
//         }
//     }
// }
//
// return if (result.items.len != 0) result.toOwnedSlice() else &[_][]const u8{};
