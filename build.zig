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

    const demos = [_]struct { name: []const u8, root: []const u8, description: []const u8 }{
        .{ .name = "play", .root = "demos/playground.zig", .description = "Run the playground (used for testing new features)" },
        .{ .name = "fp", .root = "demos/first_person.zig", .description = "Run the 3D First Person demo" },
        .{ .name = "asteroids", .root = "demos/asteroids.zig", .description = "Run the Asteroids game demo" },
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

        exe.addObjectFile(.{ .cwd_relative = "zig-out/App.o" });
        exe.linkFramework("AppKit");
        exe.linkFramework("CoreGraphics");
        exe.step.dependOn(&mac_module.step);

        b.installArtifact(exe);

        const run_step = b.step(demo.name, demo.description);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        run_step.dependOn(&run_cmd.step);
    }
}
