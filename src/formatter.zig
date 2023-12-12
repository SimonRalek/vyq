const std = @import("std");
pub inline fn escapeFmt(string: []const u8) EscapeFmt {
    return .{ .string = string };
}
const EscapeFmt = struct {
    string: []const u8,

    pub fn format(
        self: EscapeFmt,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        var start: usize = 0;
        while (true) {
            const end = std.mem.indexOfScalarPos(u8, self.string, start, '\\') orelse self.string.len;
            try writer.writeAll(self.string[start..end]);
            if (end == self.string.len) break;
            if (end + 1 == self.string.len) @panic("Bad ending escape");
            start = end + 2;
            switch (self.string[end + 1]) {
                'n' => try writer.writeByte('\n'),
                't' => try writer.writeByte('\t'),
                'r' => try writer.writeByte('\r'),
                '\"' => try writer.writeByte('\"'),
                '\'' => try writer.writeByte('\''),
                '\\' => try writer.writeByte('\\'),
                else => |c| try writer.writeAll(&[_]u8{ '\\', c }),
            }
        }
    }
};

fn testFormatter(expected: []const u8, source: []const u8) !void {
    var arrlist = std.ArrayList(u8).init(std.testing.allocator);
    defer arrlist.deinit();
    var writer = arrlist.writer();
    try escapeFmt(source).format(writer);

    var res = try arrlist.toOwnedSlice();

    try std.testing.expectEqualSlices(u8, expected, res);
    std.testing.allocator.free(res);
}

test {
    try testFormatter("New line\n", "New line\\n");
    try testFormatter("Tab\t or R\r", "Tab\\t or R\\r");
    try testFormatter("Normal \\p \\w \\v \\l", "Normal \\p \\w \\v \\l");
    try testFormatter("'New \'string\''", "'New \\'string\\''");
}
