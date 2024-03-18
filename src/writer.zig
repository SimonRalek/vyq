const std = @import("std");

const WriteErr = error{};
const WriteFn = *const fn (bytes: []const u8) void;
pub const VMWriter = WasmWriter.Writer;

pub const WasmWriter = struct {
    pub const Self = @This();
    pub const Writer = std.io.Writer(Self, WriteErr, write);

    writeFn: WriteFn,

    pub fn init(writeFn: WriteFn) Self {
        return .{ .writeFn = writeFn };
    }

    pub fn write(self: Self, bytes: []const u8) WriteErr!usize {
        self.writeFn(bytes);
        return bytes.len;
    }

    pub fn writer(self: Self) Writer {
        return .{ .context = self };
    }
};
