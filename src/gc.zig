const std = @import("std");
const Allocator = std.mem.Allocator;

const VM = @import("virtualmachine.zig").VirtualMachine;
const Emitter = @import("emitter.zig").Emitter;
const _val = @import("value.zig");
const Val = _val.Val;

const Global = @import("storage.zig").Global;

pub const GC = struct {
    const Self = @This();

    parent_allocator: Allocator,
    vm: *VM,
    bytes_allocated: usize,
    next_GC: usize,

    const vtable: Allocator.VTable = .{ .alloc = alloc, .resize = resize, .free = free };

    /// Nový GC (Garbage Collector)
    pub fn init(vm: *VM) Self {
        return .{
            .vm = vm,
            .parent_allocator = vm.allocator,
            .bytes_allocated = 0,
            .next_GC = 1_000_000,
        };
    }

    /// Hlavní metoda GC
    pub fn collectGarbage(self: *Self) void {
        self.markRoots();
        self.traceReferences();
        self.removeWeakRefs();
        self.sweep();

        self.next_GC = self.bytes_allocated * 2;
    }

    /// Markování hlavních nodu - stack, closures, elvs, globalní proměnné
    fn markRoots(self: *Self) void {
        for (0..self.vm.stack_count) |i| {
            self.markVal(self.vm.stack[i]);
        }

        for (0..self.vm.frame_count) |i| {
            self.markObject(&self.vm.frames[i].closure.obj);
        }

        var maybe_ELV = self.vm.openELV;
        while (maybe_ELV) |elv| {
            self.markObject(&elv.obj);
            maybe_ELV = elv.next;
        }

        self.markMap(Global, &self.vm.globals);
        self.markEmitterRoots();
    }

    /// Označ hodnotu
    fn markVal(self: *Self, val: Val) void {
        if (val == .obj) self.markObject(val.obj);
    }

    /// Označit objekt
    fn markObject(self: *Self, obj: *_val.Object) void {
        if (obj.is_marked) return;

        obj.is_marked = true;

        self.vm.grays.append(obj) catch @panic("Nepovedlo se alokovat");
    }

    /// Označení objektů v mapách
    fn markMap(self: *Self, comptime T: type, map: *std.AutoHashMap(*_val.Object.String, T)) void {
        var iterator = map.iterator();
        while (iterator.next()) |kv| {
            self.markObject(&kv.key_ptr.*.obj);
            self.markVal(kv.value_ptr.*.val);
        }
    }

    /// Označení funkcí emitterů
    fn markEmitterRoots(self: *Self) void {
        if (self.vm.parser) |parser| {
            var emitter: ?*Emitter = parser.emitter;

            while (emitter) |current| {
                self.markObject(&current.function.obj);
                emitter = current.wrapped;
            }
        }
    }

    /// Označení objektů v poli Vals
    fn markArray(self: *Self, vals: []Val) void {
        for (vals) |val| self.markVal(val);
    }

    /// Po fázi označení projede "šedivé objekty"
    fn traceReferences(self: *Self) void {
        while (self.vm.grays.items.len > 0) {
            const object = self.vm.grays.pop();
            self.blackenObject(object);
        }
    }

    /// Označení objektu že jeho reference jsou označené
    fn blackenObject(self: *Self, object: *_val.Object) void {
        switch (object.type) {
            .elv => self.markVal(object.elv().closed),
            .function => {
                const func = object.function();
                if (func.name) |name| self.markObject(&name.obj);
                self.markArray(func.block.values.items);
            },
            .closure => {
                const closure = object.closure();

                self.markObject(&closure.function.obj);
                for (closure.elvs) |maybeELV| {
                    if (maybeELV) |elv| self.markObject(&elv.obj);
                }
            },
            .list => {
                const list = object.list();

                self.markArray(list.items.items);
            },
            else => {},
        }
    }

    /// Odstranit reference k odstraněným řetězcům
    fn removeWeakRefs(self: *Self) void {
        var iterator = self.vm.strings.iterator();
        while (iterator.next()) |kv| {
            if (!kv.value_ptr.*.obj.is_marked) {
                _ = self.vm.strings.remove(kv.key_ptr.*);
            }
        }
    }

    /// Nemarkovaný objekty dealokovat
    fn sweep(self: *Self) void {
        var previous: ?*_val.Object = null;
        var maybeObject = self.vm.objects;
        while (maybeObject) |object| {
            maybeObject = object.next;

            if (object.is_marked) {
                object.is_marked = false;
                previous = object;
            } else {
                if (previous) |prev| {
                    prev.next = maybeObject;
                } else {
                    self.vm.objects = maybeObject;
                }

                object.deinit(object, self.vm);
            }
        }
    }

    /// Získat allocator
    pub fn allocator(self: *Self) Allocator {
        return Allocator{ .ptr = self, .vtable = &vtable };
    }

    /// Vlastní funkce na alokaci paměti
    fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (self.bytes_allocated + len > self.next_GC) {
            self.collectGarbage();
        }

        const out = self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);

        self.bytes_allocated += len;

        return out;
    }

    /// Vlastní funkce pro změnu velikosti alokované paměti
    fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (new_len > buf.len) {
            if (self.bytes_allocated + (new_len - buf.len) > self.next_GC) {
                self.collectGarbage();
            }
        }

        if (self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr)) {
            if (new_len > buf.len) {
                self.bytes_allocated += new_len - buf.len;
            } else {
                self.bytes_allocated -= buf.len - new_len;
            }
            return true;
        } else {
            return false;
        }
    }

    /// Vlastní funkce na dealokaci paměti
    fn free(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: u8,
        ret_addr: usize,
    ) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.parent_allocator.rawFree(buf, buf_align, ret_addr);
        self.bytes_allocated -= buf.len;
    }
};
