const std = @import("std");
const Allocator = std.mem.Allocator;
const Keywords = @import("token.zig").Keywords;

// Doplnění v REPL (jen v linuxu)
pub fn completion(text: ?[*:0]const u8, start: c_int, end: c_int) callconv(.C) ?[*:null]?[*:0]u8 {
    _ = end;
    _ = start;

    const alloc = std.heap.raw_c_allocator;
    const arr = Keywords.kvs;
    var result = std.ArrayList(?[*:0]u8).init(alloc);

    const buf = std.mem.span(text) orelse @panic("");

    for (arr) |kv| {
        if (std.mem.startsWith(u8, kv.key, buf)) {
            const duped = alloc.dupeZ(u8, kv.key) catch @panic("");
            result.append(duped.ptr) catch @panic("");
        }
    }

    const ownedSlice = result.toOwnedSliceSentinel(null) catch @panic("");
    return if (ownedSlice.len != 0) ownedSlice.ptr else null;
}
