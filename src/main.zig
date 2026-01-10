const std = @import("std");
const builtin = @import("builtin");
const WINAPI: std.builtin.CallingConvention = if (builtin.cpu.arch == .x86) .stdcall else .c;
const BuildOptions = @import("build_options");
const clap = @import("clap");

const debug = @import("debug.zig");
const shared = @import("shared.zig");
const Scanner = @import("scanner.zig").Scanner;
const _token = @import("token.zig");
const Token = _token.Token;
const VM = @import("virtualmachine.zig").VirtualMachine;
const Block = @import("block.zig").Block;
const Reporter = @import("reporter.zig");
const _benchmark = @import("utils/benchmark.zig");
const BenchMark = _benchmark.BenchMark;
const Timer = _benchmark.Timer;

const History = @import("history.zig");

const File = std.fs.File;
const Allocator = std.mem.Allocator;
const SplitIterator = std.mem.SplitIterator;

const GPA = std.heap.GeneralPurposeAllocator;
const ArenaAlloc = std.heap.ArenaAllocator;

extern "kernel32" fn SetConsoleCP(wCodePageID: u32) callconv(WINAPI) i32;
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: u32) callconv(WINAPI) i32;
extern "kernel32" fn ReadConsoleW(handle: std.posix.fd_t, buffer: [*]u16, len: u32, read: *u32, input_ctrl: ?*void) i32;

const MAX_HISTORY = 250;

/// Inicializace individuálních částí a spuštení dle modu
pub fn main() !void {
    if (builtin.os.tag == .windows) {
        std.debug.assert(SetConsoleCP(65001) != 0);
        _ = SetConsoleOutputCP(65001);

        const handle = std.os.windows.kernel32.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE);
        if (handle) |h| {
            var mode: u32 = 0;
            if (std.os.windows.kernel32.GetConsoleMode(h, &mode) != 0) {
                mode |= 0x0004; // ENABLE_VIRTUAL_TERMINAL_PROCESSING
                _ = std.os.windows.kernel32.SetConsoleMode(h, mode);
            }
        }
    }

    const heap = getAllocatorType();
    defer _ = heap.deinit();
    const allocator = heap.allocator();

    var reporter = Reporter{ .allocator = allocator };
    var vm = VM.create(allocator);
    defer vm.destroy();
    vm.init(&reporter);

    var bench: BenchMark = undefined;
    var timer: *Timer = undefined;
    if (debug.benchmark) {
        bench = BenchMark.init(allocator);
        timer = bench.createMark("main");
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    arguments(allocator, vm) catch |err| {
        Reporter.printErr("Chyba: {}", .{err}) catch @panic("Hodnotu se nepodařilo vypsat");
    };

    if (debug.benchmark) {
        timer.end();
        try bench.printTimers();
        defer {
            bench.deinit();
        }
    }
}

/// Parsování argumentů při spuštení programu
fn arguments(allocator: Allocator, vm: *VM) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --pomoc            Zobraz pomoc a použití
        \\-v, --verze            Zobraz verzi
        \\-b, --bezbarev         Vypisování bez barev
        \\<FILE>...
        \\
    );

    const parsers = comptime .{ .FILE = clap.parsers.string };

    var res = try clap.parse(
        clap.Help,
        &params,
        parsers,
        .{ .allocator = allocator },
    );
    defer res.deinit();

    if (res.args.verze == 1) {
        try shared.stdout.print("{s}", .{BuildOptions.version});
        return;
    }

    if (res.args.pomoc == 1) {
        try shared.stdout.print(
            \\Použití:
            \\  > vyq [cesta k souboru] [argumenty]
            \\
            \\Argumenty:
            \\  -h, --pomoc      Zobraz pomoc a použití
            \\  -v, --verze      Zobraz verzi
            \\  --bezbarev       Vypisování bez barev
            \\
        , .{});
        return;
    }

    if (res.args.bezbarev == 1) {
        vm.reporter.nocolor = true;
    }

    if (res.positionals.len > 0 and res.positionals[0].len > 0) {
        vm.reporter.file = res.positionals[0][0];
        runFile(allocator, res.positionals[0][0], vm) catch |err| {
            Reporter.printErr("Chyba při běhu skriptu: {}", .{err}) catch {};
            std.process.exit(1);
        };
    } else {
        vm.reporter.file = "REPL";
        repl(allocator, vm) catch {};
    }
}

/// Read-Eval-Print loop mod
fn repl(allocator: Allocator, vm: *VM) !void {
    if (builtin.os.tag == .windows) {
        while (true) {
            try shared.stdout.print(">>> ", .{});

            const stdin = std.os.windows.kernel32.GetStdHandle(std.os.windows.STD_INPUT_HANDLE).?;
            var data: [256]u16 = undefined;
            var read: u32 = 0;
            if (ReadConsoleW(stdin, &data, data.len, &read, null) == 0) {
                break;
            }

            var utf8: [1024]u8 = undefined;
            const utf8_len = try std.unicode.utf16LeToUtf8(&utf8, data[0..read]);
            if (utf8_len > 0) {
                const source = utf8[0 .. utf8_len - 1]; // Assuming stripping newline?
                vm.interpret(source) catch {};
            }
        }
    } else if (builtin.os.tag == .macos) {
        while (true) {
            var buf: [256]u8 = undefined;
            var buf_stream = std.io.fixedBufferStream(&buf);

            try shared.stdout.print(">>> ", .{});

            const stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };
            var stdin_buf: [4096]u8 = undefined;
            stdin_file.reader(&stdin_buf).streamUntilDelimiter(
                buf_stream.writer(),
                '\n',
                buf.len,
            ) catch {
                @panic("Nepodařilo se načíst vstup z terminálu");
            };
            const input = std.mem.trim(u8, buf_stream.getWritten(), "\n\r");

            if (input.len == buf.len) {
                try Reporter.printErr("Vstup je příliš dlouhý", .{});
                try stdin_file.reader(&stdin_buf).skipUntilDelimiterOrEof('\n');
                continue;
            }
            const source = buf[0..input.len];
            vm.interpret(source) catch {};
        }
    } else {
        const c = @cImport({
            @cInclude("stdio.h");
            @cInclude("readline/readline.h");
            @cInclude("readline/history.h");
        });
        c.using_history();
        const path: [:0]const u8 = try std.fs.path.joinZ(allocator, &.{ std.posix.getenv("HOME") orelse ".", "/.vyq/history" });
        defer allocator.free(path);
        _ = c.read_history(path.ptr);
        c.stifle_history(MAX_HISTORY);

        c.rl_attempted_completion_function = History.completion;

        while (true) {
            const line = c.readline(">>> ") orelse @panic("Nepodařilo se přečíst hodnotu z terminálu");
            c.add_history(line);

            const last_line = c.history_get(c.history_length - 1);
            if (last_line == null) {
                _ = c.write_history(path.ptr);
            } else if (c.strcmp(last_line.*.line, line) != 0) {
                _ = c.write_history(path.ptr);
            } else {
                _ = c.remove_history(c.history_length - 1);
            }
            vm.interpret(std.mem.span(line)) catch {};
        }
    }
}

/// Spustit program ze souboru
fn runFile(allocator: Allocator, filename: []const u8, vm: *VM) !void {
    const source = std.fs.cwd().readFileAlloc(
        allocator,
        filename,
        1024 * 1024,
    ) catch {
        Reporter.printErr("Soubor nebyl nalezen", .{}) catch {
            @panic("Hodnotu se nepodařilo vypsat");
        };
        return;
    };
    defer allocator.free(source);

    vm.interpret(source) catch |err| {
        return err;
    };
}

/// Získat podle debug modu přiřazený allocator
fn getAllocatorType() if (debug.test_alloc) GPA(.{}) else type {
    return if (debug.test_alloc)
        GPA(.{}){}
    else
        struct {
            fn allocator() std.mem.Allocator {
                return std.heap.c_allocator;
            }

            fn deinit() void {}
        };
}
