const std = @import("std");
const shared = @import("shared.zig");

const Compiler = @import("compiler.zig").Compiler;
const VM = @import("virtualmachine.zig").VirtualMachine;

pub const Val = union(enum) {
    const Self = @This();

    boolean: bool,
    nic,
    number: f64,
    obj: *Object,

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

    pub fn print(self: Self) void {
        if (self == .number) shared.stdout.print("value: {d}\n", .{self.number}) catch {};

        if (self == .boolean) shared.stdout.print("{}\n", .{self.boolean}) catch {};

        if (self == .nic) shared.stdout.print("nic\n", .{}) catch {};

        if (self == .obj) self.obj.print() catch {};
    }
};

const DeinitFn = *const fn (*Object, *VM) void;

pub const Object = struct {
    const ObjectType = enum { string };

    type: ObjectType,
    deinit: ?DeinitFn,

    pub fn alloc(vm: *VM, comptime T: type, obj_type: Object.ObjectType) *Object {
        const descendent = vm.allocator.create(T);

        descendent.obj = .{ .type = obj_type };

        return &descendent.obj;
    }

    pub fn deinit(self: *Object, vm: *VM) void {
        self.deinit(self, vm);
    }

    pub fn print(self: *const Object) !void {
        switch (self.type) {
            .string => try shared.stdout.print("{s}\n", .{self.toString().repre}),
        }
    }

    pub fn val(self: *Object) Val {
        return Val{ .obj = self };
    }

    pub fn toString(self: *const Object) *const String {
        return @fieldParentPtr(String, "obj", self);
    }

    pub const String = struct {
        const Self = @This();

        obj: Object,
        repre: []const u8,

        fn alloc(vm: *VM, buff: []const u8) *Object {
            const string: *Self = vm.allocator.create(Self) catch {
                std.process.exit(71);
            };

            string.repre = buff;
            string.obj = .{ .type = .string, .deinit = Self.deinit };

            return &string.obj;
        }

        pub fn copy(vm: *VM, chars: []const u8) *Object {
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
