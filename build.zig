const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const backtrace = b.dependency("backtrace", .{
        .target = target,
        .optimize = optimize,
    });
    _ = b.addModule("logger", .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{.{ .name = "backtrace", .module = backtrace.module("backtrace") }},
    });

    // Lib
    const lib = b.addStaticLibrary(.{
        .name = "logger",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("backtrace", backtrace.module("backtrace"));
    b.installArtifact(lib);

    // Unit Testing
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.root_module.addImport("backtrace", backtrace.module("backtrace"));
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
