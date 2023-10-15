const std = @import("std");
const clap = @import("lib/zig-clap/clap.zig");

const debug = @import("debug.zig");
const shared = @import("shared.zig");
const Scanner = @import("scanner.zig").Scanner;
const Token = @import("token.zig").Token;
const VM = @import("virtualmachine.zig").VirtualMachine;
const Block = @import("block.zig").Block;
const _benchmark = @import("utils/benchmark.zig");
const BenchMark = _benchmark.BenchMark;
const Timer = _benchmark.Timer;

const File = std.fs.File;
const Allocator = std.mem.Allocator;
const SplitIterator = std.mem.SplitIterator;

const GPA = std.heap.GeneralPurposeAllocator;
const ArenaAlloc = std.heap.ArenaAllocator;

/// Inicializace individuálních částí a spuštení dle modu
pub fn main() !void {
    var heap = getAllocatorType();
    defer heap.deinit();
    const allocator = heap.allocator();

    var vm = VM.init(allocator);

    var bench: BenchMark = undefined;
    var timer: *Timer = undefined;
    if (debug.benchmark) {
        bench = BenchMark.init(allocator);
        timer = try bench.createMark("main");
    }

    try shared.initLogger(allocator);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    try arguments();

    switch (args.len) {
        1 => repl(allocator, &vm) catch {},
        2 => runFile(allocator, args[1], &vm) catch {},
        else => try shared.logger.err( // TODO
            \\Chyba: Neznámý počet argumentů
            \\
            \\Použití:
            \\> vyq [filepath] [argumenty]
            \\
        , .{}),
    }

    if (debug.benchmark) {
        timer.end();
        try bench.printTimers();
        defer {
            bench.deinit();
        }
    }
}

/// Read-Eval-Print loop mod
fn repl(allocator: Allocator, vm: *VM) !void {
    _ = allocator; // TODO?

    while (true) {
        var buf: [256]u8 = undefined;
        var buf_stream = std.io.fixedBufferStream(&buf);

        try shared.stdout.print(">>> ", .{});

        std.io.getStdIn().reader().streamUntilDelimiter(buf_stream.writer(), '\n', buf.len) catch {};
        const input = std.mem.trim(u8, buf_stream.getWritten(), "\n\r");

        if (input.len == buf.len) {
            try printErr("Vstup je příliš dlouhý", .{});
            continue;
        }
        const source = buf[0..input.len];
        vm.interpret(source) catch {};
    }
    defer vm.deinit();
}

/// Spustit program ze souboru
fn runFile(allocator: Allocator, filename: []const u8, vm: *VM) !void {
    const source = std.fs.cwd().readFileAlloc(allocator, filename, 1_000_000) catch {
        try printErr("Soubor nebyl nalezen", .{});
        std.process.exit(70);
    };
    defer allocator.free(source);

    vm.interpret(source) catch {};
    defer vm.deinit();
}

/// Parsování argumentů při spuštení programu
fn arguments() !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Zobraz pomoc a použití 
        \\-v, --version          Zobraz verzi
        \\<str>...
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{ .diagnostic = &diag }) catch |err| {
        diag.report(shared.stdout, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.version == 1) {
        try shared.stdout.print("{s}\n", .{shared.version});
        std.process.exit(74);
    }

    if (res.args.help == 1) {
        try shared.stdout.print(
            \\Použití:
            \\  > vyq [cesta k souboru] [argumenty]
            \\
            \\Argumenty:
            \\  -h, --help      Zobraz pomoc a použití
            \\  -v, --version   Zobraz verzi
            \\
        , .{});
        std.process.exit(74);
    }
}

fn printErr(comptime message: []const u8, args: anytype) !void {
    try shared.stdout.print("\x1b[31mChyba\x1b[m: ", .{});
    try shared.stdout.print(message ++ "\n", args);
}

/// Získat podle debug modu přiřazený allocator
fn getAllocatorType() if (debug.test_alloc) GPA(.{}) else ArenaAlloc {
    return if (debug.test_alloc)
        GPA(.{}){}
    else
        ArenaAlloc.init(std.heap.page_allocator);
}
