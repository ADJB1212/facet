const std = @import("std");
const window = @import("window");
const render = @import("renderer");
const input = @import("input");
const math = @import("math");

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;

const vertices = [_]Vec3{
    .{ -1, -1, -1 },
    .{ 1, -1, -1 },
    .{ 1, 1, -1 },
    .{ -1, 1, -1 },
    .{ -1, -1, 1 },
    .{ 1, -1, 1 },
    .{ 1, 1, 1 },
    .{ -1, 1, 1 },
};

const indices = [_]u32{
    0, 1, 2, 0, 2, 3,
    5, 4, 7, 5, 7, 6,
    4, 0, 3, 4, 3, 7,
    1, 5, 6, 1, 6, 2,
    3, 2, 6, 3, 6, 7,
    4, 5, 1, 4, 1, 0,
};

const colors = [_]u32{
    render.colors.RED,
    render.colors.RED,
    render.colors.CYAN,
    render.colors.CYAN,
    render.colors.GREEN,
    render.colors.GREEN,
    render.colors.MAGENTA,
    render.colors.MAGENTA,
    render.colors.BLUE,
    render.colors.BLUE,
    render.colors.YELLOW,
    render.colors.YELLOW,
};

pub fn main(min_init: std.process.Init.Minimal) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded: std.Io.Threaded = .init(allocator, .{ .environ = min_init.environ });
    defer threaded.deinit();
    const io = threaded.io();

    const width = 900;
    const height = 600;

    try render.init(allocator, width, height);
    defer render.deinit();

    const canvas = render.getCanvas();
    render.fillCanvas(canvas, render.colors.BLACK);

    var fps: render.FpsManager = try .init(io);
    fps.setTargetFPS(120);

    window.init();

    var quit: bool = false;
    var circle_x: i32 = 750;
    var timer = try std.time.Timer.start();
    var last_time: u64 = 0;
    var angle: f32 = 0.0;
    while (!quit) {
        quit = window.pollEvents();
        if (input.isKeyDown(.Escape)) quit = true;

        const now = timer.read();
        const dt_ns = now - last_time;
        last_time = now;
        const dt = @as(f32, @floatFromInt(dt_ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));

        angle += dt * 1.0;

        render.fillCanvas(canvas, render.colors.BLACK);
        render.clearDepth(canvas, 1.0);

        if (input.isKeyDown(.Right)) {
            circle_x += 1;
        }
        if (input.isKeyDown(.Left)) {
            circle_x -= 1;
        }

        const aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
        const projection = Mat4.perspective(std.math.degreesToRadians(45.0), aspect, 0.1, 100.0);

        const view = Mat4.translate(.{ 0, 0, -5.0 });
        const scale = Mat4.scale(.{ 0.5, 0.5, 0.5 });
        const rotation = Mat4.mul(Mat4.rotateX(angle * 0.5), Mat4.rotateY(angle));
        const model = Mat4.mul(rotation, scale);

        const mvp = Mat4.mul(projection, Mat4.mul(view, model));

        var transformed_verts: [8]Vec4 = undefined;

        for (vertices, 0..) |v, i| {
            const v4 = Vec4{ v[0], v[1], v[2], 1.0 };
            transformed_verts[i] = Mat4.mulVec(mvp, v4);
        }

        var i: usize = 0;
        while (i < indices.len) : (i += 3) {
            const idx0 = indices[i];
            const idx1 = indices[i + 1];
            const idx2 = indices[i + 2];

            const v0c = transformed_verts[idx0];
            const v1c = transformed_verts[idx1];
            const v2c = transformed_verts[idx2];

            if (v0c[3] < 0.1 or v1c[3] < 0.1 or v2c[3] < 0.1) continue;

            const v0_ndc = v0c / @as(Vec4, @splat(v0c[3]));
            const v1_ndc = v1c / @as(Vec4, @splat(v1c[3]));
            const v2_ndc = v2c / @as(Vec4, @splat(v2c[3]));

            const v0_screen = Vec3{ (v0_ndc[0] + 1.0) * 0.5 * @as(f32, @floatFromInt(width)), (1.0 - v0_ndc[1]) * 0.5 * @as(f32, @floatFromInt(height)), v0_ndc[2] };
            const v1_screen = Vec3{ (v1_ndc[0] + 1.0) * 0.5 * @as(f32, @floatFromInt(width)), (1.0 - v1_ndc[1]) * 0.5 * @as(f32, @floatFromInt(height)), v1_ndc[2] };
            const v2_screen = Vec3{ (v2_ndc[0] + 1.0) * 0.5 * @as(f32, @floatFromInt(width)), (1.0 - v2_ndc[1]) * 0.5 * @as(f32, @floatFromInt(height)), v2_ndc[2] };

            const color = colors[i / 3];
            render.drawTriangle3D(canvas, v0_screen, v1_screen, v2_screen, color);
        }

        render.drawRect(canvas, 20, 20, 100, 180, render.colors.CYAN);
        render.drawTriangle(canvas, 220, 100, 8, 300, 200, 20, render.colors.RED);
        render.drawCircle(canvas, circle_x, 150, 50, 2, render.colors.MAGENTA);
        render.drawBezier(canvas, 130, 140, 300, 280, 134, 500, 3, render.colors.WHITE);
        render.drawText(canvas, "Andrew 123456789 (Facet)!", width / 2, height - 100, 4, render.colors.WHITE, .center);
        fps.drawFPS(canvas, width - 90, 15, render.colors.WHITE);
        window.present();
        try fps.drawFPS(canvas, width - 80, 10, render.colors.WHITE);
        try fps.waitForNextFrame();
    }
}
