const std = @import("std");
const builtin = @import("builtin");
const window = @import("window");

extern fn macos_is_mouse_down(button: u8) bool;
extern fn macos_get_last_click_position(x: *f32, y: *f32) void;
extern fn macos_get_mouse_position(x: *f32, y: *f32) void;

extern fn linux_wayland_is_mouse_down(button: u8) bool;
extern fn linux_wayland_get_last_click_position(x: *f32, y: *f32) void;
extern fn linux_wayland_get_mouse_position(x: *f32, y: *f32) void;

extern fn linux_x11_is_mouse_down(button: u8) bool;
extern fn linux_x11_get_last_click_position(x: *f32, y: *f32) void;
extern fn linux_x11_get_mouse_position(x: *f32, y: *f32) void;

extern fn windows_is_mouse_down(button: u8) bool;
extern fn windows_get_last_click_position(x: *f32, y: *f32) void;
extern fn windows_get_mouse_position(x: *f32, y: *f32) void;

pub const MouseButton = enum(u8) { Left = 0, Right = 1, Middle = 2 };
pub const MousePosition = struct {
    x: f32,
    y: f32,
};

pub fn isMouseDown(button: MouseButton) bool {
    return switch (builtin.os.tag) {
        .macos => macos_is_mouse_down(@intFromEnum(button)),
        .linux => switch (window.detect_linux_display()) {
            .X11 => linux_x11_is_mouse_down(@intFromEnum(button)),
            .Wayland => linux_wayland_is_mouse_down(@intFromEnum(button)),
            else => window.unsupported_platform(),
        },
        .windows => windows_is_mouse_down(@intFromEnum(button)),
        else => window.unsupported_platform(),
    };
}

pub fn getLastClickPosition() MousePosition {
    return switch (builtin.os.tag) {
        .macos => blk: {
            var pos: MousePosition = .{ .x = 0, .y = 0 };
            macos_get_last_click_position(&pos.x, &pos.y);
            break :blk pos;
        },
        .linux => switch (window.detect_linux_display()) {
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
            else => window.unsupported_platform(),
        },
        .windows => blk: {
            var pos: MousePosition = .{ .x = 0, .y = 0 };
            windows_get_last_click_position(&pos.x, &pos.y);
            break :blk pos;
        },
        else => window.unsupported_platform(),
    };
}

pub fn getMousePosition() MousePosition {
    return switch (builtin.os.tag) {
        .macos => blk: {
            var pos: MousePosition = .{ .x = 0, .y = 0 };
            macos_get_mouse_position(&pos.x, &pos.y);
            break :blk pos;
        },
        .linux => switch (window.detect_linux_display()) {
            .X11 => blk: {
                var pos: MousePosition = .{ .x = 0, .y = 0 };
                linux_x11_get_mouse_position(&pos.x, &pos.y);
                break :blk pos;
            },
            .Wayland => blk: {
                var pos: MousePosition = .{ .x = 0, .y = 0 };
                linux_wayland_get_mouse_position(&pos.x, &pos.y);
                break :blk pos;
            },
            else => window.unsupported_platform(),
        },
        .windows => blk: {
            var pos: MousePosition = .{ .x = 0, .y = 0 };
            windows_get_mouse_position(&pos.x, &pos.y);
            break :blk pos;
        },
        else => window.unsupported_platform(),
    };
}
