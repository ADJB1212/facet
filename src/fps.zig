const FPS_SAMPLE_COUNT = 60;
const std = @import("std");
const render = @import("canvas.zig");
const Canvas = render.Canvas;
const Color = render.colors.Color;

pub const FpsManager = struct {
    frame_times: [FPS_SAMPLE_COUNT]i128 = [_]i128{0} ** FPS_SAMPLE_COUNT,
    index: usize = 0,
    count: usize = 0,
    total_time: i128 = 0,

    last_time: i128 = 0,
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

    pub fn drawFPS(self: *FpsManager, c: *Canvas, x: i32, y: i32, color: Color) void {
        const now = std.time.nanoTimestamp();

        if (!self.initialized) {
            self.last_time = now;
            if (!self.timing_initialized) {
                self.frame_start_time = now;
                self.timing_initialized = true;
            }
            self.initialized = true;
            render.drawText(c, "FPS: --", x, y, 1, color, .left);
            return;
        }

        const frame_time = now - self.last_time;
        self.last_time = now;

        if (self.count < FPS_SAMPLE_COUNT) {
            self.count += 1;
        } else {
            self.total_time -= self.frame_times[self.index];
        }

        self.frame_times[self.index] = frame_time;
        self.total_time += frame_time;
        self.index = (self.index + 1) % FPS_SAMPLE_COUNT;

        const avg_frame_time = @as(f64, @floatFromInt(self.total_time)) / @as(f64, @floatFromInt(self.count));

        const fps = @as(f64, std.time.ns_per_s) / avg_frame_time;

        var buf: [64]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "FPS: {d:.1}", .{fps}) catch "FPS: ERR";

        render.drawText(c, text, x, y, 1, color, .left);
    }
};
