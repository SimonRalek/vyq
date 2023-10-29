const std = @import("std");

const Val = @import("value.zig").Val;
const Token = @import("token.zig").Token;

const storeType = enum { prm, konst };

/// Ukládání hodnot, aby se dalo poznat jestli je to konstanta nebo proměnná
pub const Global = struct {
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
};

pub const Local = struct {
    name: Token,
    depth: u32,
    is_const: bool,

    pub fn init(name: Token, depth: u32, is_const: bool) Local {
        return Local{ .name = name, .depth = depth, .is_const = is_const };
    }

    pub fn initPrm(name: Token, depth: u32) Local {
        return init(name, depth, false);
    }

    pub fn initKonst(name: Token, depth: u32) Local {
        return init(name, depth, true);
    }
};
