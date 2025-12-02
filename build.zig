const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mac_module = b.addSystemCommand(&.{
        "clang",
        "-O2",
        "-c",
        "src/platform/MacOS/App.m",
        "-o",
        "zig-out/App.o",
    });

    const canvas_lib = b.addModule("renderer", .{
        .root_source_file = b.path("src/canvas.zig"),
        .optimize = optimize,
    });

    const window_lib = b.addModule("window_manager", .{
        .root_source_file = b.path("src/window.zig"),
        .optimize = optimize,
    });

    const play = b.addExecutable(.{
        .name = "playground",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demos/playground.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    play.root_module.addImport("renderer", canvas_lib);
    play.root_module.addImport("window", window_lib);

    play.addObjectFile(.{ .cwd_relative = "zig-out/App.o" });
    play.linkFramework("AppKit");
    play.linkFramework("CoreGraphics");

    play.step.dependOn(&mac_module.step);

    b.installArtifact(play);

    const run_playground = b.step("play", "Run the playground (used for testing new features)");

    const run_play_cmd = b.addRunArtifact(play);
    run_playground.dependOn(&run_play_cmd.step);

    run_play_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_play_cmd.addArgs(args);
    }
}
