const std = @import("std");
const shared = @import("shared.zig");

const Allocator = std.mem.Allocator;

const _val = @import("value.zig");
const Val = _val.Val;
const Block = @import("block.zig").Block;
const ResultError = @import("shared.zig").ResultError;
const Emitter = @import("emitter.zig").Emitter;
const _storage = @import("storage.zig");
const Global = _storage.Global;
const Object = _val.Object;
const Reporter = @import("reporter.zig");

const BinaryOp = enum { sub, mult, div, greater, less, bit_and, bit_or, bit_xor };
const ShiftOp = enum { left, right };

pub const VirtualMachine = struct {
    const Self = @This();

    allocator: Allocator,
    block: *Block = undefined,
    ip: usize,
    stack: [256]Val = undefined,
    stack_top: usize,
    globals: std.StringHashMap(Global),

    strings: std.StringHashMap(*Object.String),
    objects: ?*Object = null,

    reporter: *Reporter,

    /// Inicializace virtuální mašiny
    pub fn init(allocator: Allocator, reporter: *Reporter) Self {
        return .{ .allocator = allocator, .globals = std.StringHashMap(Global).init(allocator), .strings = std.StringHashMap(*Object.String).init(allocator), .ip = 0, .stack_top = 0, .objects = null, .reporter = reporter };
    }

    /// "Free"nout objekty a listy
    pub fn deinit(self: *Self) void {
        self.deinitObjs();
        self.globals.deinit();
        self.strings.deinit();
    }

    /// Projíždění objekt linked listu a free každý objekt
    fn deinitObjs(self: *Self) void {
        var obj = self.objects;
        while (obj) |curr| {
            const next = curr.next;
            curr.deinit(curr, self);
            obj = next;
        }
    }

    /// Setup programu - spuštění kompilace a parsování
    pub fn interpret(self: *Self, source: []const u8) ResultError!void {
        self.reporter.source = source;

        var block = Block.init(self.allocator);
        defer block.deinit();

        var emitter = Emitter.init(self.allocator, self, null);
        emitter.compile(source, &block) catch return ResultError.compile;

        self.block = &block;
        self.ip = 0;

        return self.run();
    }

    /// Běh programu
    fn run(self: *Self) ResultError!void {
        while (true) {
            const instruction: Block.OpCode = @enumFromInt(self.readByte());

            try switch (instruction) {
                .op_value => {
                    var value = self.readValue();
                    self.push(value);
                },
                .op_ano => self.push(Val{ .boolean = true }),
                .op_ne => self.push(Val{ .boolean = false }),
                .op_nic => self.push(Val.nic),

                .op_add => self.add(),
                .op_sub => self.binary(.sub),
                .op_mult => self.binary(.mult),
                .op_div => self.binary(.div),

                .op_increment => {
                    var a = self.pop();

                    if (a != .number) {
                        self.runtimeErr("Nelze inkrementovat nečíselné hodnoty", .{}, &.{});
                        return ResultError.runtime;
                    }

                    self.push(Val{ .number = a.number + 1 });
                },
                .op_decrement => {
                    var a = self.pop();

                    if (a != .number) {
                        self.runtimeErr("Nelze dekrementovat nečíselné hodnoty", .{}, &.{});
                        return ResultError.runtime;
                    }

                    self.push(Val{ .number = a.number - 1 });
                },

                .op_greater => self.binary(.greater),
                .op_less => self.binary(.less),
                .op_equal => {
                    var a = self.pop();
                    var b = self.pop();

                    self.push(Val{ .boolean = Val.isEqual(a, b) });
                },

                .op_not => self.push(Val{ .boolean = isFalsey(self.pop()) }),
                .op_negate => {
                    if (self.peek(0) != .number) {
                        self.runtimeErr("Negace nelze provést na nečíselné hodnotě", .{}, &.{.{ .message = "Operace negace je platná pouze pro číselné hodnoty" }});
                        return ResultError.runtime;
                    }
                    const val = Val{ .number = -(self.pop().number) };
                    self.push(val);
                },

                .op_bit_and => self.binary(.bit_and),
                .op_bit_or => self.binary(.bit_or),
                .op_bit_xor => self.binary(.bit_xor),
                .op_shift_left => self.shift(.left),
                .op_shift_right => self.shift(.right),
                .op_bit_not => {
                    const val: i64 = @intFromFloat(self.pop().number);
                    const result: f64 = @floatFromInt(~val);
                    self.push(Val{ .number = result });
                },

                .op_print => self.pop().print(),
                .op_pop => _ = self.pop(),
                .op_popn => {
                    var n = self.readByte();
                    var i: usize = 0;

                    while (i < n) : (i += 1) {
                        _ = self.pop();
                    }
                },
                .op_get_glob => {
                    const name = self.readValue().obj.string();
                    if (!self.globals.contains(name.repre)) {
                        self.runtimeErr("Neexistující prvek '{s}'", .{name.repre}, &.{.{ .message = "Zkontrolujte zda jste správně specifikovali jméno prvku a zda je tento prvek k dispozici v akuálním kontextu" }});
                        return ResultError.runtime;
                    }
                    self.push(self.globals.get(name.repre).?.val);
                },
                .op_def_glob_var => {
                    const name = self.readValue().obj.string();
                    self.globals.put(name.repre, Global.initPrm(self.peek(0))) catch {
                        @panic("Nepodařilo se hodnotu alokovat");
                    };
                    _ = self.pop();
                },
                .op_set_glob => {
                    const name = self.readValue().obj.string();
                    if (!self.globals.contains(name.repre)) {
                        self.runtimeErr("Neexistující prvek '{s}'", .{name.repre}, &.{.{ .message = "Zkontrolujte zda jste správně specifikovali jméno prvku a zda je tento prvek k dispozici v akuálním kontextu" }});
                        return ResultError.runtime;
                    }

                    if (self.globals.get(name.repre).?.type == .konst) {
                        self.runtimeErr("Nelze změnit hodnotu konstanty '{s}'", .{name.repre}, &.{.{ .message = "Použijte 'prm' pro proměnnou." }});
                        return ResultError.runtime;
                    }

                    self.globals.put(name.repre, Global.initPrm(self.peek(0))) catch {
                        @panic("Nepodařilo se hodnotu alokovat");
                    };
                },

                .op_def_glob_const => {
                    const name = self.readValue().obj.string();
                    self.globals.put(name.repre, Global.initKonst(self.peek(0))) catch {
                        @panic("Nepodařilo se hodnotu alokovat");
                    };
                    _ = self.pop();
                },

                .op_get_loc => {
                    var slot = self.readByte();
                    self.push(self.stack[slot]);
                },

                .op_set_loc => {
                    var slot = self.readByte();
                    self.stack[slot] = self.peek(0);
                },

                .op_return => return,
            };
        }
    }

    /// Přidání hodnoty do stacku
    fn push(self: *Self, val: Val) void {
        defer self.stack_top += 1;
        self.stack[self.stack_top] = val;
    }

    /// Odstranění hodnoty ze stacku
    fn pop(self: *Self) Val {
        if (self.stack_top == 0) {
            self.runtimeErr("Nelze provést", .{}, &.{});
            std.process.exit(72);
        }
        self.stack_top -= 1;
        return self.stack[self.stack_top];
    }

    /// Dostat hodnotu ze stacku podle vzdálenosti od stack_top
    fn peek(self: *Self, distance: u16) Val {
        return self.stack[self.stack_top - 1 - distance];
    }

    /// Resetovat stack
    fn resetStack(self: *Self) void {
        self.stack_top = 0;
        self.ip = 0;
    }

    /// Pro získání jestli je hodnota nepravdivá
    fn isFalsey(val: Val) bool {
        return val == .nic or (val == .boolean and !val.boolean);
    }

    /// Spojení dvou stringů
    inline fn concatObj(self: *Self) void {
        const b = self.pop().obj;
        const a = self.pop().obj;
        defer {
            a.deinit(a, self);
            b.deinit(b, self);
        }

        const new = std.mem.concat(self.allocator, u8, &.{ a.string().repre, b.string().repre }) catch {
            @panic("Nedostatečné množství paměti");
        };

        const val = Val{ .obj = Object.String.take(self, new) };
        self.push(val);
    }

    /// Spojení hodnoty se stringem
    inline fn concatWithString(self: *Self) void {
        var b = self.pop();
        var a = self.pop();

        var new: []const u8 = undefined;
        var string: []const u8 = undefined;

        if (a == .obj and a.obj.type == .string) {
            string = b.stringVal(self.allocator) catch {
                @panic("Chyba při alokaci");
            };

            new = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ a.obj.string().repre, string }) catch {
                @panic("Chyba při alokaci");
            };

            a.obj.deinit(a.obj, self);
        } else if (b.obj.type == .string) {
            string = a.stringVal(self.allocator) catch {
                @panic("Chyba při alokaci");
            };

            new = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ string, b.obj.string().repre }) catch {
                @panic("Chyba při alokaci");
            };

            b.obj.deinit(b.obj, self);
        }

        if (a == .number or b == .number) {
            self.allocator.free(string);
        }

        self.push(Val{ .obj = Object.String.take(self, new) });
    }

    /// Spojení dvou hodnot
    inline fn add(self: *Self) ResultError!void {
        const second = self.peek(0);
        const first = self.peek(1);

        if (first == .number and second == .number) {
            const b = self.pop().number;
            const a = self.pop().number;

            self.push(Val{ .number = a + b });
        } else if (first == .obj and second == .obj) { // TODO
            self.concatObj();
        } else if (first == .obj or second == .obj) {
            self.concatWithString();
        } else {
            self.runtimeErr("Operace + není povolena pro tuto kombinaci hodnot", .{}, &.{.{ .message = "Operace + jde použít jen na číselné hodnoty, stringy a spojení hodnoty se stringem" }});
            return ResultError.runtime;
        }
    }

    /// "Binární" operace podle operátoru
    inline fn binary(self: *Self, operation: BinaryOp) ResultError!void {
        if (self.peek(0) != .number or self.peek(1) != .number) {
            self.runtimeErr("Nesprávný datový typ", .{}, &.{}); // Binární operace může být prováděna pouze na číselných hodnotách. Zkontrolujte, zda je váš datový typ kompatibilní s touto operací."
            return ResultError.runtime;
        }

        const b = self.pop().number;
        const a = self.pop().number;

        const result = switch (operation) {
            .sub => a - b,
            .mult => a * b,
            .div => a / b,

            .greater => a > b,
            .less => a < b,

            else => blk: {
                const a_bit: i64 = @intFromFloat(a);
                const b_bit: i64 = @intFromFloat(b);

                const op = switch (operation) {
                    .bit_and => a_bit & b_bit,
                    .bit_or => a_bit | b_bit,
                    .bit_xor => a_bit ^ b_bit,
                    else => unreachable,
                };

                const res: f64 = @floatFromInt(op);

                break :blk res;
            },
        };

        if (@TypeOf(result) == bool) {
            self.push(Val{ .boolean = result });
        } else {
            self.push(Val{ .number = result });
        }
    }

    /// Bit shift dvě čísla
    inline fn shift(self: *Self, operation: ShiftOp) ResultError!void {
        const b = self.pop();
        const a = self.pop();

        if (a != .number or b != .number) {
            self.runtimeErr("Binární posun lze provádět jen na číselných hodnotách", .{}, &.{});
            return ResultError.runtime;
        }

        if (b.number >= 64.0 or b.number < 0.0) {
            self.runtimeErr("Neplatné číslo '{d}' pro binární posun", .{b.number}, &.{.{ .message = "Číslo musí být kladné a menší jak 64" }});
            return ResultError.runtime;
        }

        const a_bit: i64 = @intFromFloat(a.number);
        const b_bit: u6 = @intFromFloat(b.number);

        const op = switch (operation) {
            .right => a_bit >> b_bit,
            .left => a_bit << b_bit,
        };

        const result: f64 = @floatFromInt(op);

        self.push(Val{ .number = result });
    }

    /// Dostat op_code dle IP
    inline fn readByte(self: *Self) u8 {
        const byte = self.block.code.items[self.ip];
        self.ip += 1;
        return byte;
    }

    /// Dostat hodnotu dle IP
    inline fn readValue(self: *Self) Val {
        return self.block.values.items[self.readByte()];
    }

    /// Vypisování run-time errorů s trace stackem
    fn runtimeErr(self: *Self, comptime message: []const u8, args: anytype, notes: []const Reporter.Note) void {
        const loc = self.block.locations.items[self.ip - 1];

        const new = std.fmt.allocPrint(self.allocator, message, args) catch @panic("");
        self.reporter.reportRuntime(new, notes, loc);
    }
};
