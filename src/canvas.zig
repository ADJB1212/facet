const std = @import("std");
pub const colors = @import("color.zig");
const math = @import("math.zig");
pub const FpsManager = @import("fps.zig").FpsManager;
const font8 = @import("default_font.zig").font8x8;

var canvas: Canvas = undefined;
const Color = colors.Color;
const min_rows_per_worker: usize = 64;

const RowRange = struct {
    start: usize,
    end: usize,
};

fn workerCountForRows(rows: usize) usize {
    if (rows == 0) return 1;
    const cpu_count = std.Thread.getCpuCount() catch 1;
    if (cpu_count <= 1) return 1;

    const max_by_rows = (rows + min_rows_per_worker - 1) / min_rows_per_worker;
    var count = @min(cpu_count, max_by_rows);
    if (count < 1) count = 1;
    if (count > rows) count = rows;
    return count;
}

fn rowRange(total_rows: usize, worker_index: usize, worker_count: usize) RowRange {
    const base = total_rows / worker_count;
    const extra = total_rows % worker_count;
    const start = worker_index * base + @min(worker_index, extra);
    const len: usize = base + @as(usize, if (worker_index < extra) 1 else 0);
    return .{ .start = start, .end = start + len };
}

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

fn inRenderArea(c: *Canvas, x: i32, y: i32) bool {
    return 0 <= x and x < c.width and 0 <= y and y < c.height;
}

const FillWork = struct {
    c: *Canvas,
    start_y: usize,
    end_y: usize,
    color: Color,
};

fn fillCanvasWorker(work: *FillWork) void {
    var y: usize = work.start_y;
    while (y < work.end_y) : (y += 1) {
        const row = work.c.pixels[y * work.c.stride .. y * work.c.stride + work.c.width];
        @memset(row, work.color);
    }
}

fn fillCanvasSingle(c: *Canvas, color: Color) void {
    var work = FillWork{
        .c = c,
        .start_y = 0,
        .end_y = c.height,
        .color = color,
    };
    fillCanvasWorker(&work);
}

pub fn fillCanvas(c: *Canvas, color: Color) void {
    const worker_count = workerCountForRows(c.height);
    if (worker_count <= 1) {
        fillCanvasSingle(c, color);
        return;
    }

    var works = c.allocator.alloc(FillWork, worker_count) catch {
        fillCanvasSingle(c, color);
        return;
    };
    defer c.allocator.free(works);

    var threads = c.allocator.alloc(std.Thread, worker_count - 1) catch {
        fillCanvasSingle(c, color);
        return;
    };
    defer c.allocator.free(threads);

    var i: usize = 0;
    while (i < worker_count) : (i += 1) {
        const range = rowRange(c.height, i, worker_count);
        works[i] = .{
            .c = c,
            .start_y = range.start,
            .end_y = range.end,
            .color = color,
        };
    }

    var threads_started: usize = 0;
    i = 1;
    while (i < worker_count) : (i += 1) {
        threads[threads_started] = std.Thread.spawn(.{}, fillCanvasWorker, .{&works[i]}) catch {
            fillCanvasWorker(&works[i]);
            continue;
        };
        threads_started += 1;
    }

    fillCanvasWorker(&works[0]);

    i = 0;
    while (i < threads_started) : (i += 1) {
        threads[i].join();
    }
}

pub fn setPixel(c: *Canvas, x: i32, y: i32, color: Color) void {
    colors.blendColor(getPixelPtr(c, @as(usize, @intCast(x)), @as(usize, @intCast(y))), color);
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

    const start_x: usize = @intCast(rect.v[0]);
    const end_x: usize = @intCast(rect.v[2]);
    const start_y: usize = @intCast(rect.v[1]);
    const end_y: usize = @intCast(rect.v[3]);
    const width = end_x - start_x + 1;

    const sa = colors.alpha(color);
    if (sa == 0) return;

    var cur_y = start_y;
    while (cur_y <= end_y) : (cur_y += 1) {
        const row_start = cur_y * c.stride + start_x;
        const row_slice = c.pixels[row_start .. row_start + width];

        if (sa == 255) {
            @memset(row_slice, color);
        } else {
            for (row_slice) |*p| {
                colors.blendColor(p, color);
            }
        }
    }
}

fn normalize_triangle(width: usize, height: usize, x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, lx: *i32, hx: *i32, ly: *i32, hy: *i32) bool {
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

pub fn drawTriangle(c: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, color: Color) void {
    var lx: i32 = undefined;
    var hx: i32 = undefined;
    var ly: i32 = undefined;
    var hy: i32 = undefined;

    if (!normalize_triangle(c.width, c.height, x1, y1, x2, y2, x3, y3, &lx, &hx, &ly, &hy)) return;

    const det = (x1 - x3) * (y2 - y3) - (x2 - x3) * (y1 - y3);
    const sign_det = sign(i32, det);

    const du1_dx = y2 - y3;
    const du1_dy = x3 - x2;
    const du2_dx = y3 - y1;
    const du2_dy = x1 - x3;

    var row_u1 = du1_dx * (lx - x3) + du1_dy * (ly - y3);
    var row_u2 = du2_dx * (lx - x3) + du2_dy * (ly - y3);

    var y = ly;
    while (y <= hy) : (y += 1) {
        var cur_u1 = row_u1;
        var cur_u2 = row_u2;
        const row_start = @as(usize, @intCast(y)) * c.stride;
        const row_pixels = c.pixels[row_start..];

        var x = lx;
        while (x <= hx) : (x += 1) {
            const cur_u3 = det - cur_u1 - cur_u2;

            if (((sign(i32, cur_u1) == sign_det) or cur_u1 == 0) and
                ((sign(i32, cur_u2) == sign_det) or cur_u2 == 0) and
                ((sign(i32, cur_u3) == sign_det) or cur_u3 == 0))
            {
                colors.blendColor(&row_pixels[@intCast(x)], color);
            }

            cur_u1 += du1_dx;
            cur_u2 += du2_dx;
        }
        row_u1 += du1_dy;
        row_u2 += du2_dy;
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

            const count_scaled = if (aa_i > 0) count / aa_i / aa_i else count;
            const a = colors.alpha(color) * count_scaled;
            const t: Color = @intCast((color & 0x00FFFFFF) | (a << (24)));
            colors.blendColor(getPixelPtr(c, xr, yr), t);
        }
    }
}

pub fn drawLine(c: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, thickness: u32, color: Color) void {
    var x1_mut = x1;
    var x2_mut = x2;
    var y1_mut = y1;
    var y2_mut = y2;
    const dx = x2_mut - x1_mut;
    const dy = y2_mut - y1_mut;
    const t_offset = @as(i32, @intCast(thickness >> 1));

    if (dx == 0 and dy == 0) {
        if (thickness <= 1) {
            if (inRenderArea(c, x1_mut, y1_mut)) {
                colors.blendColor(getPixelPtr(c, @intCast(x1_mut), @intCast(y1_mut)), color);
            }
        } else drawRect(c, x1_mut - t_offset, y1_mut - t_offset, thickness, thickness, color);
        return;
    }
    if (abs(i32, dx) > abs(i32, dy)) {
        if (x1_mut > x2_mut) {
            swap(i32, &x1_mut, &x2_mut);
            swap(i32, &y1_mut, &y2_mut);
        }

        const x_start = @max(0, x1_mut);
        const x_end = @min(@as(i32, @intCast(c.width)) - 1, x2_mut);

        if (x_start <= x_end) {
            for (@intCast(x_start)..@intCast(x_end + 1)) |x| {
                const x_i: i32 = @intCast(x);
                const y: i32 = y1_mut + @as(i32, @intCast(@divTrunc(@as(i64, dy) * (x_i - x1_mut), dx)));
                if (thickness <= 1) {
                    if (inRenderArea(c, x_i, y)) {
                        colors.blendColor(getPixelPtr(c, x, @intCast(y)), color);
                    }
                } else {
                    var sy = y - t_offset;
                    const ey = sy + @as(i32, @intCast(thickness));
                    while (sy < ey) : (sy += 1) {
                        if (inRenderArea(c, x_i, sy)) {
                            colors.blendColor(getPixelPtr(c, x, @intCast(sy)), color);
                        }
                    }
                }
            }
        }
    } else {
        if (y1_mut > y2_mut) {
            swap(i32, &x1_mut, &x2_mut);
            swap(i32, &y1_mut, &y2_mut);
        }

        const y_start = @max(0, y1_mut);
        const y_end = @min(@as(i32, @intCast(c.height)) - 1, y2_mut);

        if (y_start <= y_end) {
            for (@intCast(y_start)..@intCast(y_end + 1)) |y| {
                const y_i: i32 = @intCast(y);
                const x: i32 = x1_mut + @as(i32, @intCast(@divTrunc(@as(i64, dx) * (y_i - y1_mut), dy)));
                if (thickness <= 1) {
                    if (inRenderArea(c, x, y_i)) {
                        colors.blendColor(getPixelPtr(c, @intCast(x), y), color);
                    }
                } else {
                    var sx = x - t_offset;
                    const ex = sx + @as(i32, @intCast(thickness));
                    while (sx < ex) : (sx += 1) {
                        if (inRenderArea(c, sx, y_i)) {
                            colors.blendColor(getPixelPtr(c, @intCast(sx), y), color);
                        }
                    }
                }
            }
        }
    }
}

pub fn drawVerticalLine(c: *Canvas, x: i32, y0: i32, y1: i32, thickness: u32, color: Color) void {
    drawLine(c, x, y0, x, y1, thickness, color);
}

pub fn drawHorizontalLine(c: *Canvas, y: i32, x0: i32, x1: i32, thickness: u32, color: Color) void {
    drawLine(c, x0, y, x1, y, thickness, color);
}

fn bezierInterpolation(v1: @Vector(2, i32), v2: @Vector(2, i32), v3: @Vector(2, i32), t: f32) @Vector(2, i32) {
    const intermediate_1: @Vector(2, i32) = math.vectorLerp(v1, v2, t);
    const intermediate_2: @Vector(2, i32) = math.vectorLerp(v2, v3, t);
    return math.vectorLerp(intermediate_1, intermediate_2, t);
}

pub fn drawBezier(c: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, thickness: u32, color: Color) void {
    const v1: @Vector(2, i32) = .{ x1, y1 };
    const v2: @Vector(2, i32) = .{ x2, y2 };
    const v3: @Vector(2, i32) = .{ x3, y3 };
    const res: u8 = 20;
    var prev_point: @Vector(2, i32) = v1;

    for (0..res) |i| {
        const t: f32 = (@as(f32, @floatFromInt(i)) + 1.0) / res;
        const next_point: @Vector(2, i32) = bezierInterpolation(v1, v2, v3, t);
        drawLine(c, prev_point[0], prev_point[1], next_point[0], next_point[1], thickness, color);
        prev_point = next_point;
    }
}

pub const TextAlign = enum {
    left,
    center,
    right,
};

pub fn drawChar(c: *Canvas, ch: u8, x: i32, y: i32, size: i32, color: Color) void {
    if (ch < 32 or ch > 126 or size <= 0) return;

    const glyph = font8[ch - 32];

    if (size == 1) {
        for (0..8) |py| {
            const row = glyph[7 - py];
            for (0..8) |px| {
                if (((row >> @as(u3, @intCast(px))) & 1) != 0) {
                    const dx = x + @as(i32, @intCast(px));
                    const dy = y + @as(i32, @intCast(py));
                    if (inRenderArea(c, dx, dy)) {
                        colors.blendColor(getPixelPtr(c, @intCast(dx), @intCast(dy)), color);
                    }
                }
            }
        }
    } else {
        const u_size: u32 = @intCast(size);
        for (0..8) |py| {
            const row = glyph[7 - py];
            for (0..8) |px| {
                if (((row >> @as(u3, @intCast(px))) & 1) != 0) {
                    const base_x = x + @as(i32, @intCast(px)) * size;
                    const base_y = y + @as(i32, @intCast(py)) * size;
                    drawRect(c, base_x, base_y, u_size, u_size, color);
                }
            }
        }
    }
}

fn measureTextWidth(text: []const u8, size: i32) i32 {
    if (size <= 0) return 0;
    const len: i32 = @intCast(text.len);
    return len * 8 * size;
}

pub fn drawText(c: *Canvas, text: []const u8, x: i32, y: i32, size: i32, color: Color, text_align: TextAlign) void {
    if (size <= 0) return;
    const width = measureTextWidth(text, size);
    var cx = switch (text_align) {
        .left => x,
        .center => x - @divTrunc(width, 2),
        .right => x - width,
    };

    for (text) |ch| {
        drawChar(c, ch, cx, y, size, color);
        cx += 8 * size;
    }
}
