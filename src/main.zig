const std = @import("std");
const clap = @import("lib/zig-clap/clap.zig");

const debug = @import("debug.zig");
const shared = @import("shared.zig");

const Scanner = @import("scanner.zig").Scanner;
const Token = @import("token.zig").Token;
const Compiler = @import("compiler.zig").Compiler;
const Parser = @import("parser.zig").Parser;
const VM = @import("virtualmachine.zig").VirtualMachine;
const Block = @import("block.zig").Block;

const File = std.fs.File;
const Allocator = std.mem.Allocator;
const SplitIterator = std.mem.SplitIterator;

pub fn main() !void {
    var heap = if (debug.test_allocator)
        std.heap.GeneralPurposeAllocator(.{}){}
    else
        std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = heap.deinit();
    const allocator = heap.allocator();

    try shared.initLogger(allocator);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try arguments();

    try switch (args.len) {
        1 => repl(allocator),
        2 => runFile(allocator, args[1]),
        else => try shared.logger.err(
            \\Chyba: Neznámý počet argumentů
            \\
            \\Použití:
            \\> vyq [filepath] [argumenty]
            \\
        , .{}),
    };
}

fn repl(allocator: Allocator) !void {
    var vm = VM.init(allocator);

    while (true) {
        var buf: [256]u8 = undefined;
        var buf_stream = std.io.fixedBufferStream(&buf);

        try shared.stdout.print(">>> ", .{});

        shared.stdin.streamUntilDelimiter(buf_stream.writer(), '\n', buf.len) catch {};
        const input = std.mem.trim(u8, buf_stream.getWritten(), "\n\r");

        if (input.len == buf.len) {
            try shared.logger.err("Chyba: Vstup je příliš dlouhý\n", .{});
            continue;
        }
        const source = buf[0..input.len];

        vm.interpret(source) catch {};
    }
}

fn runFile(allocator: Allocator, filename: []const u8) !void {
    const source = std.fs.cwd().readFileAlloc(allocator, filename, 1_000_000) catch {
        try shared.logger.err(
            \\Chyba: Soubor nebyl nalezen
            \\
        , .{});
        std.process.exit(70);
    };
    defer allocator.free(source);

    var parser = Parser.init();
    parser.parse(source);
    // try Compiler.compile(source);
}

fn arguments() !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Zobraz pomoc a použití 
        \\-v, --version          Zobraz verzi
        \\<str>...
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{ .diagnostic = &diag }) catch |err| {
        diag.report(shared.stderr, err) catch {};
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
