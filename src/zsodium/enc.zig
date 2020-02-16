const nacl = @import("c.zig");
const SodiumError = @import("util.zig").SodiumError;
const Allocator = @import("std").mem.Allocator;

// Hexadecimal encoding
pub fn toHex(a: *Allocator, comptime T: type, bin: []const T) ![]u8 {
    const binBytes = @sliceToBytes(bin);
    var hex = try a.alloc(u8, binBytes.len * 2 + 1);
    // This function returns a pointer we already have, discard the return.
    _ = nacl.sodium_bin2hex(hex.ptr, hex.len, binBytes.ptr, binBytes.len);

    return hex;
}

pub fn fromHex(a: *Allocator, comptime T: type, hex: []const u8, ignore: []const u8) ![]T {
    var bin = try a.alloc(u8, hex.len / 2);
    // This function returns a pointer we already have, discard the return.
    _ = nacl.sodium_hex2bin(bin.ptr, bin.len, hex.ptr, hex.len, null, null, null);

    return @as([]T, bin);
}

// Base64 encoding
// I don't know why zig.vim decides this is acceptable but here we are.
pub const Base64Variant = enum(c_int) {
    Original = nacl.sodium_base64_VARIANT_ORIGINAL, OriginalNoPadding = nacl.sodium_base64_VARIANT_ORIGINAL_NO_PADDING, UrlSafe = nacl.sodium_base64_VARIANT_URLSAFE, UrlSafeNoPadding = nacl.sodium_base64_VARIANT_URLSAFE_NO_PADDING
};

pub fn toBase64(a: *Allocator, comptime T: type, bin: []const T, variant: Base64Variant) ![]u8 {}

pub fn fromBase64(a: *Allocator, comptime T: type, b64: []const u8, variant: Base64Variant) ![]T {}
