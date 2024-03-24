const std = @import("std");
const io = std.io;
const process = std.process;
const Allocator = std.mem.Allocator;

const Reporter = @import("reporter.zig");
const Chunk = @import("./block.zig").Block;
const VM = @import("./virtualmachine.zig").VirtualMachine;

const WasmWriter = @import("./writer.zig").WasmWriter;

const allocator = std.heap.wasm_allocator;

var reporter: Reporter = undefined;

extern fn writeOut(ptr: usize, len: usize) void;
extern fn now() f64;

pub fn writeOutSlice(bytes: []const u8) void {
    writeOut(@intFromPtr(bytes.ptr), bytes.len);
}

fn createVMPtr() !*VM {
    const vm = try allocator.create(VM);
    vm.* = VM.create(allocator);
    reporter = Reporter.init(allocator);
    reporter.file = "wasm";
    vm.init(&reporter);
    return vm;
}

pub fn getWriter() WasmWriter {
    return WasmWriter.init(writeOutSlice);
}

export fn createVM() usize {
    const vm = createVMPtr() catch return 0;
    return @intFromPtr(vm);
}

export fn destroyVM(vm: *VM) void {
    vm.deinit();
    allocator.destroy(vm);
}

export fn interpret(vm: *VM, input_ptr: [*]const u8, input_len: usize) usize {
    const source = input_ptr[0..input_len];

    vm.interpret(source) catch |err| switch (err) {
        error.compile => return 65,
        error.runtime => return 70,
        else => return 71,
    };

    return 0;
}

export fn run(input_ptr: [*]const u8, input_len: usize) usize {
    const vm = createVMPtr() catch return 71;
    defer destroyVM(vm);
    return interpret(vm, input_ptr, input_len);
}

pub export fn alloc(len: usize) usize {
    const buf = allocator.alloc(u8, len) catch return 0;
    return @intFromPtr(buf.ptr);
}

pub export fn dealloc(ptr: [*]const u8, len: usize) void {
    allocator.free(ptr[0..len]);
}
