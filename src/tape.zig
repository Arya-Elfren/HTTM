const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const testing = std.testing;

const Direction = enum(i2) { left = -1, right = 1 };

pub fn Tape(comptime Child: type, comptime chunk_size: usize) type {
    return struct {
        const Self = @This();
        const Chunk = [chunk_size]Child;
        const List = std.DoublyLinkedList(Chunk);
        const Node = List.Node;
        const IndexInt = std.math.IntFittingRange(0, chunk_size - 1);
        const Index = enum(IndexInt) {
            _,
            
            const first: Index = @enumFromInt(0);
            const last: Index = @enumFromInt(std.math.maxInt(IndexInt));
            
            pub fn incr(idx: *Index) void {
                assert(idx.* != Index.last);
                idx.* = @enumFromInt(@intFromEnum(idx.*) + 1);
            }
            
            pub fn decr(idx: *Index) void {
                assert(idx.* != Index.first);
                idx.* = @enumFromInt(@intFromEnum(idx.*) - 1);
            }
            
            pub fn move(idx: *Index, direction: Direction) void {
                assert(idx.* != Index.first);
                assert(idx.* != Index.last);
                idx.* = @enumFromInt(@intFromEnum(idx.*) + @intFromEnum(direction));
            }
        };
        
        list: List,
        current: *Node,
        index: Index,
        
        fn createNode(ally: mem.Allocator) !*Node {
            const node = try ally.create(Node);
            @memset(node.data[0..], 0);
            return node;
        }
        
        pub fn init(ally: mem.Allocator) !Self {
            const node = try createNode(ally);
            var list: List = .{};
            list.append(node);
            return .{
                .list = list,
                .current = node,
                .index = @enumFromInt(@as(u2, @intFromEnum(Index.last)) / 2),
            };
        }
        
        pub fn deinit(tape: *Self, ally: mem.Allocator) void {
            while (tape.list.pop()) |node| ally.destroy(node);
        }
        
        fn appendAndMove(tape: *Self, ally: mem.Allocator) !void {
            const node = try createNode(ally);
            tape.list.append(node);
            tape.current = node;
            tape.index = .first;
        }

        fn prependAndMove(tape: *Self, ally: mem.Allocator) !void {
            const node = try createNode(ally);
            tape.list.prepend(node);
            tape.current = node;
            tape.index = .last;
        }
        
        pub fn step(tape: *Self, ally: mem.Allocator, write: Child, move: Direction) !void {
            switch (move) {
                .left => switch (tape.index) {
                    Index.first => {
                        tape.current.data[@intFromEnum(Index.first)] = write;
                        if (tape.current.prev) |n| {
                            tape.current = n;
                            tape.index = .last;
                        } else {
                            try tape.prependAndMove(ally);
                        }
                    },
                    else => |idx| {
                        tape.current.data[@intFromEnum(idx)] = write;
                        tape.index.decr();
                    },
                },
                .right => switch (tape.index) {
                    Index.last => {
                        tape.current.data[@intFromEnum(Index.last)] = write;
                        if (tape.current.next) |n| {
                            tape.current = n;
                            tape.index = .first;
                        } else {
                            try tape.appendAndMove(ally);
                        }
                    },
                    else => |idx| {
                        tape.current.data[@intFromEnum(idx)] = write;
                        tape.index.incr();
                    },
                },
            }
        }
        
        pub fn read(tape: *const Self) Child {
            return tape.current.data[@intFromEnum(tape.index)];
        }
    };
}

test Tape {
    const ally = testing.allocator;
    inline for ([_]type{ Tape(u1, 2), Tape(u1, 1), Tape(u8, 1) }) |T| {
        var tape: T = try .init(ally);
        defer tape.deinit(ally);

        try testing.expect(tape.read() == 0);
        try tape.step(ally, 1, .left);
        try testing.expect(tape.read() == 0);
        try tape.step(ally, 1, .left);
        try testing.expect(tape.read() == 0);
        try tape.step(ally, 1, .right);
        try testing.expect(tape.read() == 1);
    }
}

