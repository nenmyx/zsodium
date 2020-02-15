const Builder = @import("std").build.Builder;
const LibExeObjStep = @import("std").build.LibExeObjStep;

const NAME = "zsodium";
const VERSION = "0.0.0";
const FILE = "build/" ++ NAME ++ "." ++ VERSION ++ ".tar.gz";

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    // "Build" using system commands, by bundling the source files
    // into a tar volume for distribution.
    const COMMAND = [_][]const u8{ "tar", "--exclude=\".*\"", "-cvf", FILE, "*" };
    const cmd_step = b.addSystemCommand(COMMAND[0..COMMAND.len]);

    // We don't want a shared or static object for a Zig library.
    // Kind of annoying everything is "build from source" nowadays,
    // but it's what we're stuck with right now.

    //const lib = b.addStaticLibrary("zsodium", "src/zsodium.zig");
    //lib.setBuildMode(mode);
    //add_sodium(lib);
    //lib.install();

    var main_tests = b.addTest("src/tests.zig");
    add_sodium(main_tests);
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run lib tests");
    test_step.dependOn(&main_tests.step);

    const bundle_step = b.step("bundle", "Bundle lib into tar volume");
    bundle_step.dependOn(&cmd_step.step);
}

fn add_sodium(obj: *LibExeObjStep) void {
    obj.addSystemIncludeDir("/usr/include");
    obj.addLibPath("/usr/lib/x86_64-linux-gnu/");
    obj.linkSystemLibrary("sodium");
    obj.linkLibC();
}
