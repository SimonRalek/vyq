const std = @import("std");
const shared = @import("shared.zig");

const Allocator = std.mem.Allocator;

const VM = @import("virtualmachine.zig").VirtualMachine;
const Block = @import("block.zig").Block;
const Formatter = @import("formatter.zig");

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
                    break :blk std.mem.eql(
                        u8,
                        val.string().repre,
                        b.obj.string().repre,
                    );
                }
            },
        };
    }

    /// Vytisknout hodnotu
    pub fn print(self: Self, allocator: Allocator) void {
        if (self == .number) {
            const number = std.fmt.allocPrint(
                allocator,
                "{d}",
                .{self.number},
            ) catch @panic("");

            const buff = allocator.alloc(u8, number.len) catch @panic("");
            _ = std.mem.replace(u8, number, ".", ",", buff);

            shared.stdout.print(
                "{s}",
                .{buff},
            ) catch @panic("Nepodařilo se hodnotu vypsat");

            allocator.free(number);
            allocator.free(buff);
        }

        if (self == .boolean) {
            (if (self.boolean) shared.stdout.print(
                "ano",
                .{},
            ) else shared.stdout.print("ne", .{})) catch @panic("Nepodařilo se hodnotu vypsat");
        }

        if (self == .nic) shared.stdout.print(
            "nic",
            .{},
        ) catch @panic("Nepodařilo se hodnotu vypsat");

        if (self == .obj) self.obj.print(allocator) catch @panic("Nepodařilo se hodnotu vypsat");
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
    const ObjectType = enum {
        string,
        function,
        closure,
        elv,
        native,
    };

    type: ObjectType,
    deinit: DeinitFn,
    next: ?*Object = null,
    is_marked: bool = false,

    pub fn alloc(
        vm: *VM,
        comptime T: type,
        obj_type: Object.ObjectType,
    ) *T {
        const descendent = vm.allocator.create(T) catch {
            @panic("Nepodařilo se alokovat");
        };

        descendent.obj = .{
            .type = obj_type,
            .deinit = T.deinit,
            .next = vm.objects,
        };

        vm.objects = &descendent.obj;

        return descendent;
    }

    /// Vytisknout objekt
    pub fn print(self: *Object, allocator: Allocator) !void {
        switch (self.type) {
            .string => {
                var arrlist = std.ArrayList(u8).init(allocator);
                defer arrlist.deinit();
                var writer = arrlist.writer();
                try Formatter.escapeFmt(self.string().repre).format(writer);

                var formatted = try arrlist.toOwnedSlice();
                defer allocator.free(formatted);
                try shared.stdout.print("{s}", .{formatted});
            },
            .function => {
                const func = self.function();

                if (func.name) |name| {
                    try shared.stdout.print("<fn {s}>", .{name.repre});
                    return;
                }
                try shared.stdout.print("<script>", .{});
            },
            .closure => {
                const clos = self.closure();
                const func = clos.function;

                if (func.name) |name| {
                    try shared.stdout.print("<fn {s}>", .{name.repre});
                    return;
                }
                try shared.stdout.print("<script>", .{});
            },
            // není možné aby se stalo
            .elv => {
                try shared.stdout.print("elv", .{});
            },
            .native => {
                try shared.stdout.print("<native fn>", .{});
            },
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

    pub fn function(self: *Object) *Function {
        return @fieldParentPtr(Function, "obj", self);
    }

    pub fn closure(self: *Object) *Closure {
        return @fieldParentPtr(Closure, "obj", self);
    }

    pub fn elv(self: *Object) *ELV {
        return @fieldParentPtr(ELV, "obj", self);
    }

    pub fn native(self: *Object) *Native {
        return @fieldParentPtr(Native, "obj", self);
    }

    pub const String = struct {
        const Self = @This();

        obj: Object,
        repre: []const u8,

        /// Alokace s objektem
        fn alloc(vm: *VM, buff: []const u8) *Object {
            const alloc_string = Object.alloc(vm, Self, .string);

            alloc_string.repre = buff;

            vm.push(alloc_string.obj.val());
            vm.strings.put(buff, alloc_string) catch @panic("Nepodařilo se alokovat");
            _ = vm.pop();

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

    pub const Function = struct {
        obj: Object,
        arity: u9 = 0,
        block: Block,
        name: ?*String,
        type: FunctionType,
        elv_count: u9 = 0,

        pub fn init(vm: *VM, func_type: FunctionType) *Function {
            const func = Object.alloc(vm, Function, .function);
            func.name = null;
            func.arity = 0;
            func.block = Block.init(vm.allocator);
            func.type = func_type;
            func.elv_count = 0;

            return func;
        }

        pub fn deinit(object: *Object, vm: *VM) void {
            const self = @fieldParentPtr(Function, "obj", object);
            self.block.deinit();
            vm.allocator.destroy(self);
        }
    };

    pub const Closure = struct {
        obj: Object,
        function: *Function,
        elvs: []?*ELV,
        elv_count: u9,

        pub fn init(vm: *VM, func: *Function) *Closure {
            const elvs = vm.allocator.alloc(?*ELV, func.elv_count) catch @panic("");

            for (elvs) |*elvariable| elvariable.* = null;

            const obj = Object.alloc(vm, Closure, .closure);
            obj.function = func;
            obj.elvs = elvs;
            obj.elv_count = func.elv_count;
            return obj;
        }

        pub fn deinit(obj: *Object, vm: *VM) void {
            const self = @fieldParentPtr(Closure, "obj", obj);
            vm.allocator.free(self.elvs);
            vm.allocator.destroy(self);
        }
    };

    pub const ELV = struct {
        obj: Object,
        location: *Val,
        closed: Val,
        next: ?*ELV,

        pub fn init(vm: *VM, slot: *Val) *ELV {
            const obj = Object.alloc(vm, ELV, .elv);
            obj.location = slot;
            obj.next = null;
            obj.closed = Val.nic;
            return obj;
        }

        pub fn deinit(obj: *Object, vm: *VM) void {
            const self = @fieldParentPtr(ELV, "obj", obj);
            vm.allocator.destroy(self);
        }
    };

    pub const Native = struct {
        obj: Object,
        function: NativeFn,

        pub const NativeFn = *const fn (vm: *VM, args: []Val) ?Val;

        pub fn init(vm: *VM, func: NativeFn) *Native {
            const obj = Object.alloc(vm, Native, .native);
            obj.function = func;
            return obj;
        }

        pub fn deinit(object: *Object, vm: *VM) void {
            const self = @fieldParentPtr(Native, "obj", object);
            vm.allocator.destroy(self);
        }
    };
};

pub const FunctionType = enum { function, script };
