const std = @import("std");
pub const colors = @import("color.zig");

var canvas: Canvas = undefined;
const Color = colors.Color;

pub const Canvas = struct {
    pixels: []u32,
    width: usize,
    height: usize,
    stride: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Canvas {
        const pixels = try allocator.alloc(u32, width * height);
        return Canvas{
            .pixels = pixels,
            .width = width,
            .height = height,
            .stride = width,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Canvas) void {
        self.allocator.free(self.pixels);
    }
};

pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !void {
    canvas = try Canvas.init(allocator, width, height);
}

pub fn deinit() void {
    canvas.deinit();
}

pub fn getCanvas() *Canvas {
    return &canvas;
}

export fn zig_get_canvas_pixels() [*]const u32 {
    return canvas.pixels.ptr;
}

export fn zig_get_canvas_width() usize {
    return canvas.width;
}

export fn zig_get_canvas_height() usize {
    return canvas.height;
}

export fn zig_get_canvas_stride() usize {
    return canvas.stride;
}

fn getPixelPtr(c: *Canvas, x: usize, y: usize) *u32 {
    return &c.pixels[y * c.stride + x];
}

pub fn fillCanvas(c: *Canvas, color: Color) void {
    var y: usize = 0;
    while (y < c.height) : (y += 1) {
        const row = c.pixels[y * c.stride .. y * c.stride + c.width];
        @memset(row, color);
    }
}

pub const Rect = struct {
    o: @Vector(4, i32),
    v: @Vector(4, i32),
};

inline fn sign(comptime T: type, v: T) T {
    return if (v < 0) -1 else 1;
}

fn normalize_rect(x: i32, y: i32, w: i32, h: i32, c_w: usize, c_h: usize, rect: *Rect) bool {
    if (w == 0 or h == 0) return false;

    const start = @Vector(4, i32){ x, y, x, y };
    const dims = @Vector(4, i32){ 0, 0, w - sign(i32, w), h - sign(i32, h) };
    const raw = start + dims;

    const swapped = @shuffle(i32, raw, raw, @Vector(4, i32){ 2, 3, 0, 1 });

    const mins = @min(raw, swapped);
    const maxs = @max(raw, swapped);

    rect.o = @Vector(4, i32){ mins[0], mins[1], maxs[2], maxs[3] };

    const cw = @as(i32, @intCast(c_w));
    const ch = @as(i32, @intCast(c_h));

    if (rect.o[0] >= cw or rect.o[2] < 0) return false;
    if (rect.o[1] >= ch or rect.o[3] < 0) return false;

    const bounds_min = @Vector(4, i32){ 0, 0, 0, 0 };
    const bounds_max = @Vector(4, i32){ cw - 1, ch - 1, cw - 1, ch - 1 };

    rect.v = @max(bounds_min, @min(bounds_max, rect.o));

    return true;
}

pub fn drawRect(c: *Canvas, x: i32, y: i32, w: u32, h: u32, color: Color) void {
    var rect: Rect = undefined;
    if (!normalize_rect(x, y, @intCast(w), @intCast(h), c.width, c.height, &rect)) return;
    for (@intCast(rect.v[0])..@intCast(rect.v[2] + 1)) |xr| {
        for (@intCast(rect.v[1])..@intCast(rect.v[3] + 1)) |yr| {
            colors.blendColor(getPixelPtr(c, xr, yr), color);
        }
    }
}
