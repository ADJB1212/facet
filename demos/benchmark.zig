const std = @import("std");
const renderer = @import("renderer");

const WIDTH = 1920;
const HEIGHT = 1080;
const NUM_OPERATIONS = 100000;

const Color = renderer.colors.Color;

fn getRandomColor(rand: std.Random) Color {
    return @intCast(rand.int(u32) | 0xFF000000);
}

fn getRandomCoordinate(rand: std.Random, max: usize) i32 {
    return @intCast(rand.intRangeAtMost(usize, 0, max));
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

    const benchmarks = [_]Benchmark{
        .{ .name = "Fill Canvas", .func = benchFill, .iterations = 1000 },
        .{ .name = "Set Pixel", .func = benchPixels, .iterations = NUM_OPERATIONS },
        .{ .name = "Draw Line (1px)", .func = benchLines, .iterations = NUM_OPERATIONS / 2 },
        .{ .name = "Draw Line (Thick)", .func = benchThickLines, .iterations = NUM_OPERATIONS / 2 },
        .{ .name = "Draw Rectangle", .func = benchRectangles, .iterations = NUM_OPERATIONS / 2 },
        .{ .name = "Draw Triangle", .func = benchTriangles, .iterations = 100 },
        .{ .name = "Draw Circle", .func = benchCircles, .iterations = NUM_OPERATIONS / 5 },
        .{ .name = "Draw AA Circle", .func = benchAntiAliasedCircles, .iterations = NUM_OPERATIONS / 10 },
        .{ .name = "Draw Bezier", .func = benchBezier, .iterations = NUM_OPERATIONS / 5 },
        .{ .name = "Draw Text", .func = benchText, .iterations = NUM_OPERATIONS / 5 },
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
