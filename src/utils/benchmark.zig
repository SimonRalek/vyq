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
    pub fn createMark(self: *Self, name: []const u8) *Timer {
        const gop = self.timers.getOrPut(name) catch @panic("Nepodařilo se alokovat");
        if (!gop.found_existing) gop.value_ptr.* = Timer.start();
        return gop.value_ptr;
    }

    /// Výpis timerů s jejich trváním
    pub fn printTimers(self: *Self) !void {
        if (self.timers.count() == 0) {
            return;
        }

        var it = self.timers.iterator();
        while (it.next()) |entry| {
            try shared.stdout.print("\n--- JMÉNO ----- ČAS ----\n", .{});
            try entry.value_ptr.*.print(entry.key_ptr.*);
        }
    }
};

pub const Timer = struct {
    const Self = @This();

    started: Instant,
    ended: Instant = undefined,

    /// Odstartovat časovač
    pub fn start() Self {
        return .{ .started = Instant.now() catch @panic("Nepodporovaná funkce") };
    }

    /// Ukončit časovač
    pub fn end(self: *Self) void {
        self.ended = Instant.now() catch return;
    }

    /// Restartovat
    pub fn reset(self: *Self) void {
        self.started = Instant.now() catch return;
        self.ended = undefined;
    }

    /// Vrátit startovací hodnotu a restartovat
    pub fn lap(self: *Self) i64 {
        defer self.reset();
        return self.started;
    }

    /// Doba trvání
    pub fn duration(self: *const Self) u64 {
        return self.ended.since(self.started);
    }

    /// Výpis jména a délky
    pub fn print(self: *Timer, name: []const u8) !void {
        try shared.stdout.print("{s:^11}|", .{name});
        try shared.stdout.print("{:^14}\n", .{self.duration()});
    }
};
