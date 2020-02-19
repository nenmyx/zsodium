const TypeId = @import("builtin").TypeId;
const assert = @import("std").debug.assert;

pub const SodiumError = error{
    InitError,
    AllocError,
    LockError,
    MProtectError,
};

// Functions mean't to help enforce typing as much as we realistically can,
// for the functions that accept everything and the kitchen sink.

pub inline fn assertPtr(val: var) void {
    comptime const id = @typeId(@TypeOf(val));
    comptime assert(id == TypeId.Pointer or id == TypeId.Array);
}

pub inline fn gatherSize(val: var) usize {
    // TODO: Figure out if erroring is a better solution.
    if (val.len < 1)
        return 0;

    return @sizeOf(@TypeOf(val[0])) * val.len;
}

// We slice everything here to ensure we can @sliceToBytes in case we're sent
// something that is not a slice. Is all of this overkill? Possibly.

pub inline fn getPtr(val: var) [*c]u8 {
    var slice = val[0..];
    return @as([*c]u8, @sliceToBytes(slice).ptr);
}

pub inline fn getConstPtr(val: var) [*c]const u8 {
    const slice = val[0..];
    return @as([*c]const u8, @sliceToBytes(slice).ptr);
}
