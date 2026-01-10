const std = @import("std");
const builtin = @import("builtin");

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

    const stdin_file = if (builtin.os.tag == .windows) blk: {
        const handle = std.os.windows.kernel32.GetStdHandle(std.os.windows.STD_INPUT_HANDLE);
        break :blk std.fs.File{ .handle = handle.? };
    } else blk: {
        break :blk std.fs.File{ .handle = std.posix.STDIN_FILENO };
    };

    var len: usize = 0;
    while (len < buf.len) : (len += 1) {
        var byte_buf: [1]u8 = undefined;
        const n = stdin_file.read(&byte_buf) catch {
            vm.runtimeErr("IO Error", .{}, &.{});
            return null;
        };
        if (n == 0) break;
        const byte = byte_buf[0];

        if (byte == '\n') break;
        buf[len] = byte;
    }
    const input = std.mem.trim(u8, buf[0..len], "\r");

    if (input.len == buf.len) {
        vm.runtimeErr("Vstup je příliš dlouhý", .{}, &.{});
        // Skip remaining input manually
        while (true) {
            var byte_buf: [1]u8 = undefined;
            const n_read = stdin_file.read(&byte_buf) catch break;
            if (n_read == 0) break;
            if (byte_buf[0] == '\n') break;
        }
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

    var rnd = std.Random.DefaultPrng.init(0);
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

    const str_val = args[0].stringVal(vm.allocator) catch {
        vm.runtimeErr("Nepovedlo se hodnotu převést na řetězec", .{}, &.{});
        return null;
    };
    defer vm.allocator.free(str_val);

    const string = Object.String.copy(vm, str_val);

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

/// Přečíst obsah souboru
pub fn readFileNative(vm: *VM, args: []const Val) ?Val {
    if (shared.isFreestanding()) {
        vm.runtimeErr("Funkci pro čtení souborů nelze použít na webu", .{}, &.{});
        return null;
    }

    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    if (!args[0].isString()) {
        vm.runtimeErr("Argument cesty k souboru musí být textový řetězec", .{}, &.{});
        return null;
    }

    const path = args[0].obj.string().repre;

    const content = std.fs.cwd().readFileAlloc(vm.allocator, path, std.math.maxInt(usize)) catch |err| {
        vm.runtimeErr("Nepodařilo se přečíst soubor '{s}', chyba: {}", .{ path, err }, &.{});
        return null;
    };

    // We take ownership of the content buffer in String.take or copy?
    // String.take expects the buffer to be allocated with vm.allocator.
    // readFileAlloc uses vm.allocator, so we can use String.take.
    return Val{ .obj = Object.String.take(vm, content) };
}

/// Zapsat obsah do souboru
pub fn writeFileNative(vm: *VM, args: []const Val) ?Val {
    if (shared.isFreestanding()) {
        vm.runtimeErr("Funkci pro zápis do souborů nelze použít na webu", .{}, &.{});
        return null;
    }

    if (args.len != 2) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 2 }, &.{});
        return null;
    }

    if (!args[0].isString() or !args[1].isString()) {
        vm.runtimeErr("Argumenty musí být textové řetězce (cesta, obsah)", .{}, &.{});
        return null;
    }

    const path = args[0].obj.string().repre;
    const content = args[1].obj.string().repre;

    const file = std.fs.cwd().createFile(path, .{}) catch |err| {
        vm.runtimeErr("Nepodařilo se otevřít soubor '{s}' pro zápis, chyba: {}", .{ path, err }, &.{});
        return null;
    };
    defer file.close();

    file.writeAll(content) catch |err| {
        vm.runtimeErr("Nepodařilo se zapsat do souboru '{s}', chyba: {}", .{ path, err }, &.{});
        return null;
    };

    return Val{ .boolean = true };
}

/// Rozdělit řetězec
pub fn splitNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 2) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 2 }, &.{});
        return null;
    }

    if (!args[0].isString() or !args[1].isString()) {
        vm.runtimeErr("Argumenty musí být textové řetězce (text, oddělovač)", .{}, &.{});
        return null;
    }

    const text = args[0].obj.string().repre;
    const separator = args[1].obj.string().repre;

    const list = Object.List.init(vm);

    if (separator.len == 0) {
        // If separator is empty, behavior can vary. Let's just return list with original string or split by char?
        // Usually split by empty string means split by characters.
        // Let's implement split by chars if separator is empty.
        var i: usize = 0;
        while (i < text.len) {
            // Need to handle UTF-8 chars?
            const len = std.unicode.utf8ByteSequenceLength(text[i]) catch 1;
            const char_str = Object.String.copy(vm, text[i .. i + len]);
            list.append(char_str.val());
            i += len;
        }
    } else {
        var it = std.mem.splitSequence(u8, text, separator);
        while (it.next()) |chunk| {
            const chunk_str = Object.String.copy(vm, chunk);
            list.append(chunk_str.val());
        }
    }

    return list.obj.val();
}

/// Nahradit v řetězci
pub fn replaceNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 3) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 3 }, &.{});
        return null;
    }

    if (!args[0].isString() or !args[1].isString() or !args[2].isString()) {
        vm.runtimeErr("Argumenty musí být textové řetězce (text, hledané, nahrazení)", .{}, &.{});
        return null;
    }

    const text = args[0].obj.string().repre;
    const needle = args[1].obj.string().repre;
    const replacement = args[2].obj.string().repre;

    const new_size = std.mem.replacementSize(u8, text, needle, replacement);
    const buffer = vm.allocator.alloc(u8, new_size) catch {
        vm.runtimeErr("Nepodařilo se alokovat paměť pro nový řetězec", .{}, &.{});
        return null;
    };

    _ = std.mem.replace(u8, text, needle, replacement, buffer);

    return Val{ .obj = Object.String.take(vm, buffer) };
}

/// Ořezat bílé znaky
pub fn trimNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    if (!args[0].isString()) {
        vm.runtimeErr("Argument musí být textový řetězec", .{}, &.{});
        return null;
    }

    const text = args[0].obj.string().repre;
    const trimmed = std.mem.trim(u8, text, &std.ascii.whitespace);

    return Val{ .obj = Object.String.copy(vm, trimmed) };
}

/// Importovat a spustit soubor
pub fn importNative(vm: *VM, args: []const Val) ?Val {
    if (args.len != 1) {
        vm.runtimeErr("Nesprávný počet argumentů - dostalo '{}' místo očekávaných '{}'", .{ args.len, 1 }, &.{});
        return null;
    }

    if (!args[0].isString()) {
        vm.runtimeErr("Argument musí být cesta k souboru (řetězec)", .{}, &.{});
        return null;
    }

    const path = args[0].obj.string().repre;

    // Manual stack cleanup: pop args and native function from outer frame stack
    // because wrapper won't do it if we return null (handled).
    vm.stack_count -= args.len + 1;

    const content = std.fs.cwd().readFileAlloc(vm.allocator, path, std.math.maxInt(usize)) catch |err| {
        vm.runtimeErr("Nepodařilo se přečíst soubor '{s}', chyba: {}", .{ path, err }, &.{});
        return null;
    };
    defer vm.allocator.free(content);

    vm.load(content, path) catch {
        // Compile error should have been reported already by load->compile
        return null;
    };

    return null; // Return null to indicate "Handled" (wrapper checks had_error)
}
