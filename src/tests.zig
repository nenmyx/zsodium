const zsodium = @import("zsodium.zig");
const mem = zsodium.mem;

const std = @import("std");
const assert = std.debug.assert;
const memset = std.mem.set;

const fs = @import("std").fs;
const OpenFlags = fs.File.OpenFlags;

// **** INITIALIZATION ****
test "sodium_init happy path" {
    try zsodium.init();
}

// **** MEMORY ****
test "alloc and leak" {
    const am = try mem.alloc(u8, 32);

    assert(am[0] == 0xDB);
    am[0] = 0xAA;
    assert(am[0] == 0xAA);
}

test "alloc and free" {
    const am = try mem.alloc(u32, 32);
    defer mem.free(am);
}

test "allocArray and free" {
    const am = try mem.allocArray(u8, 32);
    defer mem.free(am);

    assert(am[0] == 0xDB);
}

test "lock/unlock allocated memory" {
    const am = try mem.alloc(u16, 16);
    defer mem.free(am);

    try mem.lock(u16, am, 16);
    mem.unlock(u16, am, 16);
}

test "constant time comparison of same types" {
    const am = try mem.alloc(u8, 32);
    const bm = try mem.alloc(u8, 24);

    assert(mem.eql(u8, am, bm));
}

test "constant time comparison of different types" {
    const am = try mem.alloc(u8, 32);
    const bm = try mem.alloc(u16, 12);

    // Kinda dumb but casting down is always the safer bet.
    assert(mem.eql(u8, am, @sliceToBytes(bm)));
}

test "constant time comparison of higher alignment types" {
    const am = try mem.alloc(u64, 24);
    const bm = try mem.alloc(u64, 32);

    // Kinda dumb but casting down is always the safer bet.
    assert(mem.eql(u64, am, bm));
}

test "contant time comparison not equal" {
    const am = try mem.alloc(u64, 1);
    const bm = try mem.alloc(u64, 1);
    am[0] = 0x00;

    // Kinda dumb but casting down is always the safer bet.
    assert(!mem.eql(u64, am, bm));
}

test "zero allocated memory" {
    const m = try mem.alloc(u32, 8);
    const z = try mem.alloc(u32, 8);
    memset(u32, z, 0);
    mem.zero(u32, m);

    assert(m[0] == 0);
}

test "zero pre-allocated memory" {
    var m = [_]u16{ 1, 1, 2, 3, 5, 8 };
    var z = [_]u16{ 0, 0, 0, 0, 0, 0 };
    mem.zero(u16, m[0..m.len]);

    assert(mem.eql(u16, m[0..m.len], z[0..z.len]));
}

test "allocator used as an allocator" {
    const f = try fs.cwd().openFile("test/hello.txt", OpenFlags{ .read = true, .write = false });
    const fstream = &f.inStream().stream;

    const data = try fstream.readAllAlloc(mem.sodium_allocator, 16);
    const correct = "hello!";
    assert(mem.eql(u8, data, correct[0..]));

    mem.sodium_allocator.free(data);
    f.close();
}
