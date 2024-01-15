const std = @import("std");
const builtin = @import("builtin");
const clap = @import("lib/zig-clap/clap.zig");

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

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("readline/readline.h");
    @cInclude("readline/history.h");
});

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
    var vm = VM.init(allocator, &reporter);

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
        std.process.exit(74);
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
        std.process.exit(74);
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
    defer vm.deinit();

    if (builtin.os.tag == .windows) {
        while (true) {
            try shared.stdout.print(">>> ", .{});

            const stdin = std.io.getStdIn().handle;
            var data: [256]u16 = undefined;
            var read: u32 = undefined;
            _ = ReadConsoleW(stdin, &data, data.len, &read, null);

            var utf8: [1024]u8 = undefined;
            const utf8_len = try std.unicode.utf16leToUtf8(&utf8, data[0..read]);
            const source = utf8[0 .. utf8_len - 1]; // - \n

            vm.interpret(source) catch {};
        }
    } else {
        c.using_history();
        var path: [:0]const u8 = try std.fs.path.joinZ(allocator, &.{ std.os.getenv("HOME") orelse ".", "/.vyq_history" });
        defer allocator.free(path);
        _ = c.read_history(path.ptr);
        c.stifle_history(MAX_HISTORY);

        c.rl_attempted_completion_function = History.completion;

        while (true) {
            const line = c.readline(">>> ") orelse @panic("");
            c.add_history(line);
            if (c.strcmp(c.history_get(c.history_length - 1).*.line, line) != 0) {
                _ = c.write_history(path.ptr);
            }

            try vm.interpret(std.mem.span(line));
        }
    }
}

/// Spustit program ze souboru
fn runFile(allocator: Allocator, filename: []const u8, vm: *VM) !void {
    const source = std.fs.cwd().readFileAlloc(
        allocator,
        filename,
        1_000_000,
    ) catch {
        Reporter.printErr("Soubor nebyl nalezen", .{}) catch {
            @panic("Hodnotu se nepodařilo vypsat");
        };
        std.process.exit(70);
    };
    defer allocator.free(source);

    vm.interpret(source) catch {};
    defer vm.deinit();
}

/// Získat podle debug modu přiřazený allocator
fn getAllocatorType() if (debug.test_alloc) GPA(.{}) else ArenaAlloc {
    return if (debug.test_alloc)
        GPA(.{}){}
    else
        ArenaAlloc.init(std.heap.page_allocator);
}
