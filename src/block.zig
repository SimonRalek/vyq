const std = @import("std");

const Val = @import("value.zig").Val;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const Location = @import("scanner.zig").Location;

const charList = ArrayListUnmanaged(u8);
const valList = ArrayListUnmanaged(Val);
const locList = ArrayListUnmanaged(Location);

pub const Block = struct {
    const Self = @This();

    // op code na bytecode
    pub const OpCode = enum(u8) {
        op_value,
        op_ano,
        op_ne,
        op_nic,
        op_not,
        op_negate,
        op_equal,
        op_greater,
        op_less,
        op_shift_left,
        op_shift_right,
        op_bit_and,
        op_bit_or,
        op_bit_xor,
        op_bit_not,
        op_add,
        op_sub,
        op_mult,
        op_div,
        op_mod,
        op_return,
        op_print,
        op_println,
        op_def_glob,
        op_get_glob,
        op_set_glob,
        op_get_loc,
        op_set_loc,
        op_pop,
        op_popn,
        op_jmp,
        op_jmp_on_true,
        op_jmp_on_false,
        op_loop,
        op_case,
        op_call,
        op_closure,
        op_set_elv,
        op_get_elv,
        op_close_elv,
        op_build_list,
        op_index_subr,
        op_store_subr,
    };

    allocator: Allocator,
    code: charList,
    locations: locList,
    values: valList,

    /// Inicializace bloku
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .code = charList{},
            .locations = locList{},
            .values = valList{},
        };
    }

    /// Free blok
    pub fn deinit(self: *Self) void {
        self.code.deinit(self.allocator);
        self.locations.deinit(self.allocator);
        self.values.deinit(self.allocator);
    }

    /// Zapsat instrukci
    pub fn writeOp(self: *Self, op_code: OpCode, loc: Location) void {
        self.writeOpByte(@intFromEnum(op_code), loc);
    }

    /// Zapsat instrukce
    pub fn writeOpByte(self: *Block, byte: u8, loc: Location) void {
        self.code.append(self.allocator, byte) catch @panic("Alokace selhala");
        self.locations.append(self.allocator, loc) catch @panic("Alokace selhala");
    }

    /// Přidat hodnotu do bloku
    pub fn addVal(self: *Self, value: Val) u9 {
        const idx: u9 = @intCast(self.values.items.len);
        self.values.append(self.allocator, value) catch @panic("Alokace selhala");
        return idx;
    }
};
