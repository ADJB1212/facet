const std = @import("std");
const math = @import("math");
const colors = @import("color.zig");

const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
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
        0,  2,  1,  0,  3,  2,
        4,  6,  5,  4,  7,  6,
        8,  10, 9,  8,  11, 10,
        12, 14, 13, 12, 15, 14,
        16, 18, 17, 16, 19, 18,
        20, 22, 21, 20, 23, 22,
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
        indices[idx] = @intCast(t0);
        idx += 1;
        indices[idx] = @intCast(t1);
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
        indices[idx] = @intCast(i);
        idx += 1;
        indices[idx] = @intCast(i_next);
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
        12, 13, 14,
        12, 14, 15,
    };
    @memcpy(indices, &idxs);

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .allocator = allocator,
    };
}

pub const ObjModel = struct {
    positions: std.ArrayListUnmanaged(Vec3),
    tex_coords: std.ArrayListUnmanaged(Vec2),
    normals: std.ArrayListUnmanaged(Vec3),
    faces: std.ArrayListUnmanaged(Face),
    allocator: std.mem.Allocator,

    pub const Face = struct {
        v: [3]VertexIndex,
    };

    pub const VertexIndex = struct {
        p_idx: u32,
        t_idx: ?u32,
        n_idx: ?u32,
    };

    pub fn init(allocator: std.mem.Allocator) ObjModel {
        return .{
            .positions = .{},
            .tex_coords = .{},
            .normals = .{},
            .faces = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ObjModel) void {
        self.positions.deinit(self.allocator);
        self.tex_coords.deinit(self.allocator);
        self.normals.deinit(self.allocator);
        self.faces.deinit(self.allocator);
    }

    pub fn toMesh(self: ObjModel, allocator: std.mem.Allocator, color: Color) !Mesh {
        const num_vertices = self.positions.items.len;
        const vertices = try allocator.alloc(Vertex, num_vertices);
        errdefer allocator.free(vertices);

        for (self.positions.items, 0..) |pos, i| {
            vertices[i] = .{ .pos = pos, .color = color };
        }

        const num_indices = self.faces.items.len * 3;
        const indices = try allocator.alloc(u32, num_indices);
        errdefer allocator.free(indices);

        var idx: usize = 0;
        for (self.faces.items) |face| {
            indices[idx] = face.v[0].p_idx;
            idx += 1;
            indices[idx] = face.v[1].p_idx;
            idx += 1;
            indices[idx] = face.v[2].p_idx;
            idx += 1;
        }

        return Mesh{
            .vertices = vertices,
            .indices = indices,
            .allocator = allocator,
        };
    }
};

fn parseObj(allocator: std.mem.Allocator, file_content: []const u8) !ObjModel {
    var model = ObjModel.init(allocator);
    errdefer model.deinit();

    var lines = std.mem.tokenizeAny(u8, file_content, "\n\r");
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, std.mem.trimLeft(u8, line, " "), "#")) continue;

        var tokens = std.mem.tokenizeAny(u8, line, " \t");
        const cmd = tokens.next() orelse continue;

        if (std.mem.eql(u8, cmd, "v")) {
            const x = try parseFloat(tokens.next());
            const y = try parseFloat(tokens.next());
            const z = try parseFloat(tokens.next());
            try model.positions.append(allocator, .{ x, y, z });
        } else if (std.mem.eql(u8, cmd, "vt")) {
            const u = try parseFloat(tokens.next());
            const v = try parseFloat(tokens.next());
            try model.tex_coords.append(allocator, .{ u, v });
        } else if (std.mem.eql(u8, cmd, "vn")) {
            const x = try parseFloat(tokens.next());
            const y = try parseFloat(tokens.next());
            const z = try parseFloat(tokens.next());
            try model.normals.append(allocator, .{ x, y, z });
        } else if (std.mem.eql(u8, cmd, "f")) {
            var face_indices = std.ArrayListUnmanaged(ObjModel.VertexIndex){};
            defer face_indices.deinit(allocator);

            while (tokens.next()) |token| {
                const idx = try parseFaceIndex(token, model.positions.items.len, model.tex_coords.items.len, model.normals.items.len);
                try face_indices.append(allocator, idx);
            }

            if (face_indices.items.len >= 3) {
                const v0 = face_indices.items[0];
                var i: usize = 1;
                while (i + 1 < face_indices.items.len) : (i += 1) {
                    const v1 = face_indices.items[i];
                    const v2 = face_indices.items[i + 1];
                    try model.faces.append(allocator, .{ .v = .{ v0, v1, v2 } });
                }
            }
        }
    }
    return model;
}

pub fn loadObjFromFile(allocator: std.mem.Allocator, path: []const u8) !ObjModel {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    return parseObj(allocator, content);
}

fn parseFloat(str: ?[]const u8) !f32 {
    const s = str orelse return error.InvalidFormat;
    return std.fmt.parseFloat(f32, s);
}

fn parseFaceIndex(token: []const u8, num_pos: usize, num_tex: usize, num_norm: usize) !ObjModel.VertexIndex {
    var iter = std.mem.splitScalar(u8, token, '/');
    const p_str = iter.next();
    const t_str = iter.next();
    const n_str = iter.next();

    const p_idx = try parseIndex(p_str, num_pos) orelse return error.InvalidFaceIndex;
    const t_idx = try parseIndex(t_str, num_tex);
    const n_idx = try parseIndex(n_str, num_norm);

    return ObjModel.VertexIndex{
        .p_idx = p_idx,
        .t_idx = t_idx,
        .n_idx = n_idx,
    };
}

fn parseIndex(str: ?[]const u8, count: usize) !?u32 {
    if (str) |s| {
        if (s.len == 0) return null;
        const i = try std.fmt.parseInt(i32, s, 10);
        if (i > 0) {
            return @intCast(i - 1);
        } else if (i < 0) {
            const idx = @as(i32, @intCast(count)) + i;
            if (idx < 0) return error.IndexOutOfBounds;
            return @intCast(idx);
        } else return error.InvalidIndex;
    }
    return null;
}
