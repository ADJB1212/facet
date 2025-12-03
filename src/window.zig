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

pub fn isKeyDown(key: Key) bool {
    const platform: Platform = get_platform() catch unsupported_platform();

    return switch (platform) {
        .MacOS => macos_is_key_down(keys.macos_keycode(key)),
        else => unsupported_platform(),
    };
}

pub fn isMouseDown(button: MouseButton) bool {
    const platform: Platform = get_platform() catch unsupported_platform();

    return switch (platform) {
        .MacOS => macos_is_mouse_down(@intFromEnum(button)),
        else => unsupported_platform(),
    };
}

pub fn getLastClickPosition() MousePosition {
    const platform: Platform = get_platform() catch unsupported_platform();

    return switch (platform) {
        .MacOS => blk: {
            var pos: MousePosition = .{ .x = 0, .y = 0 };
            macos_get_last_click_position(&pos.x, &pos.y);
            break :blk pos;
        },
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
