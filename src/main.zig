const std = @import("std");
const mem = std.mem;
const TM = @import("TM.zig");

pub fn main() error{BadParam}!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const ally = arena.allocator();

    var args = try std.process.argsWithAllocator(ally);
    defer args.deinit();

    std.debug.assert(args.skip());

    const eval_choice = args.next() orelse return error.BadParam;
    const tm_choice = args.next() orelse return error.BadParam;

    const tm: TM = if (mem.eql(u8, tm_choice, "bb1"))
        .bb1
    else if (mem.eql(u8, tm_choice, "bb2"))
        .bb2
    else if (mem.eql(u8, tm_choice, "bb3"))
        .bb3
    else if (mem.eql(u8, tm_choice, "bb4"))
        .bb4
    else
        return error.BadParam;

    if (mem.eql(u8, eval_choice, "TM")) {
        const eval: TM = .from(tm);
        defer eval.deinit(ally);
        
        try eval.eval(ally);
        const out = try eval.tape.to_array(ally);
        defer ally.free(out);
        
        std.log.err("{any}", out);
    } else return error.BadParam;
}
