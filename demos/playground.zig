const std = @import("std");
const window = @import("window");
const render = @import("renderer");
const input = @import("input");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const width = 900;
    const height = 600;

    try render.init(allocator, width, height);
    defer render.deinit();

    const canvas = render.getCanvas();
    render.fillCanvas(canvas, render.colors.BLACK);

    var fps: render.FpsManager = .{};
    fps.setTargetFPS(120);

    window.init();

    var quit: bool = false;
    var circle_x: i32 = 750;
    while (!quit) {
        quit = window.pollEvents();
        render.fillCanvas(canvas, render.colors.BLACK);

        if (input.isKeyDown(.Right)) {
            circle_x += 1;
        }
        if (input.isKeyDown(.Left)) {
            circle_x -= 1;
        }

        render.drawRect(canvas, 20, 20, 100, 180, render.colors.CYAN);
        render.drawTriangle(canvas, 220, 100, 8, 300, 200, 20, render.colors.RED);
        render.drawCircle(canvas, circle_x, 150, 50, 2, render.colors.MAGENTA);
        render.drawBezier(canvas, 130, 140, 300, 280, 134, 500, 3, render.colors.WHITE);
        render.drawText(canvas, "Andrew 123456789 (Facet)!", width / 2, height - 100, 4, render.colors.WHITE, .center);
        window.present();
        fps.drawFPS(canvas, width - 80, 10, render.colors.WHITE);
        fps.waitForNextFrame();
    }
}
