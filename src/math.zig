const std = @import("std");

pub inline fn vectorLerp(v1: @Vector(2, i32), v2: @Vector(2, i32), t: f32) @Vector(2, i32) {
    const Vf = @Vector(2, f32);
    const a: Vf = @floatFromInt(v1);
    const b: Vf = @floatFromInt(v2);

    const r: Vf = a + (b - a) * @as(Vf, @splat(t));

    return @intFromFloat(r);
}

pub fn dot(a: Vec3, b: Vec3) f32 {
    const p = a * b;
    return p[0] + p[1] + p[2];
}

pub fn cross(a: Vec3, b: Vec3) Vec3 {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

pub fn normalize(v: Vec3) Vec3 {
    const len = @sqrt(dot(v, v));
    if (len < 1e-6) return v;
    return v / @as(Vec3, @splat(len));
}