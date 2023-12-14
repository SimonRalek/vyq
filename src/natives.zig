const std = @import("std");

const VM = @import("virtualmachine.zig").VirtualMachine;
const _value = @import("value.zig");
const Val = _value.Val;
const Object = _value.Object;

pub fn str_lenNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    if (args[0] != .obj or args[0].obj.type != .string) {
        vm.runtimeErr("Argument musí být textový řetězec", .{}, &.{});
        return null;
    }

    const string = args[0].obj.string().repre;

    const result: f64 = @floatFromInt(std.unicode.utf8CountCodepoints(string) catch @panic(""));
    return Val{ .number = result };
}

// TODO string a number
pub fn inputNative(vm: *VM, args: []const Val) ?Val {
    _ = args;

    var buf: [256]u8 = undefined;
    var buf_stream = std.io.fixedBufferStream(&buf);

    var buffered_stdin = std.io.bufferedReader(std.io.getStdIn().reader());
    const stdin = buffered_stdin.reader();
    stdin.streamUntilDelimiter(
        buf_stream.writer(),
        '\n',
        buf.len,
    ) catch {
        @panic("");
    };
    const input = std.mem.trim(u8, buf_stream.getWritten(), "\n\r");

    if (input.len == buf.len) {
        vm.runtimeErr("Vstup je příliš dlouhý", .{}, &.{});
        std.io.getStdIn().reader().skipUntilDelimiterOrEof('\n') catch {};
    }

    return Val{ .obj = Object.String.copy(vm, buf[0..input.len]) };
}

pub fn getTypeNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    const val = switch (args[0]) {
        .number => "číslo",
        .boolean => "pravdivost",
        .nic => "nic",
        .obj => switch (args[0].obj.type) {
            .string => "textový řetězec",
            .function => "funkce",
            .native => "výchozí funkce",
        },
    };

    return Val{ .obj = Object.String.copy(vm, val) };
}

pub fn randNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1 and args.len != 0) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}' nebo '{}'", .{ args.len, 0, 1 }, &.{});
        return null;
    }

    if (args.len == 1 and args[0] != .number) {
        vm.runtimeErr("Argument musí být číselné hodnoty", .{}, &.{});
        return null;
    }

    var rnd = std.rand.DefaultPrng.init(0);
    rnd.seed(@intCast(std.time.nanoTimestamp()));

    var mod: u64 = undefined;
    if (args.len == 1) {
        mod = @intFromFloat(args[0].number);
    }

    var result: f64 = @floatFromInt(
        if (args.len == 0) rnd.random().int(u32) else @mod(rnd.random().int(u32), mod + 1),
    );

    return Val{ .number = result };
}

pub fn sqrtNative(vm: *VM, args: []const Val) ?Val {
    std.debug.print("{any}", .{args});
    if (args.len != 2) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 2 }, &.{});
        return null;
    }

    if (args[0] != .number or args[1] != .number) {
        vm.runtimeErr("Oba argumenty funkce musí být číselné hodnoty", .{}, &.{});
        return null;
    }

    return Val{ .number = std.math.pow(f64, args[0].number, args[1].number) };
}

pub fn rootNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1 or args[0] != .number) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 2 }, &.{});
        return null;
    }

    if (args[0] != .number) {
        vm.runtimeErr("Argument funkce musí být číselné hodnoty", .{}, &.{});
        return null;
    }

    return Val{ .number = @sqrt(args[0].number) };
}

pub fn isDigitNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    return Val{ .boolean = args[0] == .number };
}

pub fn isStringNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    return Val{ .boolean = args[0] == .obj and args[0].obj.type == .string };
}

pub fn getTimeStampNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 0) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    return Val{ .number = @floatFromInt(std.time.timestamp()) };
}
