const std = @import("std");

pub const State = struct {
    pub const PartialState = struct {
        write: u1,
        move: enum(u1) { left, right },
        next: enum(usize) { halt = std.math.maxInt(usize), _ },
    };

    read_zero: PartialState,
    read_one: PartialState,
};

states: []State,
inital_state: usize,

pub const empty: @This() = .{ .states = &.{}, .inital_state = 0 };
