// ZSodium wrappers and abstractions over the libsodium cryptographic library.
// These wrappers provide access to a well vetted, audited, and maintained suite
// of cryptographic algorithms and tooling.
// Libsodium: https://libsodium.org/

// All tests are in this file since otherwise the compiler just ignores imports.

pub const SodiumError = @import("zsodium/util.zig").SodiumError;
const nacl = @import("zsodium/c.zig");

/// Initializes libsodium for use within the application, if initialization failes,
/// A catchable error is returned. When initialization fails an application that
/// requires use of libsodium should panic, or exit gracefully, up to you.
pub fn init() !void {
    if (nacl.sodium_init() < 0)
        return SodiumError.InitError;
}

/// Libsodium memory management, locking, mprotect, and secure allocation and
/// freeing of memory.
pub const mem = @import("zsodium/mem.zig");
