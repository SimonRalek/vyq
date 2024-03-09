const std = @import("std");
const builtin = @import("builtin");

pub const wasm = @import("wasm.zig");
pub const ExternalWriter = @import("writer.zig").ExternalWriter;
pub const ResultError = error{ parser, compile, runtime };

pub const IndexError = error{ negative_index, bigger_index, float_index };


/// Pro získání prostředku na výpis
pub const stdout = switch (builtin.os.tag) {
    .windows => struct {
        pub fn print(comptime message: []const u8, args: anytype) !void {
            try std.io.getStdOut().writer().print(message, args);
        }
    },
    .freestanding => ExternalWriter.init(wasm.writeOutSlice).writer(),
    .wasi => ExternalWriter.init(wasm.writeOutSlice).writer(),
    else => std.io.getStdOut().writer(),
};

pub inline fn isFreestanding() bool {
    return builtin.os.tag == .freestanding;
}
