const std = @import("std");
const builtin = @import("builtin");
const keys = @import("keycodes.zig");
const window = @import("window");

const Key = keys.Key;

extern fn macos_is_key_down(key_code: u16) bool;

extern fn linux_wayland_is_key_down(key_code: u16) bool;

extern fn linux_x11_is_key_down(key_code: u16) bool;

extern fn windows_is_key_down(key_code: u16) bool;

pub fn isKeyDown(key: Key) bool {
    return switch (builtin.os.tag) {
        .macos => macos_is_key_down(keys.macos_keycode(key)),
        .linux => switch (window.detect_linux_display()) {
            .X11 => linux_x11_is_key_down(keys.linux_keycode(key)),
            .Wayland => linux_wayland_is_key_down(keys.linux_keycode(key)),
            else => window.unsupported_platform(),
        },
        .windows => windows_is_key_down(keys.windows_keycode(key)),
        else => window.unsupported_platform(),
    };
}
