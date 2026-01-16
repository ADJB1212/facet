const std = @import("std");
const builtin = @import("builtin");
const keys = @import("platform/keycodes.zig");

const Platform = enum { MacOS, Linux_X11, Linux_Wayland, Windows };

const WindowError = error{UnsupportedPlatform};

const Key = keys.Key;
pub const MouseButton = enum(u8) { Left = 0, Right = 1, Middle = 2 };
pub const MousePosition = struct {
    x: f32,
    y: f32,
};

extern fn macos_init_app() void;
extern fn macos_poll_events() bool;
extern fn macos_present_frame() void;
extern fn macos_is_key_down(key_code: u16) bool;
extern fn macos_is_mouse_down(button: u8) bool;
extern fn macos_get_last_click_position(x: *f32, y: *f32) void;

extern fn linux_x11_init_app() void;
extern fn linux_x11_poll_events() bool;
extern fn linux_x11_present_frame() void;
extern fn linux_x11_is_key_down(key_code: u16) bool;
extern fn linux_x11_is_mouse_down(button: u8) bool;
extern fn linux_x11_get_last_click_position(x: *f32, y: *f32) void;

extern fn linux_wayland_init_app() void;
extern fn linux_wayland_poll_events() bool;
extern fn linux_wayland_present_frame() void;
extern fn linux_wayland_is_key_down(key_code: u16) bool;
extern fn linux_wayland_is_mouse_down(button: u8) bool;
extern fn linux_wayland_get_last_click_position(x: *f32, y: *f32) void;

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
    switch (builtin.os.tag) {
        .macos => macos_init_app(),
        .linux => switch (detect_linux_display()) {
            .X11 => linux_x11_init_app(),
            .Wayland => linux_wayland_init_app(),
            else => unsupported_platform(),
        },
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
        else => unsupported_platform(),
    };
}

pub fn isKeyDown(key: Key) bool {
    return switch (builtin.os.tag) {
        .macos => macos_is_key_down(keys.macos_keycode(key)),
        .linux => switch (detect_linux_display()) {
            .X11 => linux_x11_is_key_down(keys.linux_keycode(key)),
            .Wayland => linux_wayland_is_key_down(keys.linux_keycode(key)),
            else => unsupported_platform(),
        },
        else => unsupported_platform(),
    };
}

pub fn isMouseDown(button: MouseButton) bool {
    return switch (builtin.os.tag) {
        .macos => macos_is_mouse_down(@intFromEnum(button)),
        .linux => switch (detect_linux_display()) {
            .X11 => linux_x11_is_mouse_down(@intFromEnum(button)),
            .Wayland => linux_wayland_is_mouse_down(@intFromEnum(button)),
            else => unsupported_platform(),
        },
        else => unsupported_platform(),
    };
}

pub fn getLastClickPosition() MousePosition {
    return switch (builtin.os.tag) {
        .macos => blk: {
            var pos: MousePosition = .{ .x = 0, .y = 0 };
            macos_get_last_click_position(&pos.x, &pos.y);
            break :blk pos;
        },
        .linux => switch (detect_linux_display()) {
            .X11 => blk: {
                var pos: MousePosition = .{ .x = 0, .y = 0 };
                linux_x11_get_last_click_position(&pos.x, &pos.y);
                break :blk pos;
            },
            .Wayland => blk: {
                var pos: MousePosition = .{ .x = 0, .y = 0 };
                linux_wayland_get_last_click_position(&pos.x, &pos.y);
                break :blk pos;
            },
            else => unsupported_platform(),
        },
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
        else => unsupported_platform(),
    }
}
