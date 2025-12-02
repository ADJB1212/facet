const std = @import("std");
const builtin = @import("builtin");

const Platform = enum { MacOS, Linux_X11, Linux_Wayland, Windows };

const WindowError = error{UnsupportedPlatform};

extern fn macos_init_app() void;
extern fn macos_poll_events() bool;
extern fn macos_present_frame() void;

fn get_platform() WindowError!Platform {
    return switch (builtin.os.tag) {
        .macos => .MacOS,
        .windows => .Windows,
        .linux => return switch (detect_linux_display()) {
            .Wayland => .Linux_Wayland,
            .X11 => .Linux_X11,
            .Unknown => WindowError.UnsupportedPlatform,
        },
        else => WindowError.UnsupportedPlatform,
    };
}

fn detect_linux_display() enum { X11, Wayland, Unknown } {
    const env = std.process.getEnvMap(std.heap.page_allocator) catch return .Unknown;
    defer env.deinit();

    if (env.get("WAYLAND_DISPLAY") != null) {
        return .Wayland;
    }
    if (env.get("DISPLAY") != null) {
        return .X11;
    }
    return .Unknown;
}

fn unsupported_platform() noreturn {
    std.debug.print("This platform is not supported yet!\n", .{});
    std.process.exit(1);
}

pub fn init() void {
    const platform: Platform = get_platform() catch unsupported_platform();

    switch (platform) {
        .MacOS => macos_init_app(),
        else => unsupported_platform(),
    }
}

pub fn pollEvents() bool {
    const platform: Platform = get_platform() catch unsupported_platform();

    return switch (platform) {
        .MacOS => macos_poll_events(),
        else => unsupported_platform(),
    };
}

pub fn present() void {
    const platform: Platform = get_platform() catch unsupported_platform();

    switch (platform) {
        .MacOS => macos_present_frame(),
        else => unsupported_platform(),
    }
}
