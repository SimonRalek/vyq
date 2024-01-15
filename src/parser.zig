const std = @import("std");
const shared = @import("shared.zig");
const debug = @import("debug.zig");

const Allocator = std.mem.Allocator;
const VM = @import("virtualmachine.zig").VirtualMachine;

const ResultError = shared.ResultError;
const Val = @import("value.zig").Val;
const _token = @import("token.zig");
const Token = _token.Token;
const Scanner = @import("scanner.zig").Scanner;
const Block = @import("block.zig").Block;
const Emitter = @import("emitter.zig").Emitter;
const Reporter = @import("reporter.zig");
const _val = @import("value.zig");
const Object = _val.Object;
const FunctionType = _val.FunctionType;
const _storage = @import("storage.zig");
const Local = _storage.Local;

const Precedence = enum(u8) {
    none,
    assignment,
    nebo,
    zaroven,
    equal,
    compare,
    term,
    bit,
    shift,
    factor,
    unary,
    call,
    primary,
};

const ParseFn = *const fn (self: *Parser, assignable: bool) anyerror!void;

const ParseRule = struct {
    infix: ?ParseFn = null,
    prefix: ?ParseFn = null,
    precedence: Precedence = .none,
};

pub const Parser = struct {
    const Self = @This();

    allocator: Allocator,
    previous: Token,
    current: Token,
    scanner: ?Scanner = null,
    emitter: *Emitter,
    vm: *VM = undefined,
    reporter: *Reporter,

    pub fn init(
        allocator: Allocator,
        emitter: *Emitter,
        vm: *VM,
        reporter: *Reporter,
    ) Parser {
        return .{
            .allocator = allocator,
            .emitter = emitter,
            .vm = vm,
            .reporter = reporter,
            .current = undefined,
            .previous = undefined,
        };
    }

    pub fn deinit(self: *Self) *Object.Function {
        self.emitReturn();

        const function = self.emitter.function;
        if (!self.reporter.had_error and debug.debugging) {
            debug.disBlock(self.currentBlock(), if (function.name) |name| name else "script");
        }

        if (self.emitter.wrapped) |emitter| {
            self.emitter = emitter;
        }

        return function;
    }

    pub fn parse(self: *Self, source: []const u8) void {
        self.scanner = Scanner.init(source);
        self.advance();

        while (!self.check(.eof)) {
            self.declaration();
        }
    }

    fn advance(self: *Self) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.?.scan();
            if (self.current.type != .chyba) break;

            self.report(&self.current, self.current.message.?);
        }
    }

    fn eat(self: *Self, expected: _token.Type, message: []const u8) void {
        if (self.check(expected)) {
            self.advance();
            return;
        }

        self.report(&self.current, message);
    }

    fn match(self: *Self, expected: _token.Type) bool {
        const result = self.check(expected);
        defer {
            if (result) self.advance();
        }
        return result;
    }
    //
    // fn getCurrent(self: *Self) _token.Type {
    //     defer self.advance();
    //     return self.current.type;
    // }

    fn check(self: *Self, expected: _token.Type) bool {
        return expected == self.current.type;
    }

    fn currentBlock(self: *Self) *Block {
        return self.emitter.currentBlock();
    }

    fn emitOpCode(self: *Self, op_code: Block.OpCode) void {
        self.emitter.emitOpCode(op_code, self.previous.location);
    }

    fn emitVal(self: *Self, val: Val) void {
        self.emitter.emitValue(val, self.previous.location);
    }

    fn emitByte(self: *Self, byte: u8) void {
        self.emitter.emitByte(byte, self.previous.location);
    }

    fn emitJmp(self: *Self, op: Block.OpCode) usize {
        self.emitOpCode(op);
        self.emitByte(0xff);
        self.emitByte(0xff);
        return self.currentBlock().code.items.len - 2;
    }

    fn emitLoop(self: *Self, start: usize) void {
        self.emitJmpBack(.op_loop, start);
    }

    fn emitJmpBack(self: *Self, jump: Block.OpCode, start: usize) void {
        self.emitOpCode(jump);

        const idx = self.currentBlock().code.items.len - start + 2;
        if (idx > std.math.maxInt(u16)) self.report(&self.current, "Přeskočení řádků může být maximálně o 65535 míst");

        self.emitByte(@intCast((idx >> 8) & 0xff));
        self.emitByte(@intCast(idx & 0xff));
    }

    fn emitReturn(self: *Self) void {
        self.emitOpCode(.op_nic);
        self.emitOpCode(.op_return);
    }

    fn patchJmp(self: *Self, idx: usize) void {
        const jmp = self.currentBlock().code.items.len - idx - 2;

        if (jmp > std.math.maxInt(u16)) {
            self.report(&self.current, "Dosažen nejvyšší počet příkazů přes které se dá přeskočit");
        }

        self.currentBlock().code.items[idx] = @intCast((jmp >> 8) & 0xff);
        self.currentBlock().code.items[idx + 1] = @intCast(jmp & 0xff);
    }

    fn makeVal(self: *Self, val: Val) u8 {
        return self.emitter.makeValue(val);
    }

    fn report(self: *Self, token: *Token, message: []const u8) void {
        self.reporter.report(ResultError.parser, token, message);
    }

    fn warn(self: *Self, token: *Token, message: []const u8) void {
        self.reporter.warn(token, message);
    }

    fn declaration(self: *Self) void {
        if (self.match(.prm) or self.match(.konst)) {
            self.variableDeclaration() catch {};
        } else if (self.match(.funkce)) {
            self.functionDeclaration();
        } else {
            self.statement();
        }

        if (self.reporter.panic_mode) self.synchronize();
    }

    fn expression(self: *Self) void {
        self.parsePrecedence(.assignment);
        if (self.match(.question_mark)) {
            self.ternaryOperator();
        }
    }

    fn ternaryOperator(self: *Self) void {
        const jmp = self.emitJmp(.op_jmp_on_false);
        self.emitOpCode(.op_pop);
        self.expression();
        if (!self.match(.colon)) {
            self.report(&self.current, "Chybí ':' v ternárním operátoru");
        }
        const thenJmp = self.emitJmp(.op_jmp);
        self.patchJmp(jmp);
        self.emitOpCode(.op_pop);
        self.expression();
        self.patchJmp(thenJmp);
    }

    fn statement(self: *Self) void {
        if (self.match(.tiskni) or self.match(.tiskniN)) {
            self.printStmt();
        } else if (self.match(.left_brace)) {
            self.beginScope();
            self.block();
            self.endScope();
        } else if (self.match(.pokud)) {
            self.ifStmt();
        } else if (self.match(.opakuj)) {
            self.forStmt();
        } else if (self.match(.dokud)) {
            self.whileStmt();
        } else if (self.match(.vrat)) {
            self.returnStmt();
        } else if (self.match(.vyber)) {
            self.switchStmt();
        } else {
            self.exprStmt();
        }
    }

    fn block(self: *Self) void {
        while (!self.check(.right_brace) and !self.check(.eof)) {
            self.declaration();
        }

        self.eat(.right_brace, "Očekávaná '}' na konci bloku");
    }

    fn beginScope(self: *Self) void {
        self.emitter.scope_depth += 1;
    }

    fn endScope(self: *Self) void {
        self.emitter.scope_depth -= 1;

        var locals = &self.emitter.locals;
        while (locals.items.len > 0 and locals.items[locals.items.len - 1].depth > self.emitter.scope_depth) {
            if (locals.items[locals.items.len - 1].is_captured) {
                self.emitOpCode(.op_close_elv);
            } else {
                self.emitOpCode(.op_pop);
                _ = self.emitter.locals.pop();
            }
        }
    }

    fn variableDeclaration(self: *Self) !void {
        var is_const = self.previous.type == .konst;

        const glob = try self.parseVar("Očekávané jméno prvku po 'prm'");

        if (self.match(.assign)) {
            self.expression();
        } else {
            if (is_const) {
                self.warn(&self.previous, "Inicializace konstanty s prázdnou hodnotou");
            }
            self.emitOpCode(.op_nic);
        }

        self.eat(.semicolon, "Očekávaná ';' za výrazem");

        self.defineVar(glob, is_const);
    }

    fn defineVar(self: *Self, glob: u8, is_const: bool) void {
        if (self.emitter.scope_depth > 0) {
            self.markInit();
            return;
        }

        self.emitter.emitOpCodes(
            if (is_const) .op_def_glob_const else .op_def_glob_var,
            glob,
            self.current.location,
        );
    }

    fn markInit(self: *Self) void {
        if (self.emitter.scope_depth == 0) return;
        var locals = &self.emitter.locals;

        locals.items[locals.items.len - 1].depth = self.emitter.scope_depth;
    }

    fn declareVar(self: *Self, is_const: bool) void {
        if (self.emitter.scope_depth == 0) return;

        var name = &self.previous;

        var i: usize = 0;
        const locals = &self.emitter.locals;
        while (i < locals.items.len) : (i += 1) {
            const loc = locals.items[locals.items.len - 1 - i];
            if (loc.depth != -1 and loc.depth < self.emitter.scope_depth) break;

            if (std.mem.eql(u8, name.lexeme, loc.name)) {
                self.warn(
                    &self.current,
                    "Proměnná s tímto jménem již existuje v daném kontextu",
                );
            }
        }

        self.addLocal(name.lexeme, is_const);
    }

    fn parseVar(self: *Self, message: []const u8) ResultError!u8 {
        var is_const = self.previous.type == .konst;

        if (self.match(.dot)) {
            self.report(&self.current, "Pro jméno prvku nelze použít '.'");
            return ResultError.parser;
        }
        self.eat(.identifier, message);

        self.declareVar(is_const);
        if (self.emitter.scope_depth > 0) return 0;

        return self.makeVal(
            Val{ .obj = Object.String.copy(self.vm, self.previous.lexeme) },
        );
    }

    fn variable(self: *Self, assignable: bool) !void {
        self.advance();
        const token = &self.previous;
        try self.namedVar(token, assignable);
    }

    fn namedVar(self: *Self, token: *Token, assignable: bool) !void {
        var get_op: Block.OpCode = undefined;
        var set_op: Block.OpCode = undefined;
        var arg = self.resolveLocal(self.emitter, token);

        if (token.type != .identifier) {
            self.report(token, "Po tečce se očekává jméno prvku");
            return ResultError.parser;
        }

        if (arg[0] != null) {
            get_op = .op_get_loc;
            set_op = .op_set_loc;
        } else {
            if (self.resolveELV(self.emitter, token)) |new| {
                arg[0] = @intCast(new);
                get_op = .op_get_elv;
                set_op = .op_set_elv;
            } else {
                arg = .{
                    self.makeVal(Val{
                        .obj = Object.String.copy(self.vm, token.lexeme),
                    }),
                    false,
                };
                get_op = .op_get_glob;
                set_op = .op_set_glob;
            }
        }

        if (arg[0]) |index| {
            if (assignable and self.match(.assign)) {
                if (arg[1]) {
                    self.report(&self.previous, "Nelze změnit hodnotu konstanty");
                    return ResultError.compile;
                }
                self.expression();
                self.emitter.emitOpCodes(
                    set_op,
                    @intCast(index),
                    self.current.location,
                );
            } else if (assignable and self.isAdditionalOperator()) {
                if (arg[1]) {
                    self.report(&self.previous, "Nelze změnit hodnotu konstanty");
                    return ResultError.compile;
                }
                const operator = self.previous.type;

                self.emitter.emitOpCodes(
                    get_op,
                    @intCast(index),
                    self.current.location,
                );
                self.expression();

                self.emitOpCode(switch (operator) {
                    .add_operator => .op_add,
                    .min_operator => .op_sub,
                    .div_operator => .op_div,
                    .mul_operator => .op_mult,
                    else => unreachable,
                });

                self.emitter.emitOpCodes(
                    set_op,
                    @intCast(index),
                    self.current.location,
                );
            } else {
                self.emitter.emitOpCodes(
                    get_op,
                    @intCast(index),
                    self.current.location,
                );
            }
        }
    }

    fn resolveLocal(self: *Self, emitter: *Emitter, token: *Token) struct { ?usize, bool } {
        var locals = &emitter.locals;
        var i: usize = 0;

        while (i < locals.items.len) : (i += 1) {
            const local = locals.items[locals.items.len - 1 - i];
            if (std.mem.eql(u8, token.lexeme, local.name)) {
                if (local.depth == -1) self.report(
                    &self.previous,
                    "Proměnná nelze přiřadit sama sobě",
                );
                var result: usize = locals.items.len - 1 - i;
                return .{ result, local.is_const };
            }
        }

        return .{ null, false };
    }

    fn resolveELV(self: *Self, emitter: *Emitter, token: *Token) ?usize {
        if (emitter.wrapped == null) return null;

        const local = self.resolveLocal(emitter.wrapped.?, token);
        if (local[0]) |elv| {
            emitter.wrapped.?.locals.items[elv].is_captured = true;
            return self.addELV(emitter, @intCast(elv), true);
        }

        const elv = self.resolveELV(emitter.wrapped.?, token);
        if (elv) |idx| {
            return self.addELV(emitter, @intCast(idx), false);
        }

        return null;
    }

    fn addELV(self: *Self, emitter: *Emitter, idx: u8, is_local: bool) usize {
        const count = emitter.function.elv_count;

        if (count == 255) {
            self.report(&self.current, "Příliš mnoho referencovaných proměnných mimo funkci");
            return 0;
        }

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const elv = &emitter.elvs[i];
            if (elv.idx == idx and elv.is_local == is_local) {
                return i;
            }
        }

        emitter.elvs[count].is_local = is_local;
        emitter.elvs[count].idx = idx;

        defer emitter.function.elv_count += 1;

        return emitter.function.elv_count;
    }

    fn addLocal(self: *Self, name: []const u8, is_const: bool) void {
        if (self.emitter.locals.items.len == 256) {
            self.report(&self.current, "Příliš mnoho proměnných");
            return;
        }

        self.emitter.locals.append(
            if (is_const) Local.initKonst(name, -1) else Local.initPrm(name, -1),
        ) catch {
            @panic("Nepadařilo se alokovat");
        };
    }

    fn functionDeclaration(self: *Self) void {
        const glob = self.parseVar("Chybí jméno funkce. Při deklaraci funkce musíte specifikovat jméno, které bude používáno k jejímu volání.") catch return;
        self.markInit();
        self.parseFunction(.function);
        self.defineVar(glob, false);
    }

    fn parseFunction(self: *Self, func_type: FunctionType) void {
        var emitter = Emitter.init(self.vm, func_type, self.emitter);
        defer emitter.deinit();
        self.emitter = &emitter;
        self.emitter.function.name = Object.String.copy(self.vm, self.previous.lexeme).string().repre;
        self.beginScope();

        self.eat(.left_paren, "Chybí '(' po jménu funkce");
        if (!self.check(.right_paren)) {
            while (true) {
                if (self.emitter.function.arity > 255) {
                    self.report(&self.current, "Příliš mnoho parametrů. Maximální počet je 255");
                }

                self.emitter.function.arity += 1;
                const name = self.parseVar("Chybí jméno parametru") catch return;
                self.defineVar(name, false);

                if (!self.match(.semicolon)) break;
            }
        }
        self.eat(.right_paren, "Chybí ')' na konci seznamu paramerů funkce");
        self.eat(.colon, "Chybí ':' po konci seznamu parametrů funkce");
        self.eat(.left_brace, "Chybí '{' pro začátek bloku funkce");
        self.block();

        const func = self.deinit();
        self.emitter.emitOpCodes(.op_closure, self.emitter.makeValue(func.obj.val()), self.previous.location);

        for (0..func.elv_count) |i| {
            const elv = emitter.elvs[i];
            self.emitByte(if (elv.is_local) 1 else 0);
            self.emitByte(elv.idx);
        }
    }

    fn call(self: *Self, assignable: bool) !void {
        _ = assignable;
        const arg_count = self.argumentList();
        self.emitter.emitOpCodes(.op_call, arg_count, self.current.location);
    }

    fn argumentList(self: *Self) u8 {
        var arg_count: u8 = 0;

        if (!self.check(.right_paren)) {
            while (true) {
                if (arg_count == 255)
                    self.report(&self.current, "Příliš mnoho argumentů. Maximální počet je 255.");

                self.expression();
                arg_count += 1;
                if (!self.match(.semicolon)) break;
            }
        }

        self.eat(.right_paren, "Chybí ')' na konci seznamu argumentů funkce.");
        return arg_count;
    }

    fn printStmt(self: *Self) void {
        var token = self.previous;
        self.expression();
        self.eat(.semicolon, "Chybí ';' za příkazem");
        self.emitOpCode(if (token.type == .tiskni) .op_println else .op_print);
    }

    fn ifStmt(self: *Self) void {
        self.expression();
        self.eat(.colon, "Očekávaná ':' za podmínkou");

        const jmp = self.emitJmp(.op_jmp_on_false);
        self.emitOpCode(.op_pop);
        self.statement();

        const else_jmp = self.emitJmp(.op_jmp);

        self.patchJmp(jmp);
        self.emitOpCode(.op_pop);
        if (self.match(.jinak)) self.statement();
        self.patchJmp(else_jmp);
    }

    fn forStmt(self: *Self) void {
        self.beginScope();

        if (self.match(.jako)) {
            var prm = self.parseVar("Očekávané jméno prvku po 'jako'") catch {
                return;
            };

            var token = self.previous;
            self.expression();
            self.defineVar(prm, false);

            var directionUp = true;
            if (!self.match(.until)) {
                directionUp = false;
                self.eat(.dolu, "Očekává se specifikace směru iterace, '..' nebo 'dolu'");
            }

            var start = self.currentBlock().code.items.len;
            self.namedVar(&token, false) catch {
                return;
            };
            self.expression();
            self.emitOpCode(if (directionUp) .op_less else .op_greater);
            const exitJmp = self.emitJmp(.op_jmp_on_false);
            self.emitOpCode(.op_pop);

            const jmp = self.emitJmp(.op_jmp);
            const varStart = self.currentBlock().code.items.len;
            if (!self.check(.colon)) {
                self.eat(.po, "Očekává se ukončení bloku opakování");
                self.namedVar(&token, false) catch {
                    return;
                };
                self.expression();
            } else {
                self.namedVar(&token, false) catch {
                    return;
                };
                self.emitVal(Val{ .number = 1 });
            }
            self.emitOpCode(if (directionUp) .op_add else .op_sub);
            var resolve = self.resolveLocal(self.emitter, &token);
            self.emitter.emitOpCodes(.op_set_loc, @intCast(resolve[0].?), self.previous.location);
            self.emitOpCode(.op_pop);

            self.emitLoop(start);
            start = varStart;
            self.patchJmp(jmp);
            self.eat(.colon, "Očekávaná ':' pro ukončení 'opakuj'");

            self.statement();
            self.emitLoop(start);
            self.patchJmp(exitJmp);
            self.emitOpCode(.op_pop);
        } else {
            if (self.match(.semicolon)) {
                // nic nedělej
            } else if (self.match(.prm)) {
                self.variableDeclaration() catch {};
            } else self.exprStmt();

            var start = self.currentBlock().code.items.len;
            var exit: ?usize = null;

            if (!self.match(.semicolon)) {
                self.expression();
                self.eat(.semicolon, "Očekávaná podmínka nebo ';' pro ukončení iterizační části cyklu 'opakuj'");

                exit = self.emitJmp(.op_jmp_on_false);
                self.emitOpCode(.op_pop);
            }

            if (!self.match(.colon)) {
                const jmp = self.emitJmp(.op_jmp);
                const varStart = self.currentBlock().code.items.len;

                self.expression();
                self.emitOpCode(.op_pop);
                self.eat(.colon, "Očekávaná ':' pro ukončení 'opakuj'");

                self.emitLoop(start);
                start = varStart;
                self.patchJmp(jmp);
            }

            self.statement();
            self.emitLoop(start);

            if (exit) |jmp| {
                self.patchJmp(jmp);
                self.emitOpCode(.op_pop);
            }
        }

        self.endScope();
    }

    fn whileStmt(self: *Self) void {
        const start = self.currentBlock().code.items.len;

        self.expression();
        self.eat(.colon, "Očekávaná ':' za podmínkou");

        const jmp = self.emitJmp(.op_jmp_on_false);
        self.emitOpCode(.op_pop);
        self.statement();
        self.emitLoop(start);

        self.patchJmp(jmp);
        self.emitOpCode(.op_pop);
    }

    fn switchStmt(self: *Self) void {
        self.expression();
        self.eat(.colon, "Očekávaná ':' za hodnotou pro přepínání");
        self.eat(.left_brace, "Očekávaná '{' za ':'");

        var state: u8 = 0;
        var caseEnds: [256]usize = undefined;
        var caseCount: u8 = 0;
        var previousCaseSkip: isize = -1;

        while (!self.match(.right_brace) and !self.check(.eof)) {
            if (self.match(.pripad) or self.match(.jinak)) {
                const caseType = self.previous.type;

                switch (state) {
                    2 => self.report(&self.previous, "Ve 'vyber' může být pouze jeden výchozí případ"),
                    1 => {
                        caseEnds[caseCount] = self.emitJmp(.op_jmp);
                        caseCount += 1;
                        self.patchJmp(@intCast(previousCaseSkip));
                        self.emitOpCode(.op_pop);
                    },
                    else => {},
                }

                if (caseType == .pripad) {
                    state = 1;

                    self.emitOpCode(.op_case);
                    self.expression();
                    self.eat(.arrow, "Očekávaná '->' po případu");

                    self.emitOpCode(.op_equal);
                    previousCaseSkip = @intCast(self.emitJmp(.op_jmp_on_false));

                    self.emitOpCode(.op_pop);
                } else {
                    state = 2;
                    self.eat(.arrow, "Očekávaná '->' po 'jinak'");
                    previousCaseSkip = -1;
                }
            } else {
                if (state == 0) {
                    self.report(&self.previous, "Příkazy mohou být použity pouze v rámci případů nebo výchozího případu ve 'vyber'");
                }
                self.statement();
            }
        }
        if (state == 1) {
            caseEnds[caseCount] = self.emitJmp(.op_jmp);
            caseCount += 1;
            self.patchJmp(@intCast(previousCaseSkip));
            self.emitOpCode(.op_pop);
        }

        for (0..caseCount) |case| {
            self.patchJmp(caseEnds[case]);
        }

        self.emitOpCode(.op_pop);
    }

    fn returnStmt(self: *Self) void {
        if (self.emitter.function.type == .script) {
            self.report(&self.current, "Nelze vrátit hodnotu z hlavního scriptu");
        }

        if (self.match(.semicolon)) {
            self.emitReturn();
        } else {
            self.expression();
            self.eat(.semicolon, "Chybí ';' za příkazem");
            self.emitOpCode(.op_return);
        }
    }

    fn exprStmt(self: *Self) void {
        self.expression();
        self.eat(.semicolon, "Chybí ';' za příkazem");
        self.emitOpCode(.op_pop);
    }

    fn synchronize(self: *Self) void {
        self.reporter.panic_mode = false;

        while (self.current.type != .eof) {
            if (self.previous.type == .semicolon) return;
            switch (self.current.type) {
                .trida, .funkce, .prm, .opakuj, .pokud, .dokud, .tiskni, .vrat => return,
                else => {},
            }
            self.advance();
        }
    }

    fn zaroven(self: *Self, assignable: bool) !void {
        _ = assignable;

        const jmp = self.emitJmp(.op_jmp_on_false);

        self.emitOpCode(.op_pop);
        self.parsePrecedence(.zaroven);

        self.patchJmp(jmp);
    }

    fn nebo(self: *Self, assignable: bool) !void {
        _ = assignable;

        const jmp = self.emitJmp(.op_jmp_on_true);

        self.emitOpCode(.op_pop);

        self.parsePrecedence(.nebo);
        self.patchJmp(jmp);
    }

    fn group(self: *Self, assignable: bool) !void {
        _ = assignable;

        self.expression();
        self.eat(.right_paren, "Očekávaná ')' nebyla nalezena");
    }

    fn unary(self: *Self, assignable: bool) !void {
        _ = assignable;

        const op_type = self.previous.type;

        self.parsePrecedence(.unary);

        switch (op_type) {
            .minus => self.emitOpCode(.op_negate),
            .bang => self.emitOpCode(.op_not),
            .bw_not => {
                self.emitOpCode(.op_bit_not);
            },
            else => unreachable,
        }
    }

    fn binary(self: *Self, assignable: bool) !void {
        _ = assignable;

        const op_type = self.previous.type;
        const rule = getRule(op_type);

        self.parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

        switch (op_type) {
            .plus => {
                self.emitOpCode(.op_add);
            },
            .minus => {
                self.emitOpCode(.op_sub);
            },
            .star => {
                self.emitOpCode(.op_mult);
            },
            .slash => {
                self.emitOpCode(.op_div);
            },
            .equal => {
                self.emitOpCode(.op_equal);
            },
            .not_equal => {
                self.emitOpCode(.op_equal);
                self.emitOpCode(.op_not);
            },
            .greater => {
                self.emitOpCode(.op_greater);
            },
            .greater_equal => {
                self.emitOpCode(.op_less);
                self.emitOpCode(.op_not);
            },
            .less => {
                self.emitOpCode(.op_less);
            },
            .less_equal => {
                self.emitOpCode(.op_greater);
                self.emitOpCode(.op_not);
            },
            .bw_and => {
                self.emitOpCode(.op_bit_and);
            },
            .bw_or => {
                self.emitOpCode(.op_bit_or);
            },
            .bw_xor => {
                self.emitOpCode(.op_bit_xor);
            },
            .shift_left => {
                self.emitOpCode(.op_shift_left);
            },
            .shift_right => {
                self.emitOpCode(.op_shift_right);
            },
            else => {
                unreachable;
            },
        }
    }

    fn number(self: *Self, assignable: bool) !void {
        _ = assignable;

        var buff = try self.allocator.alloc(u8, self.previous.lexeme.len);
        defer self.allocator.free(buff);

        _ = std.mem.replace(u8, self.previous.lexeme, ",", ".", buff);
        const converted: std.fmt.ParseFloatError!f64 = std.fmt.parseFloat(f64, buff);
        if (converted) |value| {
            self.emitVal(Val{ .number = value });
        } else |err| {
            try shared.stdout.print("Nepovedlo se cislo zpracovat: {}", .{err});
        }
    }

    fn base(self: *Self, assignable: bool) !void {
        _ = assignable;

        const val = std.fmt.parseUnsigned(i64, self.previous.lexeme, 0) catch {
            @panic("Parsování nešlo");
        };
        self.emitVal(Val{ .number = @floatFromInt(val) });
    }

    fn crement(self: *Self, assignable: bool) !void {
        _ = assignable;

        switch (self.previous.type) {
            .increment => self.emitOpCode(.op_increment),
            .decrement => self.emitOpCode(.op_decrement),
            else => unreachable,
        }
    }

    fn string(self: *Self, assignable: bool) !void {
        _ = assignable;

        const source = self.previous.lexeme[1 .. self.previous.lexeme.len - 1];
        self.emitVal(Object.String.copy(self.vm, source).val());
    }

    fn literal(self: *Self, assignable: bool) !void {
        _ = assignable;

        switch (self.previous.type) {
            .ano => self.emitOpCode(.op_ano),
            .ne => self.emitOpCode(.op_ne),
            .nic => self.emitOpCode(.op_nic),
            else => unreachable,
        }
    }

    fn parsePrecedence(self: *Self, precedence: Precedence) void {
        self.advance();
        const prefix = getRule(self.previous.type).prefix orelse {
            self.report(&self.current, "Očekávaný výraz");
            return;
        };

        const can_assign = @intFromEnum(precedence) <= @intFromEnum(Precedence.assignment);
        prefix(self, can_assign) catch {};
        while (@intFromEnum(precedence) <= @intFromEnum(getRule(self.current.type).precedence)) {
            self.advance();
            const infix = getRule(self.previous.type).infix orelse unreachable;
            infix(self, can_assign) catch {};
        }

        if (can_assign and self.match(.assign)) {
            self.report(&self.previous, "K hodnotě nelze přiřadit hodnotu");
        }
    }

    fn isAdditionalOperator(self: *Self) bool {
        return self.match(.add_operator) or self.match(.min_operator) or self.match(.div_operator) or self.match(.mul_operator);
    }

    fn getRule(t_type: _token.Type) ParseRule {
        return switch (t_type) {
            .left_paren => .{ .prefix = Parser.group, .infix = Parser.call, .precedence = .call },

            .increment, .decrement => .{ .infix = Parser.crement },

            .number => .{ .prefix = Parser.number },
            .binary, .octal, .hexadecimal => .{ .prefix = Parser.base },

            .ano, .ne, .nic => .{ .prefix = Parser.literal },

            .string => .{ .prefix = Parser.string },

            .plus => .{ .infix = Parser.binary, .precedence = .term },
            .minus => .{ .prefix = Parser.unary, .infix = Parser.binary, .precedence = .term },
            .star, .slash => .{ .infix = Parser.binary, .precedence = .factor },

            .bang => .{ .prefix = Parser.unary },

            .equal, .not_equal => .{ .infix = Parser.binary, .precedence = .equal },
            .greater, .greater_equal, .less, .less_equal => .{ .infix = Parser.binary, .precedence = .compare },

            .bw_and, .bw_or, .bw_xor => .{ .infix = Parser.binary, .precedence = .bit },
            .shift_right, .shift_left => .{ .infix = Parser.binary, .precedence = .shift },

            .zaroven => .{ .infix = Parser.zaroven, .precedence = .zaroven },
            .nebo => .{ .infix = Parser.nebo, .precedence = .nebo },

            .dot => .{ .prefix = Parser.variable },

            else => {
                return .{};
            },
        };
    }
};

fn testParser(source: []const u8, expected: f64) !void {
    var allocator = std.testing.allocator;
    var reporter = Reporter.init(allocator);
    var vm = VM.init(allocator, &reporter);
    try vm.interpret(source);

    try std.testing.expectEqual(expected, vm.stack[0].number);
}

test "simple expressions" {
    try testParser("1 + 2;", 3);
    try testParser("7 - 2 * 3;", 1);
    try testParser("-(4 + (-6)) * 10 /5;", 4);
}
