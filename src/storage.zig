const std = @import("std");

const Val = @import("value.zig").Val;

/// Ukládání hodnot, aby se dalo poznat jestli je to konstanta nebo proměnná
pub const Global = struct {
    const Self = @This();

    is_const: bool,
    val: Val,

    pub fn init(is_const: bool, val: Val) Self {
        return Self{ .is_const = is_const, .val = val };
    }

    pub fn initPrm(val: Val) Self {
        return Self{ .is_const = false, .val = val };
    }

    pub fn initKonst(val: Val) Self {
        return Self{ .is_const = true, .val = val };
    }
};

pub const Local = struct {
    name: []const u8,
    depth: i32,
    is_const: bool,

    pub fn init(name: []const u8, depth: i32, is_const: bool) Local {
        return Local{ .name = name, .depth = depth, .is_const = is_const };
    }

    pub fn initPrm(name: []const u8, depth: i32) Local {
        return init(name, depth, false);
    }

    pub fn initKonst(name: []const u8, depth: i32) Local {
        return init(name, depth, true);
    }
};
