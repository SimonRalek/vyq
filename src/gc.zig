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
    bytesAllocated: usize,
    nextGC: usize,

    const vtable: Allocator.VTable = .{ .alloc = alloc, .resize = resize, .free = free };

    pub fn init(vm: *VM) Self {
        return .{
            .vm = vm,
            .parent_allocator = vm.allocator,
            .bytesAllocated = 0,
            .nextGC = 1024 * 1024,
        };
    }

    pub fn collectGarbage(self: *Self) void {
        self.markRoots();
        self.traceReferences();
        self.removeWeakRefs();
        self.sweep();

        self.nextGC = self.bytesAllocated * 2;
    }

    fn markRoots(self: *Self) void {
        for (0..self.vm.stack_count) |i| {
            self.markVal(self.vm.stack[i]);
        }

        for (0..self.vm.frame_count) |i| {
            self.markObject(&self.vm.frames[i].closure.obj);
        }

        var maybeELV = self.vm.openELV;
        while (maybeELV) |elv| {
            self.markObject(&elv.obj);
            maybeELV = elv.next;
        }

        self.markMap(Global, &self.vm.globals);
        self.markCompilerRoots();
    }

    fn markVal(self: *Self, val: Val) void {
        if (val == .obj) self.markObject(val.obj);
    }

    fn markObject(self: *Self, obj: *_val.Object) void {
        if (obj.is_marked) return;

        obj.is_marked = true;

        self.vm.grays.append(obj) catch @panic("Nepovedlo se alokovat");
    }

    fn markMap(self: *Self, comptime T: type, map: *std.AutoHashMap(*_val.Object.String, T)) void {
        var iterator = map.iterator();
        while (iterator.next()) |kv| {
            self.markObject(&kv.key_ptr.*.obj);
            self.markVal(kv.value_ptr.*.val);
        }
    }

    fn markCompilerRoots(self: *Self) void {
        if (self.vm.parser) |parser| {
            var emitter: ?*Emitter = parser.emitter;

            while (emitter) |current| {
                self.markObject(&current.function.obj);
                emitter = current.wrapped;
            }
        }
    }

    fn markArray(self: *Self, vals: []Val) void {
        for (vals) |val| self.markVal(val);
    }

    fn traceReferences(self: *Self) void {
        while (self.vm.grays.items.len > 0) {
            const object = self.vm.grays.pop();
            self.blackenObject(object);
        }
    }

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
            else => {},
        }
    }

    fn removeWeakRefs(self: *Self) void {
        var iterator = self.vm.strings.iterator();
        while (iterator.next()) |kv| {
            if (!kv.value_ptr.*.obj.is_marked) {
                _ = self.vm.strings.remove(kv.key_ptr.*);
            }
        }
    }

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

    pub fn allocator(self: *Self) Allocator {
        return Allocator{ .ptr = self, .vtable = &vtable };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (self.bytesAllocated + len > self.nextGC) {
            self.collectGarbage();
        }

        const out = self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);

        self.bytesAllocated += len;

        return out;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (new_len > buf.len) {
            if (self.bytesAllocated + (new_len - buf.len) > self.nextGC) {
                self.collectGarbage();
            }
        }

        if (self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr)) {
            if (new_len > buf.len) {
                self.bytesAllocated += new_len - buf.len;
            } else {
                self.bytesAllocated -= buf.len - new_len;
            }
            return true;
        } else {
            return false;
        }
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: u8,
        ret_addr: usize,
    ) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.parent_allocator.rawFree(buf, buf_align, ret_addr);
        self.bytesAllocated -= buf.len;
    }
};
