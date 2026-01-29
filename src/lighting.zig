const std = @import("std");
const math = @import("math");
const color = @import("colors");

const Vec3 = math.Vec3;
const Color = color.Color;

pub const LightType = enum {
    Directional,
    Point,
};

pub const Light = struct {
    type: LightType,
    position: Vec3,
    color: Vec3,
    intensity: f32,
};

pub const Material = struct {
    ambient: f32,
    diffuse: f32,
    specular: f32,
    shininess: f32,
    emission: f32,
};

pub const DEFAULT_MATERIAL = Material{
    .ambient = 0.3,
    .diffuse = 0.8,
    .specular = 0.5,
    .shininess = 32.0,
    .emission = 0.0,
};

pub fn calculateLighting(pos: Vec3, normal: Vec3, view_pos: Vec3, base_color: Color, material: Material, lights: []const Light, ambient_light: Vec3) Color {
    const r = @as(f32, @floatFromInt(color.red(base_color))) / 255.0;
    const g = @as(f32, @floatFromInt(color.green(base_color))) / 255.0;
    const b = @as(f32, @floatFromInt(color.blue(base_color))) / 255.0;
    const object_color = Vec3{ r, g, b };

    var total_light = ambient_light * @as(Vec3, @splat(material.ambient)) + @as(Vec3, @splat(material.emission));

    const view_dir = math.normalize(view_pos - pos);

    for (lights) |light| {
        var light_dir: Vec3 = undefined;
        var attenuation: f32 = 1.0;

        switch (light.type) {
            .Directional => {
                light_dir = math.normalize(-light.position);
            },
            .Point => {
                const diff = light.position - pos;
                const dist_sq = math.dot(diff, diff);
                const dist = @sqrt(dist_sq);
                light_dir = diff / @as(Vec3, @splat(dist));

                attenuation = 1.0 / (1.0 + 0.1 * dist + 0.01 * dist_sq);
            },
        }

        const diff = @max(math.dot(normal, light_dir), 0.0);
        const diffuse = light.color * @as(Vec3, @splat(diff * material.diffuse * light.intensity * attenuation));

        var specular: Vec3 = .{ 0, 0, 0 };
        if (diff > 0.0) {
            const reflect_dir = math.normalize(normal * @as(Vec3, @splat(2.0 * math.dot(light_dir, normal))) - light_dir);

            const spec = std.math.pow(f32, @max(math.dot(view_dir, reflect_dir), 0.0), material.shininess);
            specular = light.color * @as(Vec3, @splat(spec * material.specular * light.intensity * attenuation));
        }

        total_light += diffuse + specular;
    }

    const final_color = object_color * total_light;

    const fr = std.math.clamp(final_color[0], 0.0, 1.0);
    const fg = std.math.clamp(final_color[1], 0.0, 1.0);
    const fb = std.math.clamp(final_color[2], 0.0, 1.0);

    return color.rgba(@intFromFloat(fr * 255.0), @intFromFloat(fg * 255.0), @intFromFloat(fb * 255.0), color.alpha(base_color));
}
