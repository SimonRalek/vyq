const std = @import("std");
const shared = @import("../shared.zig");
const time = std.time;

const Allocator = std.mem.Allocator;
const Instant = time.Instant;

const timerMap = std.StringHashMap(Timer);

/// Util pro měření délky programu
pub const BenchMark = struct {
    const Self = @This();

    timers: timerMap,
    allocator: Allocator,

    /// Inicializace BenchMarku
    pub fn init(allocator: Allocator) Self {
        return .{ .timers = timerMap.init(allocator), .allocator = allocator };
    }

    /// Free listu s timery
    pub fn deinit(self: *Self) void {
        self.timers.deinit();
    }

    /// Nový timer
    pub fn createMark(self: *Self, name: []const u8) !*Timer {
        var gop = try self.timers.getOrPut(name);
        if (!gop.found_existing) gop.value_ptr.* = try Timer.start();
        return gop.value_ptr;
    }

    /// Výpis timerů s jejich trváním
    pub fn printTimers(self: *Self) !void { // TODO
        if (self.timers.count() == 0) {
            return;
        }

        var it = self.timers.iterator();
        while (it.next()) |entry| {
            try shared.stdout.print("\n ---- NAME ----- ELAPSED (ms) ------- START ------- END ------ \n", .{});
            try entry.value_ptr.*.print(entry.key_ptr.*);
        }
    }
};

pub const Timer = struct {
    const Self = @This();

    started: Instant,
    ended: Instant = undefined,

    pub fn start() !Self {
        return .{ .started = Instant.now() catch |err| return err };
    }

    pub fn end(self: *Self) void {
        self.ended = Instant.now() catch return;
    }

    pub fn reset(self: *Self) void {
        self.started = Instant.now() catch return;
        self.ended = undefined;
    }

    pub fn lap(self: *Self) i64 {
        defer self.reset();
        return self.started;
    }

    pub fn duration(self: *const Self) u64 {
        return self.ended.since(self.started);
    }

    pub fn print(self: *Timer, name: []const u8) !void {
        try shared.stdout.print("  {s:0>10}|", .{name});
        try shared.stdout.print("  {}|", .{self.duration()});
        try shared.stdout.print("   {}  |", .{self.started});
        try shared.stdout.print("  {}  \n", .{self.ended});
    }
};
