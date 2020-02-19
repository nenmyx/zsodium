// Memory management exposed by libsodium.

const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const math = std.math;
const os = std.os;

const nacl = @import("c.zig");

usingnamespace @import("util.zig");

/// Allocates a chunk of memory at the end of a page boundary, and initialized
/// with 0xDB. Asserts that the data allocated is properly aligned for the given
/// type.
pub fn alloc(comptime T: type, len: usize) ![]T {
    // Ensure we only allocate aligned values.
    // As otherwise sodium_malloc can become inconsistent.
    const alen = @sizeOf(T) * len;

    // This is mostly a sanity check, since we require you to specify a type.
    // So things should always be aligned realistically, unless you're allocating
    // A variable sized or certain packed structs. But you shouldn't be using this
    // for those use cases anyways.
    assert(alen % @alignOf(T) == 0);

    const am = @ptrCast([*c]T, @alignCast(@alignOf(T), nacl.sodium_malloc(alen)));
    // TODO: Error based on errno, instead of something generic.
    if (os.errno(@ptrToInt(am)) != 0)
        return SodiumError.AllocError;

    return am[0..len];
}

/// It provides the same guarantees as mem.alloc() but also protects against
/// arithmetic overflows when count * size exceeds SIZE_MAX.
pub fn allocArray(comptime T: type, len: usize) ![]T {
    // Same sanity check as above.
    const alen = @sizeOf(T) * len;
    assert(alen % @alignOf(T) == 0);

    // TODO?: Enforce size_max in Zig.
    const am = @ptrCast([*c]T, @alignCast(@alignOf(T), nacl.sodium_allocarray(len, @sizeOf(T))));
    // TODO: Error based on errno, instead of something generic.
    if (os.errno(@ptrToInt(am)) != 0)
        return SodiumError.AllocError;

    return am[0..len];
}

/// Frees any data that was allocated by mem.alloc(). If the given memory was not,
/// application will immediately exit. The application will also immediately exit
/// if there is evidence of tampering, and the memory will be zero passed before
/// being freed.
pub fn free(buf: var) void {
    assertPtr(buf);
    nacl.sodium_free(getPtr(buf));
}

/// Zeroes the given memory.
pub fn zero(buf: var) void {
    assertPtr(buf);
    const bufsize = gatherSize(buf);
    nacl.sodium_memzero(getPtr(buf), bufsize);
}

/// Checks that the given memory is all zeroed.
pub fn isZero(buf: var) bool {
    assertPtr(buf);
    const bufsize = gatherSize(buf);
    return nacl.sodium_is_zero(getConstPtr(buf), bufsize) == 1;
}

/// Locks the specified region of memory to avoid it being moved to swap.
/// Used to ensure critical memory (like cryptographic keys) can remain
/// in memory and not ever sent to a more persistent storage medium.
pub fn lock(buf: var) !void {
    assertPtr(buf);
    const bufsize = gatherSize(buf);

    // TODO: Error based on errno, instead of something generic.
    if (nacl.sodium_mlock(getPtr(buf), bufsize) != 0)
        return SodiumError.LockError;
}

/// Unlocks the specified region of memory, to tell the kernel it can be
/// sent to swap safely.
pub fn unlock(buf: var) !void {
    assertPtr(buf);
    const bufsize = gatherSize(buf);

    // TODO: Error based on errno, instead of something generic.
    if (nacl.sodium_munlock(getPtr(buf), bufsize) != 0)
        return SodiumError.LockError;
}

/// Ease of use function to use mprotect() to specify to the kernel that
/// the given region of memory should not be able to be read from or written to.
pub fn noAccess(buf: var) !void {
    assertPtr(buf);
    if (nacl.sodium_mprotect_noaccess(getConstPtr(buf)) != 0)
        return SodiumError.MProtectError;
}

/// Ease of use function to use mprotect() to specify to the kernel that
/// the given region of memory is read only.
pub fn readOnly(buf: var) !void {
    assertPtr(buf);
    if (nacl.sodium_mprotect_readonly(getConstPtr(buf)) != 0)
        return SodiumError.MProtectError;
}

/// Ease of use function to use mprotect() to specify to the kernel that
/// the given region of memory should be open for reading and writing.
pub fn readWrite(buf: var) !void {
    assertPtr(buf);
    if (nacl.sodium_mprotect_readwrite(getConstPtr(buf)) != 0)
        return SodiumError.MProtectError;
}

/// Constant time memory comparison, only checks for equality.
pub fn eql(mema: var, memb: var) bool {
    // Ensure both arguments are valid to be compared. As
    // this allows up to more readily compare the bytes of
    // different types of data, this is a memory comparison
    // after all, not a "value" comparison strictly.
    assertPtr(mema);
    assertPtr(memb);

    const as = gatherSize(mema);
    const bs = gatherSize(memb);

    return nacl.sodium_memcmp(getConstPtr(mema), getConstPtr(memb), math.min(as, bs)) == 0;
}

// Below is the allocation functions for sodium_allocator, as well as sodium_allocator
// itself. These are not intended to be used in any other context.

/// The primary alloc/realloc/free function for use with the Allocator.
/// We will not change or check with mprotect, as it is not the job of this function
/// to guarantee memory security, and it would be setting it implicitly which would
/// allow for certain security vulnerabilities to exist. Instead, we will assume that
/// all memory is read/write, and segfault if not. If critical memory is going through
/// this function, it should be set to read/write before handled.
fn realloc(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) Allocator.Error![]u8 {
    // TODO: See if realigning to the page is necessary, since libsodium will always use the
    // end of the page anyway.
    const new_mem = alloc(u8, new_size) catch return Allocator.Error.OutOfMemory;

    // TODO: Figure out where the 0xAA bytes are coming from, they seem
    // to occur after this function, as zeroing out the bytes does nothing.
    zero(new_mem);

    // Short circuit in event of null pointer.
    if (old_mem.len == 0) {
        return new_mem;
    }

    defer free(old_mem);
    if (old_mem.len > new_size) {
        mem.copy(u8, new_mem, old_mem[0..new_size]);
    } else if (new_mem.len > 0) {
        mem.copy(u8, new_mem, old_mem);
    }

    return new_mem;
}

/// A small wrapper around realloc().
fn shrink(a: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) []u8 {
    return realloc(a, old_mem, old_align, new_size, new_align) catch unreachable;
}

/// Zig Allocator using libsodium allocation and free functions,
/// for use with standard Zig libraries and functions.
pub const sodium_allocator = &Allocator{
    .reallocFn = realloc,
    .shrinkFn = shrink,
};
