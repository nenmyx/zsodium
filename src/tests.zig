const std = @import("std");
const assert = std.debug.assert;
const memset = std.mem.set;

const fs = @import("std").fs;
const OpenFlags = fs.File.OpenFlags;

// **** INITIALIZATION ****
const zsodium = @import("zsodium.zig");

test "sodium_init happy path" {
    try zsodium.init();
}

// **** MEMORY ****
const mem = zsodium.mem;

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

    try mem.lock(am);
    try mem.unlock(am);
}

test "lock/unlock pre-allocated memory" {
    var am = [_]u8{ 1, 1, 2, 3, 5, 8 };

    try mem.lock(am[0..]);
    try mem.unlock(am[0..]);
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

    assert(mem.eql(u64, am, bm));
}

test "contant time comparison not equal" {
    const am = try mem.alloc(u64, 1);
    const bm = try mem.alloc(u64, 1);
    am[0] = 0x00;

    assert(!mem.eql(u64, am, bm));
}

test "zero allocated memory" {
    const m = try mem.alloc(u32, 8);
    const z = try mem.alloc(u32, 8);
    memset(u32, z, 0);
    mem.zero(m);

    assert(m[0] == 0);
}

test "zero pre-allocated memory" {
    var m = [_]u16{ 1, 1, 2, 3, 5, 8 };
    var z = [_]u16{ 0, 0, 0, 0, 0, 0 };
    mem.zero(m[0..]);

    assert(mem.eql(u16, m[0..], z[0..]));
}

test "memory is zero" {
    const z = [_]u16{ 0, 0, 0, 0, 0, 0 };
    assert(mem.isZero(z[0..]));
}

test "memory is not zero" {
    const m = [_]u16{ 1, 1, 2, 3, 5, 8 };
    assert(!mem.isZero(m[0..]));
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

test "allocator realloc larger" {
    var am = try mem.sodium_allocator.alloc(u8, 4);
    defer mem.sodium_allocator.free(am);
    am[0] = 0xDE;
    am[1] = 0xAD;
    am[2] = 0xBE;
    am[3] = 0xEF;

    am = try mem.sodium_allocator.realloc(am, 8);
    assert(am[3] == 0xEF);
}

test "allocator realloc smaller" {
    var am = try mem.sodium_allocator.alloc(u8, 4);
    defer mem.sodium_allocator.free(am);
    am[0] = 0xDE;
    am[1] = 0xAD;
    am[2] = 0xBE;
    am[3] = 0xEF;

    am = try mem.sodium_allocator.realloc(am, 2);
    assert(am[1] == 0xAD);
}

// **** ENCODING/DECODING ****
const enc = zsodium.enc;

test "bin to/from hex u8" {
    const am = [_]u8{ 1, 3, 3, 7 };
    const hex = try enc.toHex(mem.sodium_allocator, u8, am[0..]);
    assert(mem.eql(u8, hex, "01030307"));

    const rev = try enc.fromHex(mem.sodium_allocator, u8, hex, "");
    assert(mem.eql(u8, rev, am[0..]));
}

test "bin to/from hex u16" {
    const am = [_]u16{ 1, 3, 3, 7 };
    const hex = try enc.toHex(mem.sodium_allocator, u16, am[0..]);
    // Just don't run the tests on a big-endian architecture, it's fine.
    // TODO: Check for endianness and check accordingly.
    assert(mem.eql(u8, hex, "0100030003000700"));

    const rev = try enc.fromHex(mem.sodium_allocator, u16, hex, "");
    assert(mem.eql(u16, rev, am[0..]));
}

test "bin to/from base64 original variant" {
    const am = [_]u16{ 0xAA, 0xBB, 0xCC, 0xDD };
    const b64 = try enc.toBase64(mem.sodium_allocator, u16, am[0..], enc.Base64Variant.Original);
    assert(mem.eql(u8, b64, "qgC7AMwA3QA="));

    const rev = try enc.fromBase64(mem.sodium_allocator, u16, b64, enc.Base64Variant.Original);
    assert(mem.eql(u16, am[0..], rev));
}

test "bin to/from base64 original padless variant" {
    const am = [_]u16{ 0xAA, 0xBB, 0xCC, 0xDD };
    const b64 = try enc.toBase64(mem.sodium_allocator, u16, am[0..], enc.Base64Variant.OriginalNoPadding);
    assert(mem.eql(u8, b64, "qgC7AMwA3QA"));

    const rev = try enc.fromBase64(mem.sodium_allocator, u16, b64, enc.Base64Variant.OriginalNoPadding);
    assert(mem.eql(u16, am[0..], rev));
}

// TODO: Fix the following test data to actually require url safe characters.

test "bin to/from base64 url safe variant" {
    const am = [_]u16{ 0xAA, 0xBB, 0xCC, 0xDD };
    const b64 = try enc.toBase64(mem.sodium_allocator, u16, am[0..], enc.Base64Variant.UrlSafe);
    assert(mem.eql(u8, b64, "qgC7AMwA3QA="));

    const rev = try enc.fromBase64(mem.sodium_allocator, u16, b64, enc.Base64Variant.UrlSafe);
    assert(mem.eql(u16, am[0..], rev));
}

test "bin to/from base64 url safe padless variant" {
    const am = [_]u16{ 0xAA, 0xBB, 0xCC, 0xDD };
    const b64 = try enc.toBase64(mem.sodium_allocator, u16, am[0..], enc.Base64Variant.UrlSafeNoPadding);
    assert(mem.eql(u8, b64, "qgC7AMwA3QA"));

    const rev = try enc.fromBase64(mem.sodium_allocator, u16, b64, enc.Base64Variant.UrlSafeNoPadding);
    assert(mem.eql(u16, am[0..], rev));
}
