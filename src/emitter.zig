const std = @import("std");
const shared = @import("shared.zig");
const debug = @import("debug.zig");
const Allocator = std.mem.Allocator;

const _value = @import("value.zig");
const FunctionType = _value.FunctionType;
const Val = _value.Val;
const Function = _value.Object.Function;
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

const ELV = struct { idx: u8, is_local: bool };

pub const Emitter = struct {
    const Self = @This();

    function: *Function,

    allocator: Allocator,
    vm: *VM,
    parser: ?Parser = null,
    reporter: *Reporter,

    wrapped: ?*Emitter,

    locals: localArray,
    scope_depth: i16,

    elvs: [255]ELV = undefined,
    elv_count: usize = 0,

    /// Inicializace Emitteru
    pub fn init(vm: *VM, func_type: FunctionType, wrapped: ?*Emitter) Self {
        var locals = localArray.init(vm.allocator);

        // aktuální funkce
        locals.append(.{
            .depth = 0,
            .name = "",
            .is_const = false,
        }) catch {};

        return .{
            .allocator = vm.allocator,
            .vm = vm,
            .reporter = vm.reporter,
            .locals = locals,
            .scope_depth = 0,
            .wrapped = wrapped,
            .function = Function.init(vm, func_type),
        };
    }

    // Emit returnu a disassemble pokud debug mod
    pub fn deinit(self: *Self) void {
        self.locals.deinit();
    }

    /// Kompilace
    pub fn compile(self: *Self, source: []const u8) ResultError!*Function {
        self.reporter.reset();

        self.parser = Parser.init(self.allocator, self, self.vm, self.reporter);
        self.vm.parser = &(self.parser.?);

        self.parser.?.parse(source);

        const func = self.parser.?.deinit();
        if (self.reporter.had_error) return ResultError.compile;

        return func;
    }

    /// Získat aktuální blok
    pub fn currentBlock(self: *Self) *Block {
        return &self.function.block;
    }

    /// Zapsat instrukci do bloku přes opcode
    pub fn emitOpCode(self: *Self, op_code: Block.OpCode, loc: Location) void {
        self.currentBlock().writeOp(op_code, loc);
    }

    /// Zapsat byte do bloku
    pub fn emitByte(self: *Self, byte: u8, loc: Location) void {
        self.currentBlock().writeOpByte(byte, loc);
    }

    /// Zapis hodnotu do bloku
    pub fn emitValue(self: *Self, val: Val, loc: Location) void {
        self.emitOpCodes(.op_value, self.createVal(val), loc);
    }

    /// Zapsat instrukce do bloku
    pub fn emitOpCodes(self: *Self, op1: Block.OpCode, op2: u8, loc: Location) void {
        self.currentBlock().writeOp(op1, loc);
        self.currentBlock().writeOpByte(op2, loc);
    }

    /// Přidání hodnoty do aktuálního bloku
    pub fn createVal(self: *Self, val: Val) u8 {
        self.vm.push(val);
        const index = self.currentBlock().addVal(val);
        _ = self.vm.pop();

        if (index > std.math.maxInt(u8)) {
            self.reporter.reportCompile("Přidali jste příliš mnoho hodnot do jedné funkce");
            return 0;
        }

        return @intCast(index);
    }
};
