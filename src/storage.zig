const std = @import("std");

const Val = @import("value.zig").Val;
const Token = @import("token.zig").Token;

const storeType = enum { prm, konst };

/// Ukládání hodnot, aby se dalo poznat jestli je to konstanta nebo proměnná
pub const Storage = struct {
    const Self = @This();

    type: storeType,
    val: Val,

    pub fn init(store_type: storeType, val: Val) Self {
        return Self{ .type = store_type, .val = val };
    }

    pub fn initPrm(val: Val) Self {
        return Self{ .type = .prm, .val = val };
    }

    pub fn initKonst(val: Val) Self {
        return Self{ .type = .konst, .val = val };
    }

    pub fn getVal(self: *Self) Val {
        return self.val;
    }

    pub fn getType(self: *Self) storeType {
        return self.type;
    }
};

pub const Local = struct { name: Token, depth: u32 };
