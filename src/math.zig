const std = @import("std");

pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);

pub const Mat4 = struct {
    data: [4]Vec4,

    pub fn identity() Mat4 {
        return .{
            .data = .{
                .{ 1, 0, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var res: Mat4 = undefined;
        inline for (0..4) |row| {
            var acc: Vec4 = @splat(0);
            inline for (0..4) |k| {
                const scalar = a.data[row][k];
                acc += @as(Vec4, @splat(scalar)) * b.data[k];
            }
            res.data[row] = acc;
        }
        return res;
    }

    pub fn mulVec(m: Mat4, v: Vec4) Vec4 {
        var res: Vec4 = undefined;
        inline for (0..4) |row| {
            res[row] = @reduce(.Add, m.data[row] * v);
        }
        return res;
    }

    pub fn translate(v: Vec3) Mat4 {
        var m = Mat4.identity();
        m.data[0][3] = v[0];
        m.data[1][3] = v[1];
        m.data[2][3] = v[2];
        return m;
    }

    pub fn scale(v: Vec3) Mat4 {
        var m = Mat4.identity();
        m.data[0][0] = v[0];
        m.data[1][1] = v[1];
        m.data[2][2] = v[2];
        return m;
    }

    pub fn rotateX(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        var m = Mat4.identity();
        m.data[1][1] = c;
        m.data[1][2] = -s;
        m.data[2][1] = s;
        m.data[2][2] = c;
        return m;
    }

    pub fn rotateY(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        var m = Mat4.identity();
        m.data[0][0] = c;
        m.data[0][2] = s;
        m.data[2][0] = -s;
        m.data[2][2] = c;
        return m;
    }

    pub fn rotateZ(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        var m = Mat4.identity();
        m.data[0][0] = c;
        m.data[0][1] = -s;
        m.data[1][0] = s;
        m.data[1][1] = c;
        return m;
    }

    pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const tan_half_fov = @tan(fov / 2.0);
        var m = Mat4{ .data = .{ @splat(0), @splat(0), @splat(0), @splat(0) } };

        m.data[0][0] = 1.0 / (aspect * tan_half_fov);
        m.data[1][1] = 1.0 / tan_half_fov;
        m.data[2][2] = -(far + near) / (far - near);
        m.data[2][3] = -(2.0 * far * near) / (far - near);
        m.data[3][2] = -1.0;

        return m;
    }
};

pub inline fn vectorLerp(v1: @Vector(2, i32), v2: @Vector(2, i32), t: f32) @Vector(2, i32) {
    const Vf = @Vector(2, f32);
    const a: Vf = @floatFromInt(v1);
    const b: Vf = @floatFromInt(v2);

    const r: Vf = a + (b - a) * @as(Vf, @splat(t));

    return @intFromFloat(r);
}

pub fn dot(a: Vec3, b: Vec3) f32 {
    return @reduce(.Add, a * b);
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
