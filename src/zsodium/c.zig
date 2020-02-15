// This is the raw C bindings. Exposed for use in-library,
// but also if you absolutely want them outside this library.
pub usingnamespace @cImport({
    @cInclude("sodium.h");
});
