const std = @import("std");

pub const Color = u32;

pub const RED = 0xFFFF0000;
pub const GREEN = 0xFF00FF00;
pub const BLUE = 0xFF0000FF;
pub const BLACK = 0xFF000000;
pub const WHITE = BLUE | GREEN | RED;
pub const YELLOW = RED | GREEN;
pub const CYAN = GREEN | BLUE;
pub const MAGENTA = RED | BLUE;

inline fn red(c: Color) u8 {
    return @intCast(c & 0xFF);
}
inline fn green(c: Color) u8 {
    return @intCast((c >> 8) & 0xFF);
}
inline fn blue(c: Color) u8 {
    return @intCast((c >> 16) & 0xFF);
}
inline fn alpha(c: Color) u8 {
    return @intCast((c >> 24) & 0xFF);
}

pub inline fn rgba(rr: u8, gg: u8, bb: u8, aa: u8) Color {
    return @as(u32, rr) | (@as(u32, gg) << 8) | (@as(u32, bb) << 16) | (@as(u32, aa) << 24);
}

inline fn blend8(dst: u8, src: u8, src_a: u8) u8 {
    const da: u16 = 255 - src_a;
    const out: u16 = @as(u16, dst) * da + @as(u16, src) * @as(u16, src_a);
    // branchless version of dividing by 255
    const tmp: u32 = (@as(u32, out) + 128) * 257;
    return @intCast(tmp >> 16);
}

pub fn blendColor(dst: *u32, src: u32) void {
    const sa: u8 = alpha(src);
    if (sa == 0) return;
    if (sa == 255) {
        dst.* = src;
        return;
    }

    const d = dst.*;
    const rr = blend8(red(d), red(src), sa);
    const gg = blend8(green(d), green(src), sa);
    const bb = blend8(blue(d), blue(src), sa);

    dst.* = rgba(rr, gg, bb, alpha(d));
}

inline fn lerp8(a: u8, b: u8, t: u8) u8 {
    const da: u16 = @as(u16, 255 - t);
    const out: u16 = @as(u16, a) * da + @as(u16, b) * @as(u16, t);

    const tmp: u32 = (@as(u32, out) + 128) * 257;
    return @intCast(tmp >> 16);
}

pub fn colorLerp(a: Color, b: Color, t: f32) Color {
    const t_i: u8 = @intFromFloat(@round(std.math.clamp(t, 0.0, 1.0) * 255.0));
    const rr = lerp8(red(a), red(b), t_i);
    const gg = lerp8(green(a), green(b), t_i);
    const bb = lerp8(blue(a), blue(b), t_i);
    const aa = lerp8(alpha(a), alpha(b), t_i);

    return rgba(rr, gg, bb, aa);
}
