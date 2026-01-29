const std = @import("std");
const renderer = @import("renderer");
const math = @import("math");

const WIDTH = 1920;
const HEIGHT = 1080;
const NUM_OPERATIONS = 100000;

const Color = renderer.colors.Color;

var mesh_cube: renderer.mesh.Mesh = undefined;
var mesh_plane: renderer.mesh.Mesh = undefined;
var mesh_sphere: renderer.mesh.Mesh = undefined;
var mesh_cylinder: renderer.mesh.Mesh = undefined;
var mesh_cone: renderer.mesh.Mesh = undefined;
var mesh_torus: renderer.mesh.Mesh = undefined;
var mesh_pyramid: renderer.mesh.Mesh = undefined;
var mesh_teapot: renderer.mesh.Mesh = undefined;

fn getRandomColor(rand: std.Random) Color {
    return @intCast(rand.int(u32) | 0xFF000000);
}

fn getRandomCoordinate(rand: std.Random, max: usize) i32 {
    return @intCast(rand.intRangeAtMost(usize, 0, max));
}

fn getRandomCoordinateF32(rand: std.Random, max: f32) f32 {
    return rand.float(f32) * max;
}

const BenchmarkFn = *const fn (canvas: *renderer.Canvas, rand: std.Random) void;

const Benchmark = struct {
    name: []const u8,
    func: BenchmarkFn,
    iterations: usize,
};

fn benchFill(canvas: *renderer.Canvas, rand: std.Random) void {
    _ = rand;
    renderer.fillCanvas(canvas, 0xFF000000);
}

fn benchPixels(canvas: *renderer.Canvas, rand: std.Random) void {
    const x = getRandomCoordinate(rand, WIDTH - 1);
    const y = getRandomCoordinate(rand, HEIGHT - 1);
    const color = getRandomColor(rand);
    renderer.setPixel(canvas, x, y, color);
}

fn benchLines(canvas: *renderer.Canvas, rand: std.Random) void {
    const x1 = getRandomCoordinate(rand, WIDTH - 1);
    const y1 = getRandomCoordinate(rand, HEIGHT - 1);
    const x2 = getRandomCoordinate(rand, WIDTH - 1);
    const y2 = getRandomCoordinate(rand, HEIGHT - 1);
    const color = getRandomColor(rand);
    renderer.drawLine(canvas, x1, y1, x2, y2, 1, color);
}

fn benchThickLines(canvas: *renderer.Canvas, rand: std.Random) void {
    const x1 = getRandomCoordinate(rand, WIDTH - 1);
    const y1 = getRandomCoordinate(rand, HEIGHT - 1);
    const x2 = getRandomCoordinate(rand, WIDTH - 1);
    const y2 = getRandomCoordinate(rand, HEIGHT - 1);
    const thickness = rand.intRangeAtMost(u32, 2, 10);
    const color = getRandomColor(rand);
    renderer.drawLine(canvas, x1, y1, x2, y2, thickness, color);
}

fn benchRectangles(canvas: *renderer.Canvas, rand: std.Random) void {
    const x = getRandomCoordinate(rand, WIDTH - 100);
    const y = getRandomCoordinate(rand, HEIGHT - 100);
    const w = rand.intRangeAtMost(u32, 10, 100);
    const h = rand.intRangeAtMost(u32, 10, 100);
    const color = getRandomColor(rand);
    renderer.drawRect(canvas, x, y, w, h, color);
}

fn benchTriangles(canvas: *renderer.Canvas, rand: std.Random) void {
    const x1 = getRandomCoordinate(rand, WIDTH - 1);
    const y1 = getRandomCoordinate(rand, HEIGHT - 1);
    const x2 = getRandomCoordinate(rand, WIDTH - 1);
    const y2 = getRandomCoordinate(rand, HEIGHT - 1);
    const x3 = getRandomCoordinate(rand, WIDTH - 1);
    const y3 = getRandomCoordinate(rand, HEIGHT - 1);
    const color = getRandomColor(rand);
    renderer.drawTriangle(canvas, x1, y1, x2, y2, x3, y3, color);
}

fn benchTriangles3D(canvas: *renderer.Canvas, rand: std.Random) void {
    const x1 = getRandomCoordinateF32(rand, WIDTH - 1);
    const y1 = getRandomCoordinateF32(rand, HEIGHT - 1);
    const z1 = getRandomCoordinateF32(rand, 1.0);

    const x2 = getRandomCoordinateF32(rand, WIDTH - 1);
    const y2 = getRandomCoordinateF32(rand, HEIGHT - 1);
    const z2 = getRandomCoordinateF32(rand, 1.0);

    const x3 = getRandomCoordinateF32(rand, WIDTH - 1);
    const y3 = getRandomCoordinateF32(rand, HEIGHT - 1);
    const z3 = getRandomCoordinateF32(rand, 1.0);

    const color = getRandomColor(rand);
    renderer.drawTriangle3D(canvas, .{ x1, y1, z1 }, .{ x2, y2, z2 }, .{ x3, y3, z3 }, color);
}

fn benchCircles(canvas: *renderer.Canvas, rand: std.Random) void {
    const x = getRandomCoordinate(rand, WIDTH - 1);
    const y = getRandomCoordinate(rand, HEIGHT - 1);
    const r = rand.intRangeAtMost(i32, 5, 50);
    const color = getRandomColor(rand);
    renderer.drawCircle(canvas, x, y, r, 1, color);
}

fn benchAntiAliasedCircles(canvas: *renderer.Canvas, rand: std.Random) void {
    const x = getRandomCoordinate(rand, WIDTH - 1);
    const y = getRandomCoordinate(rand, HEIGHT - 1);
    const r = rand.intRangeAtMost(i32, 5, 50);
    const color = getRandomColor(rand);
    renderer.drawCircle(canvas, x, y, r, 2, color);
}

fn benchBezier(canvas: *renderer.Canvas, rand: std.Random) void {
    const x1 = getRandomCoordinate(rand, WIDTH - 1);
    const y1 = getRandomCoordinate(rand, HEIGHT - 1);
    const x2 = getRandomCoordinate(rand, WIDTH - 1);
    const y2 = getRandomCoordinate(rand, HEIGHT - 1);
    const x3 = getRandomCoordinate(rand, WIDTH - 1);
    const y3 = getRandomCoordinate(rand, HEIGHT - 1);
    const color = getRandomColor(rand);
    renderer.drawBezier(canvas, x1, y1, x2, y2, x3, y3, 1, color);
}

fn benchText(canvas: *renderer.Canvas, rand: std.Random) void {
    const x = getRandomCoordinate(rand, WIDTH - 100);
    const y = getRandomCoordinate(rand, HEIGHT - 20);
    const size = rand.intRangeAtMost(i32, 1, 3);
    const color = getRandomColor(rand);
    renderer.drawText(canvas, "Benchmark", x, y, size, color, .left);
}

fn getRandomMVP(rand: std.Random) math.Mat4 {
    const aspect = @as(f32, @floatFromInt(WIDTH)) / @as(f32, @floatFromInt(HEIGHT));
    const projection = math.Mat4.perspective(std.math.degreesToRadians(45.0), aspect, 0.1, 100.0);

    const x = getRandomCoordinateF32(rand, 10.0) - 5.0;
    const y = getRandomCoordinateF32(rand, 10.0) - 5.0;
    const z = -10.0 - getRandomCoordinateF32(rand, 10.0);

    const view = math.Mat4.translate(.{ x, y, z });

    const rx = getRandomCoordinateF32(rand, std.math.pi * 2.0);
    const ry = getRandomCoordinateF32(rand, std.math.pi * 2.0);

    const rotation = math.Mat4.mul(math.Mat4.rotateX(rx), math.Mat4.rotateY(ry));
    const model = rotation;

    return math.Mat4.mul(projection, math.Mat4.mul(view, model));
}

fn benchMeshCube(canvas: *renderer.Canvas, rand: std.Random) void {
    const mvp = getRandomMVP(rand);
    renderer.drawMesh(canvas, mesh_cube, mvp);
}

fn benchMeshPlane(canvas: *renderer.Canvas, rand: std.Random) void {
    const mvp = getRandomMVP(rand);
    renderer.drawMesh(canvas, mesh_plane, mvp);
}

fn benchMeshSphere(canvas: *renderer.Canvas, rand: std.Random) void {
    const mvp = getRandomMVP(rand);
    renderer.drawMesh(canvas, mesh_sphere, mvp);
}

fn benchMeshCylinder(canvas: *renderer.Canvas, rand: std.Random) void {
    const mvp = getRandomMVP(rand);
    renderer.drawMesh(canvas, mesh_cylinder, mvp);
}

fn benchMeshCone(canvas: *renderer.Canvas, rand: std.Random) void {
    const mvp = getRandomMVP(rand);
    renderer.drawMesh(canvas, mesh_cone, mvp);
}

fn benchMeshTorus(canvas: *renderer.Canvas, rand: std.Random) void {
    const mvp = getRandomMVP(rand);
    renderer.drawMesh(canvas, mesh_torus, mvp);
}

fn benchMeshPyramid(canvas: *renderer.Canvas, rand: std.Random) void {
    const mvp = getRandomMVP(rand);
    renderer.drawMesh(canvas, mesh_pyramid, mvp);
}

fn benchMeshTeapot(canvas: *renderer.Canvas, rand: std.Random) void {
    const mvp = getRandomMVP(rand);
    renderer.drawMesh(canvas, mesh_teapot, mvp);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try renderer.init(allocator, WIDTH, HEIGHT);
    defer renderer.deinit();

    const canvas = renderer.getCanvas();
    renderer.clearDepth(canvas, 1.0);
    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    mesh_cube = try renderer.mesh.createCube(allocator, 1.0);
    defer mesh_cube.deinit();

    mesh_plane = try renderer.mesh.createPlane(allocator, 2.0, 2.0, renderer.colors.GREEN);
    defer mesh_plane.deinit();

    mesh_sphere = try renderer.mesh.createSphere(allocator, 1.0, 16, 16, renderer.colors.RED);
    defer mesh_sphere.deinit();

    mesh_cylinder = try renderer.mesh.createCylinder(allocator, 0.5, 1.0, 16, renderer.colors.MAGENTA);
    defer mesh_cylinder.deinit();

    mesh_cone = try renderer.mesh.createCone(allocator, 0.5, 1.0, 16, renderer.colors.YELLOW);
    defer mesh_cone.deinit();

    mesh_torus = try renderer.mesh.createTorus(allocator, 0.5, 0.2, 16, 16, renderer.colors.CYAN);
    defer mesh_torus.deinit();

    mesh_pyramid = try renderer.mesh.createPyramid(allocator, 1.0, 1.0, renderer.colors.BLUE);
    defer mesh_pyramid.deinit();

    var teapot_model = try renderer.mesh.loadObjFromFile(allocator, "testing/teapot.obj");
    defer teapot_model.deinit();
    mesh_teapot = try teapot_model.toMesh(allocator, renderer.colors.WHITE);
    defer mesh_teapot.deinit();

    const benchmarks = [_]Benchmark{
        .{ .name = "Fill Canvas", .func = benchFill, .iterations = 1000 },
        .{ .name = "Set Pixel", .func = benchPixels, .iterations = NUM_OPERATIONS },
        .{ .name = "Draw Line (1px)", .func = benchLines, .iterations = NUM_OPERATIONS / 2 },
        .{ .name = "Draw Line (Thick)", .func = benchThickLines, .iterations = NUM_OPERATIONS / 2 },
        .{ .name = "Draw Rectangle", .func = benchRectangles, .iterations = NUM_OPERATIONS / 2 },
        .{ .name = "Draw Triangle", .func = benchTriangles, .iterations = 100 },
        .{ .name = "Draw Triangle 3D", .func = benchTriangles3D, .iterations = 100 },
        .{ .name = "Draw Circle", .func = benchCircles, .iterations = NUM_OPERATIONS / 5 },
        .{ .name = "Draw AA Circle", .func = benchAntiAliasedCircles, .iterations = NUM_OPERATIONS / 10 },
        .{ .name = "Draw Bezier", .func = benchBezier, .iterations = NUM_OPERATIONS / 5 },
        .{ .name = "Draw Text", .func = benchText, .iterations = NUM_OPERATIONS / 5 },
        .{ .name = "Mesh: Cube", .func = benchMeshCube, .iterations = 1000 },
        .{ .name = "Mesh: Plane", .func = benchMeshPlane, .iterations = 1000 },
        .{ .name = "Mesh: Sphere", .func = benchMeshSphere, .iterations = 1000 },
        .{ .name = "Mesh: Cylinder", .func = benchMeshCylinder, .iterations = 1000 },
        .{ .name = "Mesh: Cone", .func = benchMeshCone, .iterations = 1000 },
        .{ .name = "Mesh: Torus", .func = benchMeshTorus, .iterations = 1000 },
        .{ .name = "Mesh: Pyramid", .func = benchMeshPyramid, .iterations = 1000 },
        .{ .name = "Mesh: Teapot", .func = benchMeshTeapot, .iterations = 1000 },
    };

    // The 7 print statements below were written by Gemini 3 Pro (for more readable output)
    try stdout.print("\nFacet Software Renderer Benchmark\n", .{});
    try stdout.print("Resolution: {d}x{d}\n", .{ WIDTH, HEIGHT });
    try stdout.print("----------------------------------------------------------------\n", .{});
    try stdout.print("{s:<20} | {s:<12} | {s:<12} | {s:<12}\n", .{ "Test Name", "Iterations", "Total Time", "Op/s" });
    try stdout.print("----------------------------------------------------------------\n", .{});
    try stdout.flush();

    var timer = try std.time.Timer.start();

    for (benchmarks) |bench| {
        timer.reset();
        for (0..bench.iterations) |_| {
            bench.func(canvas, rand);
        }
        const elapsed_ns = timer.read();
        const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / std.time.ns_per_s;
        const ops_per_sec = @as(f64, @floatFromInt(bench.iterations)) / elapsed_s;

        try stdout.print("{s:<20} | {d:<12} | {d:>.4}s      | {d:>.2}\n", .{ bench.name, bench.iterations, elapsed_s, ops_per_sec });
        try stdout.flush();
    }
    try stdout.print("----------------------------------------------------------------\n", .{});
    try stdout.flush();
}
