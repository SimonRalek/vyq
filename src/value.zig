const std = @import("std");
const shared = @import("shared.zig");

const VM = @import("virtualmachine.zig").VirtualMachine;
const Allocator = std.mem.Allocator;

pub const Val = union(enum) {
    const Self = @This();

    boolean: bool,
    nic,
    number: f64,
    obj: *Object,

    /// Rovnají se hodnoty
    pub fn isEqual(a: Val, b: Val) bool {
        return switch (a) {
            .nic => b == .nic,
            .boolean => |val| b == .boolean and b.boolean == val,
            .number => |val| b == .number and b.number == val,
            .obj => |val| blk: {
                if (b == .obj and val.type == .string and b.obj.type == .string) {
                    break :blk std.mem.eql(u8, val.toString().repre, b.obj.toString().repre);
                }
            },
        };
    }

    /// Vytisknout hodnotu
    pub fn print(self: Self) void {
        if (self == .number) shared.stdout.print("{d}\n", .{self.number}) catch {};

        if (self == .boolean) {
            (if (self.boolean) shared.stdout.print("ano\n", .{}) else shared.stdout.print("ne\n", .{})) catch {};
        }

        if (self == .nic) shared.stdout.print("nic\n", .{}) catch {};

        if (self == .obj) self.obj.print() catch {};
    }

    /// Hodnot
    pub fn stringVal(self: Self, allocator: Allocator) ![]const u8 {
        return switch (self) {
            .number => |val| blk: {
                const number = try std.fmt.allocPrint(allocator, "{d}", .{val});
                var buff = try allocator.alloc(u8, number.len);
                _ = std.mem.replace(u8, number, ".", ",", buff);
                break :blk buff;
            },
            .nic => "nic",
            .boolean => |val| if (val) "ano" else "ne",
            else => unreachable, // TODO?
        };
    }
};

const DeinitFn = *const fn (*Object, *VM) void;

pub const Object = struct {
    const ObjectType = enum { string };

    type: ObjectType,
    deinit: DeinitFn,
    next: ?*Object = null,

    pub fn alloc(vm: *VM, comptime T: type, obj_type: Object.ObjectType) *T {
        const descendent = vm.allocator.create(T) catch {
            @panic("");
        };

        descendent.obj = .{ .type = obj_type, .deinit = T.deinit };

        descendent.obj.next = vm.objects;
        vm.objects = &descendent.obj;

        return descendent;
    }

    pub fn print(self: *Object) !void {
        switch (self.type) {
            .string => try shared.stdout.print("{s}\n", .{self.toString().repre}),
        }
    }

    pub fn val(self: *Object) Val {
        return Val{ .obj = self };
    }

    pub fn toString(self: *Object) *String {
        return @fieldParentPtr(String, "obj", self);
    }

    pub const String = struct {
        const Self = @This();

        obj: Object,
        repre: []const u8,

        fn alloc(vm: *VM, buff: []const u8) *Object {
            const string = Object.alloc(vm, Self, .string);

            string.repre = buff;
            string.obj = .{ .type = .string, .deinit = Self.deinit };

            vm.strings.put(buff, string) catch {};

            return &string.obj;
        }

        pub fn copy(vm: *VM, chars: []const u8) *Object {
            const interned_string = vm.strings.get(chars);
            if (interned_string) |string| {
                return &string.obj;
            }

            const buff = vm.allocator.alloc(u8, chars.len) catch {
                std.process.exit(71);
            };

            std.mem.copy(u8, buff, chars);

            return Self.alloc(vm, buff);
        }

        pub fn take(vm: *VM, chars: []const u8) *Object {
            return Self.alloc(vm, chars);
        }

        pub fn isEqual(self: *Self, expected: Self) bool {
            return std.mem.eql(u8, self.repre, expected.repre);
        }

        pub fn deinit(object: *Object, vm: *VM) void {
            const self = @fieldParentPtr(Self, "obj", object);
            vm.allocator.free(self.repre);
            vm.allocator.destroy(self);
        }
    };
};
