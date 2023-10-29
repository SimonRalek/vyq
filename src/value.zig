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
                    break :blk std.mem.eql(u8, val.string().repre, b.obj.string().repre);
                }
            },
        };
    }

    /// Vytisknout hodnotu
    pub fn print(self: Self) void {
        if (self == .number) shared.stdout.print("{d}\n", .{self.number}) catch @panic("Nepodařilo se hodnotu vypsat");

        if (self == .boolean) {
            (if (self.boolean) shared.stdout.print("ano\n", .{}) else shared.stdout.print("ne\n", .{})) catch @panic("Nepodařilo se hodnotu vypsat");
        }

        if (self == .nic) shared.stdout.print("nic\n", .{}) catch @panic("Nepodařilo se hodnotu vypsat");

        if (self == .obj) self.obj.print() catch @panic("Nepodařilo se hodnotu vypsat");
    }

    /// Stringová reprezentace hodnoty
    pub fn stringVal(self: Self, allocator: Allocator) ![]const u8 {
        return switch (self) {
            .number => |val| blk: {
                const number = try std.fmt.allocPrint(allocator, "{d}", .{val});

                var buff = try allocator.alloc(u8, number.len);
                _ = std.mem.replace(u8, number, ".", ",", buff);
                allocator.free(number);
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
            @panic("Nepodařilo se alokovat");
        };

        descendent.obj = .{ .type = obj_type, .deinit = T.deinit };

        descendent.obj.next = vm.objects;
        vm.objects = &descendent.obj;

        return descendent;
    }

    /// Vytisknout objekt
    pub fn print(self: *Object) !void {
        switch (self.type) {
            .string => try shared.stdout.print("{s}\n", .{self.string().repre}),
        }
    }

    /// Jako hodnota
    pub fn val(self: *Object) Val {
        return Val{ .obj = self };
    }

    /// Převedení objektu na string s tím spojený
    pub fn string(self: *Object) *String {
        return @fieldParentPtr(String, "obj", self);
    }

    pub const String = struct {
        const Self = @This();

        obj: Object,
        repre: []const u8,

        /// Alokace s objektem
        fn alloc(vm: *VM, buff: []const u8) *Object {
            const alloc_string = Object.alloc(vm, Self, .string);

            alloc_string.repre = buff;
            alloc_string.obj = .{ .type = .string, .deinit = Self.deinit };

            vm.strings.put(buff, alloc_string) catch @panic("Nepodařilo se alokovat");

            return &alloc_string.obj;
        }

        /// Kopírovat string
        pub fn copy(vm: *VM, chars: []const u8) *Object {
            const interned_string = vm.strings.get(chars);
            if (interned_string) |interned| {
                return &interned.obj;
            }

            const buff = vm.allocator.alloc(u8, chars.len) catch {
                std.process.exit(71);
            };

            @memcpy(buff, chars);

            return Self.alloc(vm, buff);
        }

        /// Alokace stringu
        pub fn take(vm: *VM, chars: []const u8) *Object {
            return Self.alloc(vm, chars);
        }

        /// String se rovná jinému stringu
        pub fn isEqual(self: *Self, expected: Self) bool {
            return std.mem.eql(u8, self.repre, expected.repre);
        }

        /// Free string
        pub fn deinit(object: *Object, vm: *VM) void {
            const self = @fieldParentPtr(Self, "obj", object);
            vm.allocator.free(self.repre);
            vm.allocator.destroy(self);
        }
    };
};
