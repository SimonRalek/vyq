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
            if (end + 1 == self.string.len) @panic("Bad ending escape"); // <- should probably do validation on the string before formatting
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
