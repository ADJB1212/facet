const std = @import("std");
const math = @import("math");
const colors = @import("color.zig");

const Vec3 = math.Vec3;
const Color = colors.Color;

pub const Vertex = struct {
    pos: Vec3,
    color: Color,
};

pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Mesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }
};

pub fn createCube(allocator: std.mem.Allocator, size: f32) !Mesh {
    const h = size / 2.0;

    const vertices = try allocator.alloc(Vertex, 24);
    const indices = try allocator.alloc(u32, 36);

    const face_colors = [_]Color{
        colors.RED,
        colors.GREEN,
        colors.BLUE,
        colors.YELLOW,
        colors.CYAN,
        colors.MAGENTA,
    };

    vertices[0] = .{ .pos = .{ -h, -h, -h }, .color = face_colors[0] };
    vertices[1] = .{ .pos = .{ h, -h, -h }, .color = face_colors[0] };
    vertices[2] = .{ .pos = .{ h, h, -h }, .color = face_colors[0] };
    vertices[3] = .{ .pos = .{ -h, h, -h }, .color = face_colors[0] };

    vertices[4] = .{ .pos = .{ h, -h, h }, .color = face_colors[1] };
    vertices[5] = .{ .pos = .{ -h, -h, h }, .color = face_colors[1] };
    vertices[6] = .{ .pos = .{ -h, h, h }, .color = face_colors[1] };
    vertices[7] = .{ .pos = .{ h, h, h }, .color = face_colors[1] };

    vertices[8] = .{ .pos = .{ -h, h, -h }, .color = face_colors[2] };
    vertices[9] = .{ .pos = .{ h, h, -h }, .color = face_colors[2] };
    vertices[10] = .{ .pos = .{ h, h, h }, .color = face_colors[2] };
    vertices[11] = .{ .pos = .{ -h, h, h }, .color = face_colors[2] };

    vertices[12] = .{ .pos = .{ -h, -h, h }, .color = face_colors[3] };
    vertices[13] = .{ .pos = .{ h, -h, h }, .color = face_colors[3] };
    vertices[14] = .{ .pos = .{ h, -h, -h }, .color = face_colors[3] };
    vertices[15] = .{ .pos = .{ -h, -h, -h }, .color = face_colors[3] };

    vertices[16] = .{ .pos = .{ -h, -h, h }, .color = face_colors[4] };
    vertices[17] = .{ .pos = .{ -h, -h, -h }, .color = face_colors[4] };
    vertices[18] = .{ .pos = .{ -h, h, -h }, .color = face_colors[4] };
    vertices[19] = .{ .pos = .{ -h, h, h }, .color = face_colors[4] };

    vertices[20] = .{ .pos = .{ h, -h, -h }, .color = face_colors[5] };
    vertices[21] = .{ .pos = .{ h, -h, h }, .color = face_colors[5] };
    vertices[22] = .{ .pos = .{ h, h, h }, .color = face_colors[5] };
    vertices[23] = .{ .pos = .{ h, h, -h }, .color = face_colors[5] };

    const idxs = [_]u32{
        0,  1,  2,  0,  2,  3,
        4,  5,  6,  4,  6,  7,
        8,  9,  10, 8,  10, 11,
        12, 13, 14, 12, 14, 15,
        16, 17, 18, 16, 18, 19,
        20, 21, 22, 20, 22, 23,
    };

    @memcpy(indices, &idxs);

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .allocator = allocator,
    };
}

pub fn createPlane(allocator: std.mem.Allocator, width: f32, depth: f32, color: Color) !Mesh {
    const hw = width / 2.0;
    const hd = depth / 2.0;

    const vertices = try allocator.alloc(Vertex, 4);
    const indices = try allocator.alloc(u32, 6);

    vertices[0] = .{ .pos = .{ -hw, 0, -hd }, .color = color };
    vertices[1] = .{ .pos = .{ hw, 0, -hd }, .color = color };
    vertices[2] = .{ .pos = .{ hw, 0, hd }, .color = color };
    vertices[3] = .{ .pos = .{ -hw, 0, hd }, .color = color };

    const idxs = [_]u32{ 0, 1, 2, 0, 2, 3 };
    @memcpy(indices, &idxs);

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .allocator = allocator,
    };
}

pub fn createSphere(allocator: std.mem.Allocator, radius: f32, rings: u32, sectors: u32, color: Color) !Mesh {
    const vertex_count = (rings + 1) * (sectors + 1);
    const index_count = rings * sectors * 6;

    const vertices = try allocator.alloc(Vertex, vertex_count);
    const indices = try allocator.alloc(u32, index_count);

    const R = 1.0 / @as(f32, @floatFromInt(rings - 1));
    const S = 1.0 / @as(f32, @floatFromInt(sectors - 1));

    var v: usize = 0;

    for (0..rings) |r| {
        for (0..sectors) |s| {
            const y = @sin(-std.math.pi / 2.0 + std.math.pi * @as(f32, @floatFromInt(r)) * R);
            const x = @cos(2.0 * std.math.pi * @as(f32, @floatFromInt(s)) * S) * @sin(std.math.pi * @as(f32, @floatFromInt(r)) * R);
            const z = @sin(2.0 * std.math.pi * @as(f32, @floatFromInt(s)) * S) * @sin(std.math.pi * @as(f32, @floatFromInt(r)) * R);

            vertices[v] = .{
                .pos = .{ x * radius, y * radius, z * radius },
                .color = color,
            };
            v += 1;
        }
    }

    v = 0;
    for (0..rings + 1) |r| {
        const phi = std.math.pi * @as(f32, @floatFromInt(r)) / @as(f32, @floatFromInt(rings));
        const y = radius * @cos(phi);
        const r_sin = radius * @sin(phi);

        for (0..sectors + 1) |s| {
            const theta = 2.0 * std.math.pi * @as(f32, @floatFromInt(s)) / @as(f32, @floatFromInt(sectors));
            const x = r_sin * @cos(theta);
            const z = r_sin * @sin(theta);

            var c = color;
            if ((r + s) % 2 == 0) c = colors.darken(c, 0.9);

            vertices[v] = .{
                .pos = .{ x, y, z },
                .color = c,
            };
            v += 1;
        }
    }

    var idx: usize = 0;
    for (0..rings) |r| {
        for (0..sectors) |s| {
            const next_r = r + 1;
            const next_s = s + 1;

            const idx0 = r * (sectors + 1) + s;
            const idx1 = r * (sectors + 1) + next_s;
            const idx2 = next_r * (sectors + 1) + s;
            const idx3 = next_r * (sectors + 1) + next_s;

            indices[idx] = @intCast(idx0);
            idx += 1;
            indices[idx] = @intCast(idx2);
            idx += 1;
            indices[idx] = @intCast(idx1);
            idx += 1;

            indices[idx] = @intCast(idx1);
            idx += 1;
            indices[idx] = @intCast(idx2);
            idx += 1;
            indices[idx] = @intCast(idx3);
            idx += 1;
        }
    }

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .allocator = allocator,
    };
}

pub fn createCylinder(allocator: std.mem.Allocator, radius: f32, height: f32, segments: u32, color: Color) !Mesh {
    const vertex_count = (segments + 1) * 2 + 2;
    const index_count = segments * 6 + segments * 6;

    const vertices = try allocator.alloc(Vertex, vertex_count);
    const indices = try allocator.alloc(u32, index_count);

    const half_h = height / 2.0;

    var v: usize = 0;

    for (0..segments + 1) |i| {
        const theta = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments));
        const x = radius * @cos(theta);
        const z = radius * @sin(theta);
        vertices[v] = .{ .pos = .{ x, half_h, z }, .color = color };
        v += 1;
    }
    for (0..segments + 1) |i| {
        const theta = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments));
        const x = radius * @cos(theta);
        const z = radius * @sin(theta);
        vertices[v] = .{ .pos = .{ x, -half_h, z }, .color = colors.darken(color, 0.8) };
        v += 1;
    }

    const top_center_idx: u32 = @intCast(v);
    vertices[v] = .{ .pos = .{ 0, half_h, 0 }, .color = color };
    v += 1;
    const bot_center_idx: u32 = @intCast(v);
    vertices[v] = .{ .pos = .{ 0, -half_h, 0 }, .color = colors.darken(color, 0.8) };
    v += 1;

    var idx: usize = 0;
    for (0..segments) |i| {
        const i_next = i + 1;

        const t0 = i;
        const t1 = i_next;
        const b0 = i + (segments + 1);
        const b1 = i_next + (segments + 1);

        indices[idx] = @intCast(t0);
        idx += 1;
        indices[idx] = @intCast(b0);
        idx += 1;
        indices[idx] = @intCast(t1);
        idx += 1;

        indices[idx] = @intCast(t1);
        idx += 1;
        indices[idx] = @intCast(b0);
        idx += 1;
        indices[idx] = @intCast(b1);
        idx += 1;

        indices[idx] = top_center_idx;
        idx += 1;
        indices[idx] = @intCast(t1);
        idx += 1;
        indices[idx] = @intCast(t0);
        idx += 1;

        indices[idx] = bot_center_idx;
        idx += 1;
        indices[idx] = @intCast(b0);
        idx += 1;
        indices[idx] = @intCast(b1);
        idx += 1;
    }

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .allocator = allocator,
    };
}

pub fn createCone(allocator: std.mem.Allocator, radius: f32, height: f32, segments: u32, color: Color) !Mesh {
    const vertex_count = segments + 2;
    const index_count = segments * 6;

    const vertices = try allocator.alloc(Vertex, vertex_count);
    const indices = try allocator.alloc(u32, index_count);

    const half_h = height / 2.0;

    var v: usize = 0;

    for (0..segments) |i| {
        const theta = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments));
        const x = radius * @cos(theta);
        const z = radius * @sin(theta);
        vertices[v] = .{ .pos = .{ x, -half_h, z }, .color = if (i % 2 == 0) color else colors.darken(color, 0.9) };
        v += 1;
    }

    const top_idx: u32 = @intCast(v);
    vertices[v] = .{ .pos = .{ 0, half_h, 0 }, .color = color };
    v += 1;

    const base_idx: u32 = @intCast(v);
    vertices[v] = .{ .pos = .{ 0, -half_h, 0 }, .color = colors.darken(color, 0.8) };
    v += 1;

    var idx: usize = 0;
    for (0..segments) |i| {
        const i_next = (i + 1) % segments;

        indices[idx] = top_idx;
        idx += 1;
        indices[idx] = @intCast(i_next);
        idx += 1;
        indices[idx] = @intCast(i);
        idx += 1;

        indices[idx] = base_idx;
        idx += 1;
        indices[idx] = @intCast(i);
        idx += 1;
        indices[idx] = @intCast(i_next);
        idx += 1;
    }

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .allocator = allocator,
    };
}

pub fn createTorus(allocator: std.mem.Allocator, radius: f32, tube_radius: f32, radial_segments: u32, tubular_segments: u32, color: Color) !Mesh {
    const vertex_count = (radial_segments + 1) * (tubular_segments + 1);
    const index_count = radial_segments * tubular_segments * 6;

    const vertices = try allocator.alloc(Vertex, vertex_count);
    const indices = try allocator.alloc(u32, index_count);

    var v: usize = 0;
    for (0..radial_segments + 1) |j| {
        const v_angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(radial_segments));
        const c_v = @cos(v_angle);
        const s_v = @sin(v_angle);

        for (0..tubular_segments + 1) |i| {
            const u_angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(tubular_segments));
            const c_u = @cos(u_angle);
            const s_u = @sin(u_angle);

            const x = (radius + tube_radius * c_v) * c_u;
            const y = (radius + tube_radius * c_v) * s_u;
            const z = tube_radius * s_v;

            var c = color;
            if ((i + j) % 2 == 0) c = colors.darken(c, 0.85);

            vertices[v] = .{ .pos = .{ x, y, z }, .color = c };
            v += 1;
        }
    }

    var idx: usize = 0;
    for (0..radial_segments) |j| {
        for (0..tubular_segments) |i| {
            const i_next = i + 1;
            const j_next = j + 1;

            const a = (tubular_segments + 1) * j + i;
            const b = (tubular_segments + 1) * j + i_next;
            const c = (tubular_segments + 1) * j_next + i;
            const d = (tubular_segments + 1) * j_next + i_next;

            indices[idx] = @intCast(a);
            idx += 1;
            indices[idx] = @intCast(c);
            idx += 1;
            indices[idx] = @intCast(b);
            idx += 1;

            indices[idx] = @intCast(b);
            idx += 1;
            indices[idx] = @intCast(c);
            idx += 1;
            indices[idx] = @intCast(d);
            idx += 1;
        }
    }

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .allocator = allocator,
    };
}

pub fn createPyramid(allocator: std.mem.Allocator, base_size: f32, height: f32, color: Color) !Mesh {
    const half_size = base_size / 2.0;
    const half_h = height / 2.0;

    const vertices = try allocator.alloc(Vertex, 16);
    const indices = try allocator.alloc(u32, 18);

    const top = Vec3{ 0, half_h, 0 };
    const b_lf = Vec3{ -half_size, -half_h, -half_size };
    const b_rf = Vec3{ half_size, -half_h, -half_size };
    const b_rb = Vec3{ half_size, -half_h, half_size };
    const b_lb = Vec3{ -half_size, -half_h, half_size };

    vertices[0] = .{ .pos = top, .color = color };
    vertices[1] = .{ .pos = b_lf, .color = colors.darken(color, 0.9) };
    vertices[2] = .{ .pos = b_rf, .color = colors.darken(color, 0.9) };

    vertices[3] = .{ .pos = top, .color = colors.darken(color, 0.8) };
    vertices[4] = .{ .pos = b_rf, .color = colors.darken(color, 0.8) };
    vertices[5] = .{ .pos = b_rb, .color = colors.darken(color, 0.8) };

    vertices[6] = .{ .pos = top, .color = colors.darken(color, 0.7) };
    vertices[7] = .{ .pos = b_rb, .color = colors.darken(color, 0.7) };
    vertices[8] = .{ .pos = b_lb, .color = colors.darken(color, 0.7) };

    vertices[9] = .{ .pos = top, .color = colors.darken(color, 0.6) };
    vertices[10] = .{ .pos = b_lb, .color = colors.darken(color, 0.6) };
    vertices[11] = .{ .pos = b_lf, .color = colors.darken(color, 0.6) };

    const base_color = colors.darken(color, 0.5);
    vertices[12] = .{ .pos = b_lf, .color = base_color };
    vertices[13] = .{ .pos = b_rf, .color = base_color };
    vertices[14] = .{ .pos = b_rb, .color = base_color };
    vertices[15] = .{ .pos = b_lb, .color = base_color };

    const idxs = [_]u32{
        0,  1,  2,
        3,  4,  5,
        6,  7,  8,
        9,  10, 11,
        12, 14, 13,
        12, 15, 14,
    };
    @memcpy(indices, &idxs);

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .allocator = allocator,
    };
}
