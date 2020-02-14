const sodium = @import("csodium.zig");

// TODO: Break the tests into the right file.
test "basic add functionality" {
    try sodium.init();

    var buf = try sodium.mem.allocArray(u8, 32);
    defer sodium.mem.free(u8, buf);

    try sodium.mem.lock(u8, buf, 32);
    sodium.mem.unlock(u8, buf, 32);

    sodium.mem.noAccess(u8, buf);
    sodium.mem.readOnly(u8, buf);
    sodium.mem.readWrite(u8, buf);
}
