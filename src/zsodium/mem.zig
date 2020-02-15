// Memory management exposed by libsodium.

const TypeId = @import("builtin").TypeId;
const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const math = std.math;
const os = std.os;

const SodiumError = @import("util.zig").SodiumError;
const nacl = @import("c.zig");

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
    if (os.errno(@ptrToInt(am)) != 0)
        return SodiumError.AllocError;

    return am[0..len];
}

/// Frees any data that was allocated by mem.alloc(). If the given memory was not,
/// application will immediately exit. The application will also immediately exit
/// if there is evidence of tampering, and the memory will be zero passed before
/// being freed.
pub fn free(buf: var) void {
    // Check ourselves since we want to let anything in.
    comptime assert(@typeId(@TypeOf(buf)) == TypeId.Pointer);
    nacl.sodium_free(@as(*c_void, buf.ptr));
}

/// Zeroes the given memory.
pub fn zero(comptime T: type, buf: []T) void {
    nacl.sodium_memzero(buf.ptr, @sizeOf(T) * buf.len);
}

/// Locks the specified region of memory to avoid it being moved to swap.
/// Used to ensure critical memory (like cryptographic keys) can remain
/// in memory and not ever sent to a more persistent storage medium.
pub fn lock(comptime T: type, buf: []T, len: usize) !void {
    if (nacl.sodium_mlock(@as(*c_void, buf.ptr), @sizeOf(T) * len) < 0)
        return SodiumError.LockLimitError;
}

/// Unlocks the specified region of memory, to tell the kernel it can be
/// sent to swap safely.
pub fn unlock(comptime T: type, buf: []T, len: usize) void {
    // TODO: Figure out if this is an error return value or not.
    _ = nacl.sodium_munlock(@as(*c_void, buf.ptr), @sizeOf(T) * len);
}

/// Ease of use function to use mprotect() to specify to the kernel that
/// the given region of memory should not be able to be read from or written to.
pub fn noAccess(buf: var) !void {
    if (nacl.sodium_mprotect_noaccess(@as(*c_void, buf)) != 0)
        return SodiumError.MProtectError;
}

/// Ease of use function to use mprotect() to specify to the kernel that
/// the given region of memory is read only.
pub fn readOnly(buf: var) !void {
    if (nacl.sodium_mprotect_readonly(@as(*c_void, buf)) != 0)
        return SodiumError.MProtectError;
}

/// Ease of use function to use mprotect() to specify to the kernel that
/// the given region of memory should be open for reading and writing.
pub fn readWrite(buf: var) !void {
    if (nacl.sodium_mprotect_readwrite(@as(*c_void, buf)) != 0)
        return SodiumError.MProtectError;
}

/// Constant time memory comparison, only checks for equality.
pub fn eql(comptime T: type, mema: []const T, memb: []const T) bool {
    return nacl.sodium_memcmp(mema.ptr, memb.ptr, math.min(mema.len, memb.len)) == 0;
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
    const new_mem = alloc(u8, new_size) catch @panic("unable to allocate memory using sodium_malloc");

    // Initialize the new memory
    mem.set(u8, new_mem, 0);
    if (old_mem.len == 0) {
        return new_mem;
    }

    if (old_mem.len > new_size) {
        mem.copy(u8, new_mem, old_mem[0..new_size]);
    } else if (new_mem.len > 0) {
        mem.copy(u8, new_mem, old_mem);
    }

    free(old_mem);
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
