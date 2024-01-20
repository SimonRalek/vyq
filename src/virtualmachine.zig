const std = @import("std");
const shared = @import("shared.zig");

const Allocator = std.mem.Allocator;

const _val = @import("value.zig");
const Val = _val.Val;
const Block = @import("block.zig").Block;
const ResultError = shared.ResultError;
const IndexError = shared.IndexError;
const Emitter = @import("emitter.zig").Emitter;
const _storage = @import("storage.zig");
const Global = _storage.Global;
const Object = _val.Object;
const Function = Object.Function;
const Closure = Object.Closure;
const Native = Object.Native;
const Reporter = @import("reporter.zig");
const unicode = @import("utils/unicode.zig");
const natives = @import("natives.zig");

const BinaryOp = enum {
    sub,
    mult,
    div,
    greater,
    less,
    bit_and,
    bit_or,
    bit_xor,
};
const ShiftOp = enum { left, right };

const CallFrame = struct {
    closure: *Closure,
    start: usize,
    ip: usize,
};

pub const VirtualMachine = struct {
    const Self = @This();

    frames: [64]CallFrame = undefined,
    frame_count: u8 = 0,

    allocator: Allocator,
    stack: [256]Val,
    stack_count: u9 = 0,
    globals: std.StringHashMap(Global),

    strings: std.StringHashMap(*Object.String),
    objects: ?*Object = null,
    openELV: ?*Object.ELV = null,

    reporter: *Reporter,

    /// Inicializace virtuální mašiny
    pub fn init(allocator: Allocator, reporter: *Reporter) Self {
        var vm: Self = .{
            .allocator = allocator,
            .globals = std.StringHashMap(Global).init(allocator),
            .strings = std.StringHashMap(*Object.String).init(allocator),
            .stack = undefined,
            .objects = null,
            .reporter = reporter,
        };

        vm.defineNative("delka", natives.str_lenNative);
        vm.defineNative("nactiVstup", natives.inputNative);
        vm.defineNative("ziskejTyp", natives.getTypeNative);
        vm.defineNative("nahoda", natives.randNative);
        vm.defineNative("mocnina", natives.sqrtNative);
        vm.defineNative("odmocnit", natives.rootNative);
        vm.defineNative("jeCislo", natives.isDigitNative);
        vm.defineNative("jeRetezec", natives.isStringNative);
        vm.defineNative("casovaZnacka", natives.getTimeStampNative);

        return vm;
    }

    /// "Free"nout objekty a listy
    pub fn deinit(self: *Self) void {
        self.deinitObjs();
        self.globals.deinit();
        self.strings.deinit();
        self.stack_count = 0;
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

        var emitter = Emitter.init(self, .script, null);
        defer emitter.deinit();
        const func = emitter.compile(source) catch return ResultError.compile;
        self.push(func.obj.val());
        const closure = Closure.init(self, func);
        _ = self.pop();
        self.push(closure.obj.val());
        _ = self.call(closure, 0);

        return self.run();
    }

    /// Běh programu
    fn run(self: *Self) ResultError!void {
        while (true) {
            var frame = self.currentFrame();
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
                        self.runtimeErr(
                            "Nelze inkrementovat nečíselné hodnoty",
                            .{},
                            &.{},
                        );
                        return ResultError.runtime;
                    }

                    self.push(Val{ .number = a.number + 1 });
                },
                .op_decrement => {
                    var a = self.pop();

                    if (a != .number) {
                        self.runtimeErr(
                            "Nelze dekrementovat nečíselné hodnoty",
                            .{},
                            &.{},
                        );
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
                        self.runtimeErr(
                            "Negace nelze provést na nečíselné hodnotě",
                            .{},
                            &.{
                                .{ .message = "Operace negace je platná pouze pro číselné hodnoty" },
                            },
                        );
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

                .op_print => self.pop().print(self.allocator),
                .op_println => {
                    self.pop().print(self.allocator);
                    shared.stdout.print(
                        "\n",
                        .{},
                    ) catch @panic("Nepodařilo se vypsat hodnotu");
                },
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
                        self.runtimeErr(
                            "Neexistující prvek '{s}'",
                            .{name.repre},
                            &.{
                                .{ .message = "Zkontrolujte zda jste správně specifikovali jméno prvku a zda je tento prvek k dispozici v aktuálním kontextu" },
                            },
                        );
                        return ResultError.runtime;
                    }
                    self.push(self.globals.get(name.repre).?.val);
                },
                .op_def_glob_var => {
                    const name = self.readValue().obj.string();
                    self.globals.put(
                        name.repre,
                        Global.initPrm(self.peek(0)),
                    ) catch {
                        @panic("Nepodařilo se hodnotu alokovat");
                    };
                    _ = self.pop();
                },
                .op_set_glob => {
                    const name = self.readValue().obj.string();
                    if (!self.globals.contains(name.repre)) {
                        self.runtimeErr(
                            "Neexistující prvek '{s}'",
                            .{name.repre},
                            &.{
                                .{ .message = "Zkontrolujte zda jste správně specifikovali jméno prvku a zda je tento prvek k dispozici v akuálním kontextu" },
                            },
                        );
                        return ResultError.runtime;
                    }

                    if (self.globals.get(name.repre).?.is_const) {
                        self.runtimeErr(
                            "Nelze změnit hodnotu konstanty '{s}'",
                            .{name.repre},
                            &.{.{ .message = "Použijte 'prm' pro proměnnou." }},
                        );
                        return ResultError.runtime;
                    }

                    self.globals.put(
                        name.repre,
                        Global.initPrm(self.peek(0)),
                    ) catch {
                        @panic("Nepodařilo se hodnotu alokovat");
                    };
                },

                .op_def_glob_const => {
                    const name = self.readValue().obj.string();
                    self.globals.put(
                        name.repre,
                        Global.initKonst(self.peek(0)),
                    ) catch {
                        @panic("Nepodařilo se hodnotu alokovat");
                    };
                    _ = self.pop();
                },

                .op_get_loc => {
                    var slot = self.readByte();
                    self.push(self.stack[frame.start + slot - 1]);
                },

                .op_set_loc => {
                    var slot = self.readByte();
                    self.stack[frame.start + slot - 1] = self.peek(0);
                },

                .op_jmp => {
                    const idx = self.read16Bit();
                    frame.ip += idx;
                },
                .op_jmp_on_true => {
                    const idx = self.read16Bit();
                    if (!isFalsey(self.peek(0))) {
                        frame.ip += idx;
                    }
                },
                .op_jmp_on_false => {
                    const idx = self.read16Bit();
                    frame.ip += falsey(self.peek(0)) * idx;
                },
                .op_loop => {
                    const idx = self.read16Bit();
                    frame.ip -= idx;
                },
                .op_case => {
                    self.push(self.peek(0));
                },

                .op_call => {
                    const count = self.readByte();
                    if (!self.callValue(self.peek(count), count)) {
                        return ResultError.runtime;
                    }
                },
                .op_closure => {
                    const func = self.readValue().obj.function();
                    const closure = Object.Closure.init(self, func);

                    for (0..closure.elv_count) |i| {
                        const is_local = self.readByte() != 0;
                        const idx = self.readByte();

                        closure.elvs[i] = if (is_local) self.captureELV(&self.stack[frame.start + idx - 1]) else frame.closure.elvs[idx];
                    }

                    self.push(closure.obj.val());
                },

                .op_get_elv => {
                    const slot = self.readByte();
                    self.push(self.currentFrame().closure.elvs[slot].?.location.*);
                },
                .op_set_elv => {
                    const slot = self.readByte();
                    frame.closure.elvs[slot].?.location.* = self.peek(0);
                },
                .op_close_elv => {
                    self.closeELV(&self.stack[self.stack_count - 2]);
                    _ = self.pop();
                },

                .op_build_list => {
                    const list = Object.List.init(self);
                    var item_count = self.readByte();

                    self.push(list.obj.val());
                    for (0..item_count) |i| {
                        list.append(self.peek(@intCast(item_count - i)));
                    }
                    _ = self.pop();

                    while (item_count > 0) : (item_count -= 1) {
                        _ = self.pop();
                    }

                    self.push(list.obj.val());
                },
                .op_index_subr => {
                    const idx = self.pop();
                    const val = self.pop();

                    try self.indexValidate(val, idx);

                    if (val.obj.type == .list) {
                        self.push(val.obj.list().getItem(idx.number));
                    } else {
                        const index: usize = @intFromFloat(idx.number);
                        self.push(Val{ .obj = Object.String.copy(self, val.obj.string().repre[index .. index + 1]) });
                    }
                },
                .op_store_subr => {
                    const item = self.pop();
                    const idx = self.pop();
                    const val = self.pop();

                    try self.indexValidate(val, idx);

                    if (val.obj.type == .list) {
                        val.obj.list().insert(idx.number, item);
                    } else {
                        const char = item.obj.string().repre;

                        if (char.len > 1) {
                            self.runtimeErr("Na místo písmena jde přiřadit jen písmeno", .{}, &.{});
                            return ResultError.runtime;
                        }

                        const index: usize = @intFromFloat(idx.number);
                        val.obj.string().repre[index] = char[0];
                    }
                    self.push(item);
                },

                .op_return => {
                    const result = self.pop();
                    self.closeELV(&self.stack[frame.start - 1]);
                    self.frame_count -= 1;

                    if (self.frame_count == 0) {
                        _ = self.pop();
                        return;
                    }

                    self.stack_count = @intCast(frame.start - 1);
                    self.push(result);
                    frame = &self.frames[self.frame_count - 1];
                },
            };
        }
    }

    inline fn currentFrame(self: *Self) *CallFrame {
        return &self.frames[self.frame_count - 1];
    }

    fn callValue(self: *Self, callee: Val, arg_count: u8) bool {
        if (callee == .obj) {
            switch (callee.obj.type) {
                .closure => {
                    return self.call(
                        callee.obj.closure(),
                        arg_count,
                    );
                },
                .native => {
                    const native = callee.obj.native();

                    const result = native.function(
                        self,
                        self.stack[self.stack_count - arg_count .. self.stack_count],
                    );

                    if (result != null)
                        self.stack_count -= arg_count + 1;

                    if (result) |val| {
                        self.push(val);
                        return true;
                    } else {
                        return false;
                    }
                },
                else => {},
            }
        }

        self.runtimeErr("Volat lze jen funkce", .{}, &.{});
        return false;
    }

    fn call(self: *Self, closure: *Closure, arg_count: u8) bool {
        if (arg_count != closure.function.arity) {
            self.runtimeErr(
                "Funkce '{s}' očekává počet argumentů {d}, dostala {d}",
                .{ closure.function.name.?, closure.function.arity, arg_count },
                &.{},
            );
            return false;
        }

        if (self.frame_count == 64) {
            self.runtimeErr("Stack overflow", .{}, &.{});
            return false;
        }

        var frame = &self.frames[self.frame_count];
        self.frame_count += 1;
        frame.closure = closure;
        frame.ip = 0;
        frame.start = self.stack_count - arg_count; // -1 ABY ZUSTALA HLAVNI FUNKCE NA STACKU
        return true;
    }

    fn defineNative(self: *Self, name: []const u8, function: Native.NativeFn) void {
        const str = Object.String.copy(self, name);
        self.push(str.val());
        const functionVal = (Object.Native.init(self, function)).obj.val();
        self.push(functionVal);
        self.globals.put(str.string().repre, Global{ .is_const = true, .val = functionVal }) catch @panic("");
        _ = self.pop();
        _ = self.pop();
    }

    fn captureELV(self: *Self, local: *Val) *Object.ELV {
        var prev: ?*Object.ELV = null;
        var elv = self.openELV;
        while (elv != null and @intFromPtr(elv.?.location) > @intFromPtr(local)) {
            prev = elv;
            elv = elv.?.next;
        }

        if (elv != null and elv.?.location == local) {
            return elv.?;
        }

        const created = Object.ELV.init(self, local);

        created.next = elv;

        if (prev) |new| {
            new.next = elv;
        } else {
            self.openELV = elv;
        }

        return created;
    }

    inline fn closeELV(self: *Self, last: *Val) void {
        while (self.openELV) |elv| {
            if (@intFromPtr(self.openELV.?.location) < @intFromPtr(last)) break;
            elv.closed = elv.location.*;
            elv.location = &elv.closed;
            self.openELV = elv.next;
        }
    }

    fn indexValidate(self: *Self, val: Val, idx: Val) ResultError!void {
        if (val != .obj or (val.obj.type != .string and val.obj.type != .list)) {
            self.runtimeErr("Pouze pole můžete indexovat", .{}, &.{});
            return ResultError.runtime;
        }

        if (idx != .number) {
            self.runtimeErr("Index může být pouze číslo", .{}, &.{});
            return ResultError.runtime;
        }

        if (val.obj.type == .list) {
            const list = val.obj.list();

            list.isValidIndex(idx.number) catch |err| {
                switch (err) {
                    IndexError.float_index => {
                        self.runtimeErr("Index musí být celé číslo", .{}, &.{});
                    },
                    IndexError.negative_index => {
                        self.runtimeErr("Index nemůže být záporné číslo", .{}, &.{});
                    },
                    IndexError.bigger_index => {
                        self.runtimeErr("Index je větší než délka pole", .{}, &.{});
                    },
                }

                return ResultError.runtime;
            };
        } else {
            const string = val.obj.string();

            string.isValidIndex(idx.number) catch |err| {
                switch (err) {
                    IndexError.float_index => {
                        self.runtimeErr("Index musí být celé číslo", .{}, &.{});
                    },
                    IndexError.negative_index => {
                        self.runtimeErr("Index nemůže být záporné číslo", .{}, &.{});
                    },
                    IndexError.bigger_index => {
                        self.runtimeErr("Index je větší než délka řetězce", .{}, &.{});
                    },
                }

                return ResultError.runtime;
            };
        }
    }

    /// Přidání hodnoty do stacku
    fn push(self: *Self, val: Val) void {
        self.stack[self.stack_count] = val;
        self.stack_count += 1;
    }

    /// Odstranění hodnoty ze stacku
    fn pop(self: *Self) Val {
        self.stack_count -= 1;
        return self.stack[self.stack_count];
    }

    /// Dostat hodnotu ze stacku podle vzdálenosti od stack_top
    fn peek(self: *Self, distance: u16) Val {
        return self.stack[self.stack_count - 1 - distance];
    }

    /// Resetovat stack
    fn resetStack(self: *Self) void {
        self.stack_count = 0;
        self.frame_count = 0;
    }

    /// Pro získání jestli je hodnota nepravdivá
    inline fn isFalsey(val: Val) bool {
        return falsey(val) == 1;
    }

    inline fn falsey(val: Val) u8 {
        return if (val == .nic or (val == .boolean and !val.boolean) or (val == .number and val.number == 0)) 1 else 0;
    }

    /// Spojení dvou stringů
    inline fn concatObj(self: *Self) void {
        const b = self.pop();
        const a = self.pop();

        const buff = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ a.obj.string().repre, b.obj.string().repre }) catch @panic("");

        const val = Val{ .obj = Object.String.take(self, buff) };
        self.push(val);
    }

    /// Spojení hodnoty se stringem
    inline fn concatWithString(self: *Self) void {
        var b = self.pop();
        var a = self.pop();

        var new: []u8 = undefined;
        var string: []const u8 = undefined;

        if (a == .obj and a.obj.type == .string) {
            string = b.stringVal(self.allocator) catch {
                @panic("Chyba při alokaci");
            };

            new = std.fmt.allocPrint(
                self.allocator,
                "{s}{s}",
                .{ a.obj.string().repre, string },
            ) catch {
                @panic("Chyba při alokaci");
            };
        } else if (b.obj.type == .string) {
            string = a.stringVal(self.allocator) catch {
                @panic("Chyba při alokaci");
            };

            new = std.fmt.allocPrint(
                self.allocator,
                "{s}{s}",
                .{ string, b.obj.string().repre },
            ) catch {
                @panic("Chyba při alokaci");
            };
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
            self.runtimeErr(
                "Operace + není povolena pro tuto kombinaci hodnot",
                .{},
                &.{
                    .{ .message = "Operace + jde použít jen na číselné hodnoty, stringy a spojení hodnoty se stringem" },
                },
            );
            return ResultError.runtime;
        }
    }

    /// "Binární" operace podle operátoru
    inline fn binary(self: *Self, operation: BinaryOp) ResultError!void {
        if (self.peek(0) != .number or self.peek(1) != .number) {
            self.runtimeErr(
                "Nesprávný datový typ",
                .{},
                &.{.{ .message = "Binární operace může být prováděna pouze na číselných hodnotách. Zkontrolujte, zda je váš datový typ kompatibilní s touto operací." }},
            );
            return ResultError.runtime;
        }

        const b = self.pop().number;
        const a = self.pop().number;

        const result = switch (operation) {
            .sub => a - b,
            .mult => a * b,
            .div => blk: {
                if (b == 0) {
                    self.runtimeErr("Nelze dělit nulou", .{}, &.{});
                    return ResultError.runtime;
                }
                break :blk a / b;
            },

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
            self.runtimeErr(
                "Binární posun lze provádět jen na číselných hodnotách",
                .{},
                &.{},
            );
            return ResultError.runtime;
        }

        if (b.number >= 64.0 or b.number < 0.0) {
            self.runtimeErr(
                "Neplatné číslo '{d}' pro binární posun",
                .{b.number},
                &.{.{ .message = "Číslo musí být kladné a menší jak 64" }},
            );
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
        const frame = self.currentFrame();
        const byte = frame.closure.function.block.code.items[frame.ip];
        frame.ip += 1;
        return byte;
    }

    /// Dostat hodnotu dle IP
    inline fn readValue(self: *Self) Val {
        const func = self.currentFrame().closure.function;
        return func.block.values.items[self.readByte()];
    }

    inline fn read16Bit(self: *Self) u16 {
        var frame = self.currentFrame();
        var items = frame.closure.function.block.code.items;
        frame.ip += 2;
        return (@as(u16, items[frame.ip - 2]) << 8 | items[frame.ip - 1]);
    }

    /// Vypisování run-time errorů s trace stackem
    pub fn runtimeErr(
        self: *Self,
        comptime message: []const u8,
        args: anytype,
        notes: []const Reporter.Note,
    ) void {
        const closure = self.currentFrame().closure;
        const loc = closure.function.block.locations.items[self.currentFrame().ip - 1];

        const new = std.fmt.allocPrint(self.allocator, message, args) catch @panic("Nepodařilo se alokovat");
        defer self.allocator.free(new);
        self.reporter.reportRuntime(new, notes, loc);

        var stdout = std.io.getStdOut();
        const config = std.io.tty.detectConfig(stdout);
        config.setColor(stdout, .dim) catch {};
        var i = self.frame_count;
        while (i > 0) : (i -= 1) {
            const branch = if (i == self.frame_count)
                "╰─┬─"
            else if (i != 1)
                "  ├─"
            else
                "  ╰─";

            const frame = self.frames[i - 1];
            const location = frame.closure.function.block.locations.items[frame.ip -| 1];
            const name = if (frame.closure.function.name) |name| name else "skript";

            shared.stdout.print("{s} {s}{s}: na řádce {}:{}\n", .{
                branch,
                name,
                if (std.mem.eql(u8, name, "skript")) "" else "()",
                location.line,
                location.start_column,
            }) catch @panic("");
        }
        config.setColor(stdout, .reset) catch {};

        self.resetStack();
    }
};
