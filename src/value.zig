const std = @import("std");
const shared = @import("shared.zig");

const Allocator = std.mem.Allocator;

const VM = @import("virtualmachine.zig").VirtualMachine;
const Block = @import("block.zig").Block;
const Formatter = @import("formatter.zig");
const IndexError = shared.IndexError;

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
                if (b.isString() and val.type == .string) {
                    break :blk std.mem.eql(
                        u8,
                        val.string().repre,
                        b.obj.string().repre,
                    );
                }

		        break :blk false;
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
            ) catch @panic("Nepodařilo se alokovat hodnotu");

            const buff = allocator.alloc(u8, number.len) catch @panic("Nepodařilo se alokovat hodnotu");
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

                const buff = try allocator.alloc(u8, number.len);
                _ = std.mem.replace(u8, number, ".", ",", buff);
                allocator.free(number);
                break :blk buff;
            },
            .nic => "nic",
            .boolean => |val| if (val) "ano" else "ne",
            .obj => blk: {
                switch (self.obj.type) {
                    .string => break :blk self.obj.string().repre,
                    .function => break :blk self.obj.function().name.?.repre,
                    .closure => break :blk self.obj.closure().function.name.?.repre,
                    .native => break :blk self.obj.native().name,
                    else => unreachable,
                }
            },
        };
    }

    /// Je hodnota textový řetězec
    pub fn isString(self: Self) bool {
        return self == .obj and self.obj.type == .string;
    }

    /// Je hodnota funkce
    pub fn isFunction(self: Self) bool {
        return self == .obj and self.obj.type == .function;
    }

    /// Je hodnota 'Closure'
    pub fn isClosure(self: Self) bool {
        return self == .obj and self.obj.type == .closure;
    }

    /// Je hodnota externé lokální proměnná
    pub fn isELV(self: Self) bool {
        return self == .obj and self.obj.type == .elv;
    }

    /// Je hodnota nativní funkce
    pub fn isNative(self: Self) bool {
        return self == .obj and self.obj.type == .native;
    }

    /// Je hodnota list
    pub fn isList(self: Self) bool {
        return self == .obj and self.obj.type == .list;
    }
};

pub const FunctionType = enum { function, script };

const DeinitFn = *const fn (*Object, *VM) void;

pub const Object = struct {
    const ObjectType = enum {
        string,
        list,
        function,
        closure,
        elv,
        native,
    };

    type: ObjectType,
    deinit: DeinitFn,
    next: ?*Object = null,
    is_marked: bool = false,

    /// Alokace nového objektu
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
                const writer = arrlist.writer();
                try Formatter.escapeFmt(self.string().repre).format(writer);

                const formatted = try arrlist.toOwnedSlice();
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
            .list => {
                const array = self.list();

                try shared.stdout.print("[ ", .{});
                for (array.items.items, 0..) |item, i| {
                    item.print(allocator);

                    if (i != array.items.items.len - 1) {
                        try shared.stdout.print("; ", .{});
                    }
                }
                try shared.stdout.print(" ]", .{});
            },
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

    /// Převedení objektu na řetězec s tím spojený
    pub fn string(self: *Object) *String {
        return @fieldParentPtr(String, "obj", self);
    }

    /// Převedení objektu na funkci s tím spojenou
    pub fn function(self: *Object) *Function {
        return @fieldParentPtr(Function, "obj", self);
    }

    /// Převedení objektu na 'closure' s tím spojený
    pub fn closure(self: *Object) *Closure {
        return @fieldParentPtr(Closure, "obj", self);
    }

    /// Převedení objektu na 'Externí Lokální Proměnou' s tím spojenou
    pub fn elv(self: *Object) *ELV {
        return @fieldParentPtr(ELV, "obj", self);
    }

    /// Převedení objektu na nativní funkci s tím spojenou
    pub fn native(self: *Object) *Native {
        return @fieldParentPtr(Native, "obj", self);
    }

    /// Převedení objektu na list s tím spojený
    pub fn list(self: *Object) *List {
        return @fieldParentPtr(List, "obj", self);
    }

    pub const String = struct {
        const Self = @This();

        obj: Object,
        repre: []u8,

        /// Alokace s objektem
        fn alloc(vm: *VM, buff: []u8) *Object {
            const alloc_string = Object.alloc(vm, Self, .string);

            alloc_string.repre = buff;

            vm.push(alloc_string.obj.val());
            vm.strings.put(buff, alloc_string) catch @panic("Nepodařilo se alokovat");
            _ = vm.pop();

            return &alloc_string.obj;
        }

        /// Kopírovat řetězec
        pub fn copy(vm: *VM, chars: []const u8) *Object {
            const interned_string = vm.strings.get(chars);
            if (interned_string) |interned| {
                return &interned.obj;
            }

            const buff = vm.allocator.alloc(u8, chars.len) catch {
                @panic("sd");
            };

            @memcpy(buff, chars);

            return Self.alloc(vm, buff);
        }

        /// Alokace řetězce
        pub fn take(vm: *VM, chars: []u8) *Object {
            return Self.alloc(vm, chars);
        }

        /// Řetězec se rovná jinému
        pub fn isEqual(self: *Self, expected: Self) bool {
            return std.mem.eql(u8, self.repre, expected.repre);
        }

        /// Je index validní v řetězci
        pub fn isValidIndex(self: *String, index: f64) IndexError!void {
            const length: f64 = @floatFromInt(self.repre.len - 1);
            try indexValidation(index, length);
        }

        /// Free řetězce
        pub fn deinit(object: *Object, vm: *VM) void {
            const self = @fieldParentPtr(Self, "obj", object);
            vm.allocator.free(self.repre);
            vm.allocator.destroy(self);
        }
    };

    pub const List = struct {
        obj: Object,
        items: std.ArrayList(Val),

        /// Alokace listu
        pub fn init(vm: *VM) *List {
            const array = Object.alloc(vm, List, .list);
            array.items = std.ArrayList(Val).init(vm.allocator);
            return array;
        }

        /// Dealokace listu
        pub fn deinit(obj: *Object, vm: *VM) void {
            const self = @fieldParentPtr(List, "obj", obj);
            self.items.deinit();
            vm.allocator.destroy(self);
        }

        /// Přidat prvek do listu
        pub fn append(array: *List, value: Val) void {
            array.items.append(value) catch {};
        }

        /// Přidat prvek do listu na pozici
        pub fn insert(self: *List, idx: f64, value: Val) void {
            self.items.insert(@intFromFloat(idx), value) catch {};
        }

        /// Získat prvek na indexu
        pub fn getItem(self: *List, idx: f64) Val {
            return self.items.items[@intFromFloat(idx)];
        }

        /// Odstranit prvek na indexu
        pub fn delete(self: *List, idx: u32) void {
            _ = self.items.orderedRemove(idx);
        }

        /// Je index validní
        pub fn isValidIndex(self: *List, index: f64) IndexError!void {
            const length: f64 = @floatFromInt(self.items.items.len - 1);
            try indexValidation(index, length);
        }
    };

    pub const Function = struct {
        obj: Object,
        arity: u9 = 0,
        block: Block,
        name: ?*String,
        type: FunctionType,
        elv_count: u9 = 0,

        /// Nová funkce
        pub fn init(vm: *VM, func_type: FunctionType) *Function {
            const func = Object.alloc(vm, Function, .function);
            func.name = null;
            func.arity = 0;
            func.block = Block.init(vm.allocator);
            func.type = func_type;
            func.elv_count = 0;

            return func;
        }

        /// Deinicializace funkce
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

        /// Nové 'Closure'
        pub fn init(vm: *VM, func: *Function) *Closure {
            const elvs = vm.allocator.alloc(?*ELV, func.elv_count) catch @panic("Nepodařilo se alokovat hodnotu");

            for (elvs) |*elvariable| elvariable.* = null;

            const obj = Object.alloc(vm, Closure, .closure);
            obj.function = func;
            obj.elvs = elvs;
            obj.elv_count = func.elv_count;
            return obj;
        }

        /// Deinicializace 'Closure'
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

        /// Nová Externí Lokální Proměnná
        pub fn init(vm: *VM, slot: *Val) *ELV {
            const obj = Object.alloc(vm, ELV, .elv);
            obj.location = slot;
            obj.next = null;
            obj.closed = Val.nic;
            return obj;
        }

        /// Deinicializace Externí Lokální Proměnné
        pub fn deinit(obj: *Object, vm: *VM) void {
            const self = @fieldParentPtr(ELV, "obj", obj);
            vm.allocator.destroy(self);
        }
    };

    pub const Native = struct {
        obj: Object,
        name: []const u8,
        function: NativeFn,

        pub const NativeFn = *const fn (vm: *VM, args: []Val) ?Val;

        /// Nová nativní funkce
        pub fn init(vm: *VM, func: NativeFn, name: []const u8) *Native {
            const obj = Object.alloc(vm, Native, .native);
            obj.function = func;
            obj.name = name;
            return obj;
        }

        /// Deinicializace nativní funkce
        pub fn deinit(object: *Object, vm: *VM) void {
            const self = @fieldParentPtr(Native, "obj", object);
            vm.allocator.destroy(self);
        }
    };
};

/// Vrácení chyby jestli index není validní
fn indexValidation(index: f64, length: f64) IndexError!void {
    if (index < 0) {
        return IndexError.negative_index;
    }

    if (index > length) {
        return IndexError.bigger_index;
    }

    if (std.math.floor(index) != index) {
        return IndexError.float_index;
    }
}
