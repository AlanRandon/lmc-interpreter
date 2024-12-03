const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const assembler_exe = b.addExecutable(.{
        .name = "lmc-as",
        .root_source_file = b.path("src/assembler.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(assembler_exe);

    const assembler_run_cmd = b.addRunArtifact(assembler_exe);
    assembler_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        assembler_run_cmd.addArgs(args);
    }

    const assembler_run_step = b.step("lmc-as", "Run the assembler");
    assembler_run_step.dependOn(&assembler_run_cmd.step);

    const assembler_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/assembler.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_assembler_unit_tests = b.addRunArtifact(assembler_unit_tests);

    const debugger_exe = b.addExecutable(.{
        .name = "lmc-dbg",
        .root_source_file = b.path("src/debugger.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(debugger_exe);

    const debugger_run_cmd = b.addRunArtifact(debugger_exe);
    debugger_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        debugger_run_cmd.addArgs(args);
    }

    const debugger_run_step = b.step("lmc-dbg", "Run the debugger");
    debugger_run_step.dependOn(&debugger_run_cmd.step);

    const debugger_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/debugger.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_debugger_unit_tests = b.addRunArtifact(debugger_unit_tests);

    const interp_exe = b.addExecutable(.{
        .name = "lmci",
        .root_source_file = b.path("src/interpreter.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(interp_exe);

    const interp_run_cmd = b.addRunArtifact(interp_exe);
    interp_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        interp_run_cmd.addArgs(args);
    }

    const interp_run_step = b.step("lmci", "Run the interpreter");
    interp_run_step.dependOn(&interp_run_cmd.step);

    const interp_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/interpreter.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_interp_unit_tests = b.addRunArtifact(interp_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_interp_unit_tests.step);
    test_step.dependOn(&run_assembler_unit_tests.step);
    test_step.dependOn(&run_debugger_unit_tests.step);
}
