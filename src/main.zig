const std = @import("std");
const builtin = @import("builtin");
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

extern "kernel32" fn SetConsoleCP(wCodePageID: std.os.windows.UINT) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "kernel32" fn ReadConsoleW(handle: std.os.fd_t, buffer: [*]u16, len: std.os.windows.DWORD, read: *std.os.windows.DWORD, input_ctrl: ?*void) i32;

const MAX_HISTORY = 250;

/// Inicializace individuálních částí a spuštení dle modu
pub fn main() !void {
    if (builtin.os.tag == .windows) {
        std.debug.assert(SetConsoleCP(65001) != 0);
        std.debug.assert(std.os.windows.kernel32.SetConsoleOutputCP(65001) != 0);
    }

    var heap = getAllocatorType();
    defer _ = heap.deinit();
    const allocator = heap.allocator();

    var reporter = Reporter{ .allocator = allocator };
    var vm = VM.create(allocator);
    defer vm.deinit();
    vm.init(&reporter);

    var bench: BenchMark = undefined;
    var timer: *Timer = undefined;
    if (debug.benchmark) {
        bench = BenchMark.init(allocator);
        timer = bench.createMark("main");
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    arguments(allocator, &vm) catch {
        Reporter.printErr("Neznámý argument", .{}) catch @panic("Hodnotu se nepodařilo vypsat");
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
        .{},
    );
    defer res.deinit();

    if (res.args.verze == 1) {
        const version = (std.ChildProcess.exec(.{
            .allocator = allocator,
            .argv = &.{ "git", "describe", "--tags", "--abbrev=0" },
        }) catch {
            unreachable;
        }).stdout;
        try shared.stdout.print("{s}", .{version});
        allocator.free(version);
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

    if (res.positionals.len > 0) {
        vm.reporter.file = res.positionals[0];
        runFile(allocator, res.positionals[0], vm) catch {};
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

            const stdin = std.io.getStdIn().handle;
            var data: [256]u16 = undefined;
            var read: u32 = undefined;
            _ = ReadConsoleW(stdin, &data, data.len, &read, null);

            var utf8: [1024]u8 = undefined;
            const utf8_len = try std.unicode.utf16leToUtf8(&utf8, data[0..read]);
            const source = utf8[0 .. utf8_len - 1];

            vm.interpret(source) catch {};
        }
    } else if (builtin.os.tag == .macos) {
        while (true) {
            var buf: [256]u8 = undefined;
            var buf_stream = std.io.fixedBufferStream(&buf);

            try shared.stdout.print(">>> ", .{});

            std.io.getStdIn().reader().streamUntilDelimiter(
                buf_stream.writer(),
                '\n',
                buf.len,
            ) catch {
                @panic("");
            };
            const input = std.mem.trim(u8, buf_stream.getWritten(), "\n\r");

            if (input.len == buf.len) {
                try Reporter.printErr("Vstup je příliš dlouhý", .{});
                try std.io.getStdIn().reader().skipUntilDelimiterOrEof('\n');
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
        var path: [:0]const u8 = try std.fs.path.joinZ(allocator, &.{ std.os.getenv("HOME") orelse ".", "/.vyq_history" });
        defer allocator.free(path);
        _ = c.read_history(path.ptr);
        c.stifle_history(MAX_HISTORY);

        c.rl_attempted_completion_function = History.completion;

        while (true) {
            const line = c.readline(">>> ") orelse @panic("");
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

    vm.interpret(source) catch {};
}

/// Získat podle debug modu přiřazený allocator
fn getAllocatorType() if (debug.test_alloc) GPA(.{}) else ArenaAlloc {
    return if (debug.test_alloc)
        GPA(.{}){}
    else
        ArenaAlloc.init(std.heap.page_allocator);
}
