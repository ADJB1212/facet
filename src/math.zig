const std = @import("std");

pub inline fn vectorLerp(v1: @Vector(2, i32), v2: @Vector(2, i32), t: f32) @Vector(2, i32) {
    const Vf = @Vector(2, f32);
    const a: Vf = @floatFromInt(v1);
    const b: Vf = @floatFromInt(v2);

    const r: Vf = a + (b - a) * @as(Vf, @splat(t));

    return @intFromFloat(r);
}
