const std = @import("std");
const builtin = @import("builtin");

const Platform = enum { MacOS, Linux_X11, Linux_Wayland, Windows };

const WindowError = error{UnsupportedPlatform};

extern fn macos_init_app() void;
extern fn macos_poll_events() bool;
extern fn macos_present_frame() void;

extern fn linux_x11_init_app() void;
extern fn linux_x11_poll_events() bool;
extern fn linux_x11_present_frame() void;

extern fn linux_wayland_init_app() void;
extern fn linux_wayland_poll_events() bool;
extern fn linux_wayland_present_frame() void;

extern fn windows_init_app() void;
extern fn windows_poll_events() bool;
extern fn windows_present_frame() void;

pub fn detect_linux_display() enum { X11, Wayland, Unknown } {
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

pub fn unsupported_platform() noreturn {
    std.debug.print("This platform is not supported yet!\n", .{});
    std.process.exit(1);
}

pub fn init() void {
    switch (builtin.os.tag) {
        .macos => macos_init_app(),
        .linux => switch (detect_linux_display()) {
            .X11 => linux_x11_init_app(),
            .Wayland => linux_wayland_init_app(),
            else => unsupported_platform(),
        },
        .windows => windows_init_app(),
        else => unsupported_platform(),
    }
}

pub fn pollEvents() bool {
    return switch (builtin.os.tag) {
        .macos => macos_poll_events(),
        .linux => switch (detect_linux_display()) {
            .X11 => linux_x11_poll_events(),
            .Wayland => linux_wayland_poll_events(),
            else => unsupported_platform(),
        },
        .windows => windows_poll_events(),
        else => unsupported_platform(),
    };
}

pub fn present() void {
    switch (builtin.os.tag) {
        .macos => macos_present_frame(),
        .linux => switch (detect_linux_display()) {
            .X11 => linux_x11_present_frame(),
            .Wayland => linux_wayland_present_frame(),
            else => unsupported_platform(),
        },
        .windows => windows_present_frame(),
        else => unsupported_platform(),
    }
}
