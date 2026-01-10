const std = @import("std");
const Allocator = std.mem.Allocator;
const Keywords = @import("token.zig").Keywords;

// Doplnění v REPL (jen v linuxu)
pub fn completion(text_in: [*c]const u8, start: c_int, end: c_int) callconv(.c) [*c][*c]u8 {
    _ = end;
    _ = start;

    const alloc = std.heap.c_allocator;
    const arr = Keywords.keys();
    const buf = std.mem.span(text_in);
    var result = std.ArrayList([*c]u8){};

    for (arr) |key| {
        if (std.mem.startsWith(u8, key, buf)) {
            const duped = alloc.dupeZ(u8, key) catch @panic("Něco se nepodařilo, prosím zkuste znova");
            result.append(alloc, duped.ptr) catch @panic("Něco se nepodařilo, prosím zkuste znova");
        }
    }

    result.append(alloc, null) catch @panic("Něco se nepodařilo, prosím zkuste znova");

    const ownedSlice = result.toOwnedSlice(alloc) catch @panic("Něco se nepodařilo, prosím zkuste znova");

    if (ownedSlice.len > 1) {
        return @ptrCast(ownedSlice.ptr);
    } else {
        return null;
    }
}
