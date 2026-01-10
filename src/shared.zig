const std = @import("std");
const builtin = @import("builtin");

pub const wasm = @import("wasm.zig");
pub const WasmWriter = @import("writer.zig").WasmWriter;

pub const ResultError = error{ parser, compile, runtime };
pub const IndexError = error{ negative_index, bigger_index, float_index };

/// Pro získání prostředku na výpis
pub const stdout = switch (builtin.os.tag) {
    .windows => struct {
        pub fn print(comptime message: []const u8, args: anytype) !void {
            const handle = std.os.windows.kernel32.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE);
            const file = std.fs.File{ .handle = handle.? };

            const NonClosingWriter = struct {
                file: std.fs.File,
                pub const Error = std.fs.File.WriteError;
                pub fn write(self: @This(), bytes: []const u8) Error!usize {
                    return self.file.write(bytes);
                }
            };

            const BufferedWriter = struct {
                unbuffered: NonClosingWriter,
                buffer: [4096]u8 = undefined,
                index: usize = 0,

                pub const Error = NonClosingWriter.Error;

                pub fn flush(self: *@This()) Error!void {
                    if (self.index == 0) return;
                    try self.unbuffered.file.writeAll(self.buffer[0..self.index]);
                    self.index = 0;
                }

                pub fn write(self: *@This(), bytes: []const u8) Error!usize {
                    if (self.index + bytes.len > self.buffer.len) {
                        try self.flush();
                        if (bytes.len > self.buffer.len) {
                            return self.unbuffered.write(bytes);
                        }
                    }
                    @memcpy(self.buffer[self.index..][0..bytes.len], bytes);
                    self.index += bytes.len;
                    return bytes.len;
                }

                fn writeFn(context: *@This(), bytes: []const u8) Error!usize {
                    return context.write(bytes);
                }

                pub const Writer = std.io.GenericWriter(*@This(), Error, writeFn);

                pub fn writer(self: *@This()) Writer {
                    return .{ .context = self };
                }
            };

            const nc_writer = NonClosingWriter{ .file = file };
            var buffered = BufferedWriter{ .unbuffered = nc_writer };
            try buffered.writer().print(message, args);
            try buffered.flush();
        }
    },
    .freestanding => WasmWriter.init(wasm.writeOutSlice).writer(),
    .wasi => WasmWriter.init(wasm.writeOutSlice).writer(),
    else => struct {
        pub fn print(comptime message: []const u8, args: anytype) !void {
            const file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
            const NonClosingWriter = struct {
                file: std.fs.File,
                pub const Error = std.fs.File.WriteError;
                pub fn write(self: @This(), bytes: []const u8) Error!usize {
                    return self.file.write(bytes);
                }
                pub fn writer(self: @This()) std.io.Writer(@This(), Error, write) {
                    return .{ .context = self };
                }
            };

            const BufferedWriter = struct {
                unbuffered: NonClosingWriter,
                buffer: [4096]u8 = undefined,
                index: usize = 0,

                pub const Error = NonClosingWriter.Error;

                pub fn flush(self: *@This()) Error!void {
                    if (self.index == 0) return;
                    try self.unbuffered.file.writeAll(self.buffer[0..self.index]);
                    self.index = 0;
                }

                pub fn write(self: *@This(), bytes: []const u8) Error!usize {
                    if (self.index + bytes.len > self.buffer.len) {
                        try self.flush();
                        if (bytes.len > self.buffer.len) {
                            return self.unbuffered.write(bytes);
                        }
                    }
                    @memcpy(self.buffer[self.index..][0..bytes.len], bytes);
                    self.index += bytes.len;
                    return bytes.len;
                }

                fn writeFn(context: *@This(), bytes: []const u8) Error!usize {
                    return context.write(bytes);
                }

                pub const Writer = std.io.GenericWriter(*@This(), Error, writeFn);

                pub fn writer(self: *@This()) Writer {
                    return .{ .context = self };
                }
            };

            const raw_writer = NonClosingWriter{ .file = file };
            var buffered = BufferedWriter{ .unbuffered = raw_writer };
            try buffered.writer().print(message, args);
            try buffered.flush();
        }
    },
};
pub fn getStdOutFile() std.fs.File {
    if (builtin.os.tag == .windows) {
        const handle = std.os.windows.kernel32.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE);
        return std.fs.File{ .handle = handle.? };
    } else {
        return std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    }
}

pub inline fn isFreestanding() bool {
    return builtin.os.tag == .freestanding;
}
