const Builder = @import("std").build.Builder;
const LibExeObjStep = @import("std").build.LibExeObjStep;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zsodium", "src/main.zig");
    lib.setBuildMode(mode);
    add_sodium(lib);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    add_sodium(main_tests);
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}

fn add_sodium(obj: *LibExeObjStep) void {
    obj.addSystemIncludeDir("/usr/include");
    obj.addLibPath("/usr/lib/x86_64-linux-gnu/");
    obj.linkSystemLibrary("sodium");
    obj.linkLibC();
}
