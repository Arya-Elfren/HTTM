pub const State = struct {
    pub const PartialState = struct {
        write: u1,
        move: enum(u1) { left, right },
        next: ?*const State,
    };

    read_zero: PartialState,
    read_one: PartialState,
};

states: []State,
