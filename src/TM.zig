const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const TM = @This();
const alphabet = blk: {
    var tmp: [26]u8 = undefined;
    for ('A'..'Z' + 1, 0..) |char, i| tmp[i] = char;
    break :blk tmp;
};

pub const Direction = enum(i2) {
    left = -1,
    right = 1,
    pub fn label(self: Direction) u8 {
        return switch (self) {
            .left => 'L',
            .right => 'R',
        };
    }
};

pub const State = struct {
    pub const Index = enum(usize) {
        halt = std.math.maxInt(usize),
        _,
        pub fn to_int(self: Index) usize {
            return @intFromEnum(self);
        }
        pub fn label(self: Index) u8 {
            return if (self.to_int() < 26) alphabet[self.to_int()] else 'H';
        }
        pub fn from(idx: TM.State.Index) Index {
            return @enumFromInt(@intFromEnum(idx));
        }
    };
    pub const PartialState = struct {
        move: Direction,
        write: u1,
        next: Index,

        const halt: PartialState = .{ .move = .left, .write = 0, .next = .halt };
    };

    read_zero: PartialState,
    read_one: PartialState,

    pub const halt: State = .{ .read_zero = .halt, .read_one = .halt };
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

    fn deinit(self: *Tape, ally: std.mem.Allocator) void {
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
            @intCast(@abs(self.index + 1)),
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
            assert(tape_offset == tape_array.items.len);
            try tape_array.append(ally, bit);
        }
    }

    fn read(self: *Tape) u1 {
        const tape_array, const tape_offset = self.get_tape_and_offset();
        return if (tape_offset < tape_array.items.len) tape_array.items[tape_offset] else 0;
    }
};

pub const DiskWriter = struct {
    writer: std.fs.File.Writer,

    pub fn write_log(
        self: DiskWriter,
        current_state: State.Index,
        next_state: State.Index,
        bit: u1,
        direction: Direction,
    ) !void {
        try self.writer.print(
            "{c} -> {c}, {} ({c})\n",
            .{
                current_state.label(),
                next_state.label(),
                bit,
                direction.label(),
            },
        );
    }
};

const DiskWritingTM = struct {
    pub fn from(machine: TM) TM {
        return machine.with_writer(std.fs.cwd().createFile(
            "execution-trace",
            .{},
        ) catch unreachable);
    }
};

states: []const State,
state: State.Index = @enumFromInt(0),
tape: Tape = .empty,
step: usize = 0,
step_cap: usize = std.math.maxInt(u26),
disk_writer: ?DiskWriter = null,

pub fn from(self: TM) TM {
    return self;
}

pub fn deinit(self: *TM, ally: std.mem.Allocator) void {
    self.tape.deinit(ally);
}

pub fn get_state(self: *TM) State {
    return self.states[@intFromEnum(self.state)];
}

pub fn to_array(self: *TM, ally: Allocator) ![]const u1 {
    return try self.tape.to_array(ally);
}

pub fn with_writer(self: TM, file: std.fs.File) TM {
    return .{
        .states = self.states,
        .state = self.state,
        .tape = self.tape,
        .step = self.step,
        .step_cap = self.step_cap,
        .disk_writer = .{ .writer = file.writer() },
    };
}

pub fn eval(self: *TM, ally: std.mem.Allocator) !void {
    try self.tape.write(ally, 0);
    while (self.state != .halt and self.step < self.step_cap) : (self.step += 1) {
        const pstate = switch (self.tape.read()) {
            0 => self.get_state().read_zero,
            1 => self.get_state().read_one,
        };
        try self.tape.write(ally, pstate.write);
        if (self.disk_writer) |disk_writer| {
            try disk_writer.write_log(
                self.state,
                pstate.next,
                pstate.write,
                pstate.move,
            );
        } else {}
        self.tape.index += @intFromEnum(pstate.move);
        self.state = pstate.next;
    }
}

test "TM1" {
    const ally = std.testing.allocator;
    try @import("testcases.zig").test_tm(TM, ally);
    try @import("testcases.zig").test_tm(TM.DiskWritingTM, ally);
}

pub const empty: TM = .{ .states = &.{.halt} };

pub const bb1: TM = .{
    .states = &.{.{
        .read_zero = .{ .move = .right, .write = 1, .next = .halt },
        .read_one = .{ .move = .left, .write = 0, .next = @enumFromInt(0) },
    }},
};

/// Two-state busy-beaver champion
pub const bb2: TM = .{
    .states = &.{ .{
        .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(1) },
        .read_one = .{ .move = .left, .write = 1, .next = @enumFromInt(1) },
    }, .{
        .read_zero = .{ .move = .left, .write = 1, .next = @enumFromInt(0) },
        .read_one = .{ .move = .right, .write = 1, .next = .halt },
    } },
};

/// Three-state busy beaver champion
pub const bb3: TM = .{
    .states = &.{
        .{
            .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(1) },
            .read_one = .{ .move = .right, .write = 1, .next = .halt },
        },
        .{
            .read_zero = .{ .move = .right, .write = 0, .next = @enumFromInt(2) },
            .read_one = .{ .move = .right, .write = 1, .next = @enumFromInt(1) },
        },
        .{
            .read_zero = .{ .move = .left, .write = 1, .next = @enumFromInt(2) },
            .read_one = .{ .move = .left, .write = 1, .next = @enumFromInt(0) },
        },
    },
};

pub const bb4: TM = .{
    .states = &.{ .{
        .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(1) },
        .read_one = .{ .move = .left, .write = 1, .next = @enumFromInt(1) },
    }, .{
        .read_zero = .{ .move = .left, .write = 1, .next = @enumFromInt(0) },
        .read_one = .{ .move = .left, .write = 0, .next = @enumFromInt(2) },
    }, .{
        .read_zero = .{ .move = .right, .write = 1, .next = .halt },
        .read_one = .{ .move = .left, .write = 1, .next = @enumFromInt(3) },
    }, .{
        .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(3) },
        .read_one = .{ .move = .right, .write = 0, .next = @enumFromInt(0) },
    } },
};

pub const bb5: TM = .{
    .states = &.{
        .{
            .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(1) },
            .read_one = .{ .move = .left, .write = 1, .next = @enumFromInt(2) },
        },
        .{
            .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(2) },
            .read_one = .{ .move = .right, .write = 1, .next = @enumFromInt(1) },
        },
        .{
            .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(3) },
            .read_one = .{ .move = .left, .write = 0, .next = @enumFromInt(4) },
        },
        .{
            .read_zero = .{ .move = .left, .write = 1, .next = @enumFromInt(0) },
            .read_one = .{ .move = .left, .write = 1, .next = @enumFromInt(3) },
        },
        .{
            .read_zero = .{ .move = .right, .write = 1, .next = .halt },
            .read_one = .{ .move = .left, .write = 0, .next = @enumFromInt(0) },
        },
    },
};

pub const bb6: TM = .{
    .states = &.{
        .{
            .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(1) },
            .read_one = .{ .move = .left, .write = 0, .next = @enumFromInt(3) },
        },
        .{
            .read_zero = .{ .move = .right, .write = 1, .next = @enumFromInt(2) },
            .read_one = .{ .move = .right, .write = 0, .next = @enumFromInt(5) },
        },
        .{
            .read_zero = .{ .move = .left, .write = 1, .next = @enumFromInt(2) },
            .read_one = .{ .move = .left, .write = 1, .next = @enumFromInt(0) },
        },
        .{
            .read_zero = .{ .move = .left, .write = 0, .next = @enumFromInt(4) },
            .read_one = .{ .move = .right, .write = 1, .next = .halt },
        },
        .{
            .read_zero = .{ .move = .left, .write = 1, .next = @enumFromInt(5) },
            .read_one = .{ .move = .right, .write = 0, .next = @enumFromInt(1) },
        },
        .{
            .read_zero = .{ .move = .right, .write = 0, .next = @enumFromInt(2) },
            .read_one = .{ .move = .right, .write = 0, .next = @enumFromInt(4) },
        },
    },
};
