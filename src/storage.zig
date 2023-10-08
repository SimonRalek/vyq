const std = @import("std");

const Val = @import("value.zig").Val;

const storeType = enum { prm, konst };

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
