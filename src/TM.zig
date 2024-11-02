pub const State = packed struct {
    pub const PartialState = packed struct {
        write: u1,
        move: enum(u1) { left, right },
    };

    read_zero: PartialState,
    read_one: PartialState,
};
