const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mac_module = b.addSystemCommand(&.{
        "clang",
        "-O2",
        "-c",
        "src/platform/macOS/App.m",
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

    const input_lib = b.addModule("input_manager", .{
        .root_source_file = b.path("src/input.zig"),
        .optimize = optimize,
    });

    const demos = [_]struct { name: []const u8, root: []const u8, description: []const u8 }{
        .{ .name = "play", .root = "demos/playground.zig", .description = "Run the playground (used for testing new features)" },
        .{ .name = "fp", .root = "demos/first_person.zig", .description = "Run the 3D First Person demo" },
        .{ .name = "asteroids", .root = "demos/asteroids.zig", .description = "Run the Asteroids game demo" },
        .{ .name = "benchmark", .root = "demos/benchmark.zig", .description = "Run the software renderer benchmark" },
    };

    for (demos) |demo| {
        const exe = b.addExecutable(.{
            .name = demo.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(demo.root),
                .target = target,
                .optimize = optimize,
            }),
        });

        exe.root_module.addImport("renderer", canvas_lib);
        exe.root_module.addImport("window", window_lib);
        exe.root_module.addImport("input", input_lib);

        if (target.result.os.tag == .macos) {
            exe.addObjectFile(.{ .cwd_relative = "zig-out/App.o" });
            exe.linkFramework("AppKit");
            exe.linkFramework("CoreGraphics");
            exe.step.dependOn(&mac_module.step);
        } else if (target.result.os.tag == .linux) {
            exe.addCSourceFile(.{ .file = b.path("src/platform/Linux/X11.c"), .flags = &.{} });
            exe.addCSourceFile(.{ .file = b.path("src/platform/Linux/Wayland.c"), .flags = &.{} });
            exe.linkSystemLibrary("X11");
            exe.linkLibC();
        } else if (target.result.os.tag == .windows) {
            exe.addCSourceFile(.{ .file = b.path("src/platform/Windows/App.c"), .flags = &.{} });
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("gdi32");
            exe.linkLibC();
        }

        b.installArtifact(exe);

        const run_step = b.step(demo.name, demo.description);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        run_step.dependOn(&run_cmd.step);
    }
}
