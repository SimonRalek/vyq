const std = @import("std");
const File = std.fs.File;

pub const History = struct {
    const Self = @This();

    file: File = undefined,

    pub fn init() Self {

        // const history_path = std.fs.op
        //
        // return .{
        //     .file = std.
        // };
        return .{};
    }
};
