const std = @import("std");

const shared = @import("shared.zig");
const VM = @import("virtualmachine.zig").VirtualMachine;
const _value = @import("value.zig");
const Val = _value.Val;
const Object = _value.Object;

extern fn now() f64;

/// Délka textového řetězce
pub fn lenNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    if (!args[0].isString() and !args[0].isList()) {
        vm.runtimeErr("Argument musí být textový řetězec nebo list", .{}, &.{});
        return null;
    }

    if (args[0].isString()) {
        const string = args[0].obj.string().repre;

        const result: f64 = @floatFromInt(std.unicode.utf8CountCodepoints(string) catch @panic("Nepodařilo se získat délku řetězce"));
        return Val{ .number = result };
    } else {
        const list = args[0].obj.list();

        return Val{ .number = @floatFromInt(list.items.items.len) };
    }
}

/// Získat input jako textový řetězec
pub fn inputNative(vm: *VM, args: []const Val) ?Val {
    if (shared.isFreestanding()) {
        vm.runtimeErr("Funkci pro input z příkazové řádky nelze použít na webu", .{}, &.{});
        return null;
    }
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
        @panic("Nepodařilo se načíst vstup z terminálu");
    };
    const input = std.mem.trim(u8, buf_stream.getWritten(), "\n\r");

    if (input.len == buf.len) {
        vm.runtimeErr("Vstup je příliš dlouhý", .{}, &.{});
        std.io.getStdIn().reader().skipUntilDelimiterOrEof('\n') catch {};
    }

    return Val{ .obj = Object.String.copy(vm, buf[0..input.len]) };
}

/// Získat typ hodnoty
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
            .function, .closure => "funkce",
            .native => "výchozí funkce",
            .elv => "external local variable",
            .list => "list",
        },
    };

    return Val{ .obj = Object.String.copy(vm, val) };
}

/// Random číslo
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
    const time: i64 = if (shared.isFreestanding()) @intFromFloat(now()) else @intCast(std.time.nanoTimestamp());

    rnd.seed(
        @intCast(time),
    );

    var mod: u64 = undefined;
    if (args.len == 1) {
        mod = @intFromFloat(args[0].number);
    }

    const result: f64 = @floatFromInt(
        if (args.len == 0) rnd.random().int(u32) else @mod(rnd.random().int(u32), mod + 1),
    );

    return Val{ .number = result };
}

/// Pro mocnění
pub fn sqrtNative(vm: *VM, args: []const Val) ?Val {
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

/// Pro odmocnění
pub fn rootNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1 or args[0] != .number) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    if (args[0] != .number) {
        vm.runtimeErr("Argument funkce musí být číselné hodnoty", .{}, &.{});
        return null;
    }

    return Val{ .number = @sqrt(args[0].number) };
}

/// Či je hodnota číslo
pub fn isDigitNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    return Val{ .boolean = args[0] == .number };
}

/// Či je hodnota textový řetězec
pub fn isStringNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    return Val{ .boolean = args[0].isString() };
}

/// Jestli je hodnota list
pub fn isListNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    return Val{ .boolean = args[0].isList() };
}

/// Získat časový údaj
pub fn getTimeStampNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 0) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    return Val{ .number = if (shared.isFreestanding()) now() else @floatFromInt(std.time.timestamp()) };
}

/// Převést hodnotu na textový řetězec
pub fn toString(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    const string = Object.String.copy(vm, args[0].stringVal(vm.allocator) catch {
        vm.runtimeErr("Nepovedlo se hodnotu převést na řetězec", .{}, &.{});
        return null;
    });

    return Val{ .obj = string };
}

/// Převést hodnotu na číslo, jinak chyba
pub fn toNumber(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    if (!args[0].isString()) {
        vm.runtimeErr("Argument musí být textový řetězec", .{}, &.{});
        return null;
    }

    const repre = args[0].obj.string().repre;

    if (std.mem.containsAtLeast(u8, repre, 1, ".")) {
        vm.runtimeErr("Řetězec '{s}' nemohl být převeden na číslo", .{repre}, &.{});
        return null;
    }

    const replaced: []u8 = vm.allocator.alloc(u8, repre.len) catch {
        vm.runtimeErr("Alokace paměti neuspěla", .{}, &.{});
        return null;
    };
    _ = std.mem.replace(u8, repre, ",", ".", replaced);

    const number = std.fmt.parseFloat(f64, replaced) catch {
        vm.runtimeErr("Řetězec '{s}' nemohl být převeden na číslo", .{repre}, &.{});
        vm.allocator.free(replaced);
        return null;
    };

    vm.allocator.free(replaced);

    return Val{ .number = number };
}

/// Přidat prvek do listu
pub fn appendToList(vm: *VM, args: []const Val) ?Val {
    if (args.len != 2) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 2 }, &.{});
        return null;
    }

    if (!args[0].isList()) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 2 }, &.{});
        return null;
    }

    const list = args[0].obj.list();
    list.append(args[1]);
    return Val{ .number = @floatFromInt(list.items.items.len) };
}

/// Odstranit poslední prvek v listu
pub fn popFromList(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    if (!args[0].isList()) {
        vm.runtimeErr("Prvek jde vyjmout pouze z listu", .{}, &.{});
        return null;
    }

    const list = args[0].obj.list();
    if (list.isEmpty()) {
        vm.runtimeErr("Nelze vyjmout prvek z listu, list je prázdný", .{}, &.{});
        return null;
    }

    const popped = list.items.pop();

    return popped;
}
