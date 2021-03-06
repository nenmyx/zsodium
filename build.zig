const Builder = @import("std").build.Builder;
const LibExeObjStep = @import("std").build.LibExeObjStep;
const fs = @import("std").fs;

const NAME = "zsodium";
const VERSION = "0.1.0";

// Enjoy this cursed way to bundle, this is done mostly out of laziness.
// My focus is on proper interaction with libsodium, not the cleanest way
// to possibly generate a tar volume.
const FILE = "../build/" ++ NAME ++ "." ++ VERSION ++ ".tar.gz";
const SUBCMD = "cd src/ && tar --exclude=\".*\" -cvf" ++ FILE ++ " *";

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    // "Build" using system commands, by bundling the source files
    // into a tar volume for distribution.
    // TODO: Don't tie so close to bash or linux.
    const COMMAND = [_][]const u8{ "bash", "-c", SUBCMD };
    const cmd_step = b.addSystemCommand(COMMAND[0..]);

    // We don't want a shared or static object for a Zig library.
    // Kind of annoying that everything is "build from source" nowadays,
    // but it's what we're stuck with right now.

    // TODO: Revisit is a static or shared library can be imported in an
    // actual Zig style, instead of just being ran back through a cImport.
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
    // TODO: Don't tie so close to bash or linux.
    obj.addSystemIncludeDir("/usr/include");
    obj.addLibPath("/usr/lib/x86_64-linux-gnu/");
    obj.linkSystemLibrary("sodium");
    obj.linkLibC();
}
