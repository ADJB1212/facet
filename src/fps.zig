const std = @import("std");

pub const FpsManager = struct {
    frame_start_time: i128 = 0,
    target_fps: f64 = 60.0,
    initialized: bool = false,
    timing_initialized: bool = false,

    pub fn setTargetFPS(self: *FpsManager, target: f64) void {
        self.target_fps = target;
    }

    pub fn waitForNextFrame(self: *FpsManager) void {
        const now = std.time.nanoTimestamp();
        if (!self.timing_initialized) {
            self.frame_start_time = now;
            self.timing_initialized = true;
            return;
        }

        const target_ns = @as(i64, @intFromFloat(@as(f64, std.time.ns_per_s) / self.target_fps));
        const elapsed = now - self.frame_start_time;

        if (elapsed < target_ns) std.Thread.sleep(@intCast(target_ns - elapsed));

        self.frame_start_time = std.time.nanoTimestamp();
    }
};
