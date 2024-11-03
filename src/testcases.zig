const std = @import("std");
const TM = @import("TM.zig");

const TestCase = struct { machine: TM, expected_out: []const u1 };

const test_cases = [_]TestCase{
    // Trivial Turing Machine that immediately halts
    .{ .machine = .empty, .expected_out = &.{0} },
    // Simple Turing Machine that writes two 1s to the tape before
    // returning to the start and halting
    .{
        .machine = .{
            .states = &.{ .{
                .read_zero = .{ .move = .left, .write = 1, .next = @enumFromInt(1) },
                .read_one = .{ .move = .left, .write = 1, .next = .halt },
            }, .{
                .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(0) },
                .read_one = .{ .move = .right, .write = 1, .next = @enumFromInt(0) },
            } },
            .state = @enumFromInt(0),
            .tape = .empty,
        },
        .expected_out = &.{ 1, 1 },
    },
    .{ .machine = .bb1, .expected_out = &.{1} },
    .{ .machine = .bb2, .expected_out = &.{ 1, 1, 1, 1 } },
    .{ .machine = .bb3, .expected_out = &.{ 1, 1, 1, 1, 1, 1 } },
    .{ .machine = .bb4, .expected_out = &.{ 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
};

pub fn test_tm(T: type, ally: std.mem.Allocator) !void {
    var tests = test_cases;
    for (&tests) |*case| {
        var machine = T.from(case.machine);
        const e_out = case.expected_out;
        defer machine.deinit(ally);

        try machine.eval(ally);
        const out = try machine.to_array(ally);
        defer ally.free(out);

        try std.testing.expectEqualSlices(u1, e_out, out);
    }
}
