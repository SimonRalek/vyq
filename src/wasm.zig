const std = @import("std");
const io = std.io;
const process = std.process;
const Allocator = std.mem.Allocator;

const Reporter = @import("reporter.zig");
const Chunk = @import("./block.zig").Block;
const VM = @import("./virtualmachine.zig").VirtualMachine;
const ExternalWriter = @import("./writer.zig").ExternalWriter;

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = general_purpose_allocator.allocator();

extern fn writeOut(ptr: usize, len: usize) void;
extern fn now() f64;

pub fn writeOutSlice(bytes: []const u8) void {
    writeOut(@intFromPtr(bytes.ptr), bytes.len);
}

var reporter: Reporter = undefined;

pub const std_options = struct {
    pub const log_level = .info;
    pub fn logFn(
        comptime level: std.log.Level,
        comptime scope: @Type(.EnumLiteral),
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = args;
        _ = format;
        _ = scope;
        _ = level;
        // @compileError("");
        // const prefix = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
        // log(level.asText() ++ prefix ++ format, args);
    }
};

fn log(comptime format: []const u8, args: anytype) void {
    const writer = std.io.Writer(void, error{}, console_log_write_zig){ .context = {} };
    writer.print(format, args) catch @panic("console_log_write failed");
}
fn console_log_write_zig(context: void, bytes: []const u8) !usize {
    _ = context;
    return bytes.len;
}

fn createVMPtr() !*VM {
    var vm = try allocator.create(VM);
    vm.* = VM.create(allocator);
    reporter = Reporter.init(allocator);
    reporter.file = "wasm";
    vm.init(&reporter);
    return vm;
}

export fn createVM() usize {
    var vm = createVMPtr() catch return 0;
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
    var vm = createVMPtr() catch return 71;
    defer destroyVM(vm);
    return interpret(vm, input_ptr, input_len);
}

pub export fn alloc(len: usize) usize {
    var buf = allocator.alloc(u8, len) catch return 0;
    return @intFromPtr(buf.ptr);
}

pub export fn dealloc(ptr: [*]const u8, len: usize) void {
    allocator.free(ptr[0..len]);
}
