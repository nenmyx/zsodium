const nacl = @import("c.zig");
const SodiumError = @import("util.zig").SodiumError;
const Allocator = @import("std").mem.Allocator;

// TODO: Remove comptime types in "to" functions.

// Hexadecimal encoding
pub fn toHex(a: *Allocator, comptime T: type, bin: []const T) ![]u8 {
    const binBytes = @sliceToBytes(bin);
    var hex = try a.alloc(u8, binBytes.len * 2 + 1);
    // This function returns a pointer we already have, discard the return.
    _ = nacl.sodium_bin2hex(hex.ptr, hex.len, binBytes.ptr, binBytes.len);

    return hex;
}

pub fn fromHex(a: *Allocator, comptime T: type, hex: []const u8, ignore: []const u8) ![]T {
    var bin = try a.alloc(T, hex.len / 2);
    // This function returns a pointer we already have, discard the return.
    _ = nacl.sodium_hex2bin(@sliceToBytes(bin).ptr, @sizeOf(T) * bin.len, hex.ptr, hex.len, null, null, null);

    return bin;
}

// Base64 encoding
// I don't know why zig.vim decides this is acceptable but here we are.
pub const Base64Variant = enum(c_int) {
    Original = nacl.sodium_base64_VARIANT_ORIGINAL, OriginalNoPadding = nacl.sodium_base64_VARIANT_ORIGINAL_NO_PADDING, UrlSafe = nacl.sodium_base64_VARIANT_URLSAFE, UrlSafeNoPadding = nacl.sodium_base64_VARIANT_URLSAFE_NO_PADDING
};

pub fn toBase64(a: *Allocator, comptime T: type, bin: []const T, variant: Base64Variant) ![]u8 {
    const bytes = @sliceToBytes(bin);
    const b64 = try a.alloc(u8, nacl.sodium_base64_encoded_len(bytes.len, @enumToInt(variant)));
    _ = nacl.sodium_bin2base64(b64.ptr, b64.len, bytes.ptr, bytes.len, @enumToInt(variant));

    return b64;
}

pub fn fromBase64(a: *Allocator, comptime T: type, b64: []const u8, variant: Base64Variant) ![]T {
    const bin = try a.alloc(T, (b64.len * 6) / (8 * @sizeOf(T)));
    _ = nacl.sodium_base642bin(@sliceToBytes(bin).ptr, @sizeOf(T) * bin.len, b64.ptr, b64.len, null, null, null, @enumToInt(variant));

    return bin;
}
