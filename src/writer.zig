const std = @import("std");

pub const ExternalWriter = struct {
    pub const WriteFnType = *const fn (bytes: []const u8) void;

    writeFn: WriteFnType,

    pub fn init(writeFn: WriteFnType) ExternalWriter {
        return ExternalWriter{ .writeFn = writeFn };
    }

    pub const WriteError = error{};

    pub fn write(self: ExternalWriter, bytes: []const u8) WriteError!usize {
        self.writeFn(bytes);
        return bytes.len;
    }

    pub const Writer = std.io.Writer(ExternalWriter, WriteError, write);

    pub fn writer(self: ExternalWriter) Writer {
        return .{ .context = self };
    }
};

pub const VMWriter = ExternalWriter.Writer;
