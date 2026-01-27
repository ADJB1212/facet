const std = @import("std");
const window = @import("window");
const render = @import("renderer");
const input = @import("input");
const math = @import("math");

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;

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

    var cube = try render.mesh.createCube(allocator, 1.0);
    defer cube.deinit();

    var plane = try render.mesh.createPlane(allocator, 10.0, 10.0, render.colors.darken(render.colors.GREEN, 0.5));
    defer plane.deinit();

    var sphere = try render.mesh.createSphere(allocator, 0.8, 16, 16, render.colors.RED);
    defer sphere.deinit();

    var cylinder = try render.mesh.createCylinder(allocator, 0.5, 1.5, 16, render.colors.MAGENTA);
    defer cylinder.deinit();

    var cone = try render.mesh.createCone(allocator, 0.6, 1.5, 16, render.colors.YELLOW);
    defer cone.deinit();

    var torus = try render.mesh.createTorus(allocator, 0.6, 0.2, 16, 32, render.colors.CYAN);
    defer torus.deinit();

    var fps: render.FpsManager = try .init(io);
    fps.setTargetFPS(60);

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
        const view = Mat4.translate(.{ 0, -2.5, -9.0 });

        // Draw Plane
        const model_plane = Mat4.identity();
        const mvp_plane = Mat4.mul(projection, Mat4.mul(view, model_plane));
        render.drawMesh(canvas, plane, mvp_plane);

        // Draw Cube
        const rot_cube = Mat4.mul(Mat4.rotateX(angle * 0.5), Mat4.rotateY(angle));
        const trans_cube = Mat4.translate(.{ -1.5, 0.5, 0 });
        const model_cube = Mat4.mul(trans_cube, rot_cube);
        const mvp_cube = Mat4.mul(projection, Mat4.mul(view, model_cube));
        render.drawMesh(canvas, cube, mvp_cube);

        // Draw Sphere
        const trans_sphere = Mat4.translate(.{ 1.5, 0.8, 0 });
        const model_sphere = Mat4.mul(trans_sphere, Mat4.rotateY(-angle));
        const mvp_sphere = Mat4.mul(projection, Mat4.mul(view, model_sphere));
        render.drawMesh(canvas, sphere, mvp_sphere);

        // Draw Cylinder
        const trans_cyl = Mat4.translate(.{ -3.5, 0.75, 0 });
        const rot_cyl = Mat4.rotateX(std.math.degreesToRadians(30.0));
        const model_cyl = Mat4.mul(trans_cyl, Mat4.mul(rot_cyl, Mat4.rotateY(angle * 0.8)));
        const mvp_cyl = Mat4.mul(projection, Mat4.mul(view, model_cyl));
        render.drawMesh(canvas, cylinder, mvp_cyl);

        // Draw Cone
        const trans_cone = Mat4.translate(.{ 3.5, 0.75, 0 });
        const model_cone = Mat4.mul(trans_cone, Mat4.rotateY(angle * 1.2));
        const mvp_cone = Mat4.mul(projection, Mat4.mul(view, model_cone));
        render.drawMesh(canvas, cone, mvp_cone);

        // Draw Torus
        const trans_torus = Mat4.translate(.{ 0, 2.0, -1.0 });
        const rot_torus = Mat4.mul(Mat4.rotateX(angle), Mat4.rotateY(angle * 0.5));
        const model_torus = Mat4.mul(trans_torus, rot_torus);
        const mvp_torus = Mat4.mul(projection, Mat4.mul(view, model_torus));
        render.drawMesh(canvas, torus, mvp_torus);

        render.drawRect(canvas, 20, 20, 100, 180, render.colors.CYAN);
        render.drawTriangle(canvas, 220, 100, 8, 300, 200, 20, render.colors.RED);
        render.drawCircle(canvas, circle_x, 150, 50, 2, render.colors.MAGENTA);
        render.drawBezier(canvas, 130, 140, 300, 280, 134, 500, 3, render.colors.WHITE);
        render.drawText(canvas, "Andrew 123456789 (Facet)!", width / 2, height - 100, 4, render.colors.WHITE, .center);
        try fps.drawFPS(canvas, width - 90, 15, render.colors.WHITE);
        window.present();
        try fps.drawFPS(canvas, width - 80, 10, render.colors.WHITE);
        try fps.waitForNextFrame();
    }
}
