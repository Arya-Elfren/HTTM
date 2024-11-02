const std = @import("std");

pub fn main() !void {}

test "init TM" {
    const TM = @import("TM.zig");
    const empty: TM = .empty;
    _ = empty;
}
