const std = @import("std");
const window = @import("window");
const render = @import("renderer");

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

    window.init();

    var quit: bool = false;

    while (!quit) {
        quit = window.pollEvents();

        render.drawRect(canvas, 20, 20, 200, 180, render.colors.CYAN);
        render.drawTriangle(canvas, 220, 200, 8, 500, 400, 300, render.colors.RED);
        render.drawCircle(canvas, 750, 150, 50, 2, render.colors.MAGENTA);
        window.present();
    }
}
