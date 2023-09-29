const std = @import("std");
const shared = @import("shared.zig");

pub const Type = enum { boolean, nic, number, binary, hexadecimal };

pub const Val = union(enum) {
    const Self = @This();

    boolean: bool,
    nic,
    number: f64,
    // binary: u64,
    // hexadecimal: u64,

    pub fn isEqual(a: Val, b: Val) bool {
        return switch (a) {
            .nic => b == .nic,
            .boolean => |val| b == .boolean and b.boolean == val,
            .number => |val| b == .number and b.number == val,
            // .binary => |val| b == .number and b.binary == val,
            // .hexadecimal => |val| b == .hexadecimal and b.hexadecimal == val,
        };
    }

    pub fn print(self: Self) void {
        if (self == .number) {
            shared.stdout.print("value: {d}\n", .{self.number}) catch {};
            return;
        }

        if (self == .boolean) {
            shared.stdout.print("{}\n", .{self.boolean}) catch {};
            return;
        }

        if (self == .nic) {
            shared.stdout.print("nic\n", .{}) catch {};
            return;
        }
    }
};
