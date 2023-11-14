const std = @import("std");
const shared = @import("shared.zig");
const debug = @import("debug.zig");
const Allocator = std.mem.Allocator;

const Val = @import("value.zig").Val;
const ResultError = shared.ResultError;
const Reporter = @import("reporter.zig");
const _scanner = @import("scanner.zig");
const Scanner = _scanner.Scanner;
const Location = _scanner.Location;
const Parser = @import("parser.zig").Parser;
const Token = @import("token.zig").Token;
const Block = @import("block.zig").Block;
const VM = @import("virtualmachine.zig").VirtualMachine;
const Local = @import("storage.zig").Local;

const localArray = std.ArrayList(Local);

pub const Emitter = struct {
    const Self = @This();

    allocator: Allocator,
    vm: *VM,
    parser: ?Parser = null,
    block: ?*Block = null,
    reporter: *Reporter,

    wrapped: ?*Emitter,

    locals: localArray,
    scope_depth: i32,

    /// Inicializace Emitteru
    pub fn init(allocator: Allocator, vm: *VM, emitter: ?*Self) Self {
        return .{
            .allocator = allocator,
            .vm = vm,
            .reporter = vm.reporter,
            .locals = localArray.init(allocator),
            .scope_depth = 0,
            .wrapped = emitter,
        };
    }

    // Emit returnu a disassemble pokud debug mod
    pub fn deinit(self: *Self) void {
        self.locals.deinit();
        self.emitOpCode(.op_return, self.parser.?.previous.location);
        if (!self.reporter.had_error and debug.debugging) {
            debug.disBlock(self.currentBlock(), "code");
        }
    }

    /// Kompilace
    pub fn compile(self: *Self, source: []const u8, block: *Block) ResultError!void {
        self.reporter.had_error = false;
        self.reporter.panic_mode = false;

        self.parser = Parser.init(self.allocator, self, self.vm, self.reporter);
        self.block = block;
        self.parser.?.parse(source);

        self.deinit();
        if (self.reporter.had_error) return ResultError.compile;
    }

    /// Získat aktuální blok
    pub fn currentBlock(self: *Self) *Block {
        return self.block.?;
    }

    /// Zapsat instrukci do bloku
    pub fn emitOpCode(self: *Self, op_code: Block.OpCode, loc: Location) void {
        self.currentBlock().writeOp(op_code, loc);
    }

    pub fn emitByte(self: *Self, byte: u8, loc: Location) void {
        self.currentBlock().writeOpByte(byte, loc);
    }

    /// Zapis hodnotu do bloku
    pub fn emitValue(self: *Self, val: Val, loc: Location) void {
        self.emitOpCodes(.op_value, self.makeValue(val), loc);
    }

    /// Zapsat instrukce do bloku
    pub fn emitOpCodes(self: *Self, op1: Block.OpCode, op2: u8, loc: Location) void {
        self.currentBlock().writeOp(op1, loc);
        self.currentBlock().writeOpByte(op2, loc);
    }

    /// Přidání hodnoty do aktuálního bloku
    pub fn makeValue(self: *Self, val: Val) u8 {
        const value = self.currentBlock().addValue(val);
        if (value > 255) @panic("Stack overflow");

        return value;
    }
};
