const std = @import("std");
const shared = @import("shared.zig");
const debug = @import("debug.zig");
const Allocator = std.mem.Allocator;

const Val = @import("value.zig").Val;
const ResultError = shared.ResultError;
const Reporter = @import("reporter.zig");
const Scanner = @import("scanner.zig").Scanner;
const Parser = @import("parser.zig").Parser;
const Token = @import("token.zig").Token;
const Block = @import("block.zig").Block;
const VM = @import("virtualmachine.zig").VirtualMachine;

pub const Emitter = struct {
    const Self = @This();

    allocator: Allocator,
    vm: *VM,
    parser: ?Parser = null,
    block: ?*Block = null,
    reporter: Reporter,

    /// Inicializace Emitteru
    pub fn init(allocator: Allocator, vm: *VM) Self {
        return .{ .allocator = allocator, .vm = vm, .reporter = Reporter{ .allocator = allocator } };
    }

    // Emit returnu a disassemble pokud debug mod
    pub fn deinit(self: *Self) void {
        self.emitOpCode(.op_return, self.parser.?.previous.line);
        if (!self.reporter.had_error and debug.debugging) {
            debug.disBlock(self.currentChunk(), "code");
        }
    }

    /// Kompilace
    pub fn compile(self: *Self, source: []const u8, block: *Block) ResultError!void {
        self.parser = Parser.init(self.allocator, self, self.vm, &self.reporter);
        self.block = block;
        self.parser.?.parse(source);

        self.deinit();
        if (self.reporter.had_error) return ResultError.compile;
    }

    /// Získat aktuální blok
    pub fn currentChunk(self: *Self) *Block {
        return self.block.?;
    }

    /// Zapsat instrukci do bloku
    pub fn emitOpCode(self: *Self, op_code: Block.OpCode, line: u32) void {
        self.currentChunk().writeOp(op_code, line) catch {};
    }

    /// Zapis hodnotu do bloku
    pub fn emitValue(self: *Self, val: Val, line: u32) !void {
        self.emitOpCodes(.op_value, try self.makeValue(val), line);
    }

    /// Zapsat instrukce do bloku
    pub fn emitOpCodes(self: *Self, op1: Block.OpCode, op2: u8, line: u32) void {
        self.currentChunk().writeOp(op1, line) catch {};
        self.currentChunk().writeOpByte(op2, line) catch {};
    }

    /// Přidání hodnoty do aktuálního bloku
    pub fn makeValue(self: *Self, val: Val) !u8 {
        const value = try self.currentChunk().addValue(val);
        if (value > 255) {
            // TODO
            @panic("Overflow");
        }

        return value;
    }
};
