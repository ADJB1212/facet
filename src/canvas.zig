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

inline fn abs(comptime T: type, v: T) T {
    return if (v < 0) -v else v;
}

inline fn swap(comptime T: type, item_a: *T, item_b: *T) void {
    const tmp = item_a.*;
    item_a.* = item_b.*;
    item_b.* = tmp;
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

pub fn normalize_triangle(width: usize, height: usize, x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, lx: *i32, hx: *i32, ly: *i32, hy: *i32) bool {
    lx.* = x1;
    hx.* = x1;

    if (lx.* > x2) lx.* = x2;
    if (lx.* > x3) lx.* = x3;
    if (hx.* < x2) hx.* = x2;
    if (hx.* < x3) hx.* = x3;

    if (lx.* < 0) lx.* = 0;
    if (@as(usize, @intCast(lx.*)) >= width) return false;
    if (hx.* < 0) return false;
    if (@as(usize, @intCast(hx.*)) >= width) hx.* = @as(i32, @intCast(width - 1));

    ly.* = y1;
    hy.* = y1;

    if (ly.* > y2) ly.* = y2;
    if (ly.* > y3) ly.* = y3;
    if (hy.* < y2) hy.* = y2;
    if (hy.* < y3) hy.* = y3;

    if (ly.* < 0) ly.* = 0;
    if (@as(usize, @intCast(ly.*)) >= height) return false;
    if (hy.* < 0) return false;
    if (@as(usize, @intCast(hy.*)) >= height) hy.* = @as(i32, @intCast(height - 1));

    return true;
}

fn isPointInTriangle(x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, xp: i32, yp: i32, u_1: *i32, u_2: *i32, det: *i32) bool {
    det.* = (x1 - x3) * (y2 - y3) - (x2 - x3) * (y1 - y3);

    u_1.* = (y2 - y3) * (xp - x3) + (x3 - x2) * (yp - y3);
    u_2.* = (y3 - y1) * (xp - x3) + (x1 - x3) * (yp - y3);

    const u_3: i32 = det.* - u_1.* - u_2.*;

    return ((sign(i32, u_1.*) == sign(i32, det.*) or u_1.* == 0) and
        (sign(i32, u_2.*) == sign(i32, det.*) or u_2.* == 0) and
        (sign(i32, u_3) == sign(i32, det.*) or u_3 == 0));
}

pub fn drawTriangle(c: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, color: Color) void {
    var lx: i32 = undefined;
    var hx: i32 = undefined;
    var ly: i32 = undefined;
    var hy: i32 = undefined;

    if (normalize_triangle(c.width, c.height, x1, y1, x2, y2, x3, y3, &lx, &hx, &ly, &hy)) {
        var y: i32 = ly;
        while (y <= hy) : (y += 1) {
            var x: i32 = lx;
            while (x <= hx) : (x += 1) {
                var u_1: i32 = undefined;
                var u_2: i32 = undefined;
                var det: i32 = undefined;

                if (isPointInTriangle(x1, y1, x2, y2, x3, y3, x, y, &u_1, &u_2, &det)) {
                    colors.blendColor(getPixelPtr(c, @intCast(x), @intCast(y)), color);
                }
            }
        }
    }
}

// aa parameter is for anti-aliasing
pub fn drawCircle(c: *Canvas, x: i32, y: i32, r: i32, aa: i32, color: Color) void {
    var rect: Rect = undefined;
    const r_s = r + sign(@TypeOf(r), r);
    if (!normalize_rect(x - r_s, y - r_s, 2 * r_s, 2 * r_s, c.width, c.height, &rect)) return;

    const res: i32 = aa + 1;
    const aa_i: usize = @intCast(aa);

    for (@intCast(rect.v[0])..@intCast(rect.v[2] + 1)) |xr| {
        for (@intCast(rect.v[1])..@intCast(rect.v[3] + 1)) |yr| {
            var count: usize = 0;
            const xr_i: i32 = @intCast(xr);
            const yr_i: i32 = @intCast(yr);
            for (@intCast(0)..@intCast(aa)) |xr2| {
                for (@intCast(0)..@intCast(aa)) |yr2| {
                    const xr2_i: i32 = @intCast(xr2);
                    const yr2_i: i32 = @intCast(yr2);
                    const dx = xr_i * res * 2 + 2 + xr2_i * 2 - res * x * 2 - res;
                    const dy = yr_i * res * 2 + 2 + yr2_i * 2 - res * y * 2 - res;
                    if (dx * dx + dy * dy <= res * res * r * r * 4) count += 1;
                }
            }

            const a = colors.alpha(color) * count / aa_i / aa_i;
            const t: Color = @intCast((color & 0x00FFFFFF) | (a << (24)));
            colors.blendColor(getPixelPtr(c, xr, yr), t);
        }
    }
}
