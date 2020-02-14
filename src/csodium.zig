// "csodium" is a minimal wrapper around the C libsodium functions.
// These exist to add basic enforcements, and handle interfacing with C, and
// wrap them nicely into a struct for use in the rest of this library.

// These are safe to use outside the library, however any required
// things (like sodium_init) will be included into the main library itself.
// So these should only be used if you want in in-between between the straight
// C functions, and a more Zig-style struct approach.

// If you want to handle just using the library, avoid this part.
// There are higher level abstractions for normal use.

const nacl = @import("c.zig");
const c = @import("std").c;
const os = @import("std").os;

pub const SodiumError = error{
    InitError,
    AllocError,
    LockLimitError,
};

// INITIALIZATION
pub fn init() !void {
    if (nacl.sodium_init() < 0)
        return SodiumError.InitError;
}

// MEMORY HANDLING
pub const mem = struct {
    pub fn alloc(comptime T: type, len: usize) ![*c]T {
        const am = @ptrCast([*c]T, nacl.sodium_malloc(@sizeOf(T) * len));
        if (os.errno(@ptrToInt(am)) != 0)
            return SodiumError.AllocError;

        return am;
    }

    // TODO: Figure out how to remve the need for the type argument
    // since sodium_free sure doesn't care.
    pub fn free(comptime T: type, buf: [*c]T) void {
        nacl.sodium_free(@as(*c_void, buf));
    }

    pub fn lock(comptime T: type, buf: [*c]u8, len: usize) !void {
        if (nacl.sodium_mlock(@as(*c_void, buf), @sizeOf(T) * len) < 0)
            return SodiumError.LockLimitError;
    }

    pub fn unlock(comptime T: type, buf: [*c]u8, len: usize) void {
        // TODO: Figure out if this is an error return value or not.
        _ = nacl.sodium_munlock(@as(*c_void, buf), @sizeOf(T) * len);
    }

    pub fn allocArray(comptime T: type, len: usize) ![*c]T {
        // TODO: Enforce size_max in Zig.
        const am = @ptrCast([*c]T, nacl.sodium_allocarray(len, @sizeOf(T)));
        if (os.errno(@ptrToInt(am)) != 0)
            return SodiumError.AllocError;

        return am;
    }

    pub fn noAccess(comptime T: type, buf: [*c]T) void {
        _ = nacl.sodium_mprotect_noaccess(@as(*c_void, buf));
    }

    pub fn readOnly(comptime T: type, buf: [*c]T) void {
        _ = nacl.sodium_mprotect_readonly(@as(*c_void, buf));
    }

    pub fn readWrite(comptime T: type, buf: [*c]T) void {
        _ = nacl.sodium_mprotect_readwrite(@as(*c_void, buf));
    }
};
