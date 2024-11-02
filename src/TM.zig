const std = @import("std");

pub const State = struct {
    pub const Index = enum(usize) { halt = std.math.maxInt(usize), _ };
    pub const PartialState = struct {
        move: enum(i2) { left = -1, right = 1 },
        write: u1,
        next: Index,

        const halt: PartialState = .{ .move = .left, .write = 0, .next = .halt };
    };

    read_zero: PartialState,
    read_one: PartialState,

    const halt: State = .{ .read_zero = .halt, .read_one = .halt };
};

const Tape = struct {
    index: isize,
    left_tape: std.ArrayListUnmanaged(u1),
    right_tape: std.ArrayListUnmanaged(u1),

    pub const empty: Tape = .{
        .index = 0,
        .left_tape = .empty,
        .right_tape = .empty,
    };

    fn deinit(self: *@This(), ally: std.mem.Allocator) void {
        self.left_tape.deinit(ally);
        self.right_tape.deinit(ally);
    }

    fn to_array(self: *const Tape, ally: std.mem.Allocator) ![]const u1 {
        var list = try ally.alloc(u1, self.left_tape.items.len + self.right_tape.items.len);
        @memcpy(list[0..self.left_tape.items.len], self.left_tape.items);
        std.mem.reverse(u1, list[0..self.left_tape.items.len]);
        @memcpy(list[self.left_tape.items.len..], self.right_tape.items);
        return list;
    }

    fn get_tape_and_offset(self: *Tape) struct { *std.ArrayListUnmanaged(u1), usize } {
        return if (self.index < 0) .{
            &self.left_tape,
            @intCast(-self.index - 1),
        } else .{
            &self.right_tape,
            @intCast(self.index),
        };
    }

    fn write(self: *Tape, ally: std.mem.Allocator, bit: u1) !void {
        const tape_array, const tape_offset = self.get_tape_and_offset();
        if (tape_offset < tape_array.items.len) {
            tape_array.items[tape_offset] = bit;
        } else {
            try tape_array.append(ally, bit);
        }
    }

    fn read(self: *Tape) u1 {
        const tape_array, const tape_offset = self.get_tape_and_offset();
        return if (tape_offset < tape_array.items.len) tape_array.items[tape_offset] else 0;
    }
};

states: []const State,
state: State.Index,
tape: Tape,

pub fn deinit(self: *@This(), ally: std.mem.Allocator) void {
    self.tape.deinit(ally);
}

pub fn get_state(self: *@This()) State {
    return self.states[@intFromEnum(self.state)];
}

pub fn eval(self: *@This(), ally: std.mem.Allocator) !void {
    while (self.state != .halt) {
        const pstate = switch (self.tape.read()) {
            0 => self.get_state().read_zero,
            1 => self.get_state().read_one,
        };
        try self.tape.write(ally, pstate.write);
        self.state = pstate.next;
    }
}

pub const empty: @This() = .{
    .states = &.{.halt},
    .state = @enumFromInt(0),
    .tape = .empty,
};

test "trivial TM exec" {
    const ally = std.testing.allocator;
    var triv: @This() = .empty;
    defer triv.deinit(ally);

    try triv.eval(ally);
    const out = try triv.tape.to_array(ally);
    defer ally.free(out);

    try std.testing.expectEqualSlices(u1, &.{0}, out);
}
