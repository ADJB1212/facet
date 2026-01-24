const std = @import("std");
const render = @import("renderer");
const window = @import("window");
const input = @import("input");

const Canvas = render.Canvas;

const SCREEN_WIDTH = 900;
const SCREEN_HEIGHT = 600;

const MAP_SIZE = 16;
const TEX_WIDTH = 64;
const TEX_HEIGHT = 64;

const MIN_WALL_DIST = 0.1;
const MAX_DT = 0.1;

const MOVE_SPEED = 3.0;
const ROT_SPEED = 3.0;

const BOB_FREQ = 10.0;
const BOB_VIEW_Y = 3.0;

const MINIMAP_SCALE = 8;
const MINIMAP_OFFSET_X = 10;
const MINIMAP_OFFSET_Y = 10;

const MAPDATA = [MAP_SIZE * MAP_SIZE]u8{
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 2, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 1,
    1, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 3, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 4, 4, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};

const Vec2 = @Vector(2, f32);
const Vec2i = @Vector(2, i32);

const UserInput = struct {
    forward: bool,
    backward: bool,
    left: bool,
    right: bool,
    escape: bool,
};

const State = struct {
    pos: Vec2,
    dir: Vec2,
    plane: Vec2,
    walk_timer: f32,
};

fn length(v: Vec2) f32 {
    const squared = v * v;
    return @sqrt(squared[0] + squared[1]);
}

fn normalize(v: Vec2) Vec2 {
    const l = length(v);
    return v / @as(Vec2, @splat(l));
}

fn mapIndex(x: i32, y: i32) ?usize {
    if (x < 0 or y < 0 or x >= MAP_SIZE or y >= MAP_SIZE) return null;
    return @as(usize, @intCast(y)) * MAP_SIZE + @as(usize, @intCast(x));
}

fn mapCell(x: i32, y: i32) u8 {
    return if (mapIndex(x, y)) |idx| MAPDATA[idx] else 1;
}

fn wallColor(id: u8) u32 {
    return switch (id) {
        1 => render.colors.RED,
        2 => render.colors.GREEN,
        3 => render.colors.BLUE,
        4 => render.colors.MAGENTA,
        else => render.colors.WHITE,
    };
}

fn init() State {
    return .{
        .pos = .{ 2.0, 2.0 },
        .dir = normalize(.{ -1.0, 0.1 }),
        .plane = .{ 0.0, 0.66 },
        .walk_timer = 0.0,
    };
}

fn drawMinimap(canvas: *Canvas, state: *const State) void {
    const map_px = MAP_SIZE * MINIMAP_SCALE;
    render.drawRect(canvas, MINIMAP_OFFSET_X - 2, MINIMAP_OFFSET_Y - 2, map_px + 4, map_px + 4, 0xAA000000);

    var y: usize = 0;
    while (y < MAP_SIZE) : (y += 1) {
        var x: usize = 0;
        while (x < MAP_SIZE) : (x += 1) {
            const val = MAPDATA[y * MAP_SIZE + x];
            if (val == 0) continue;

            const color = wallColor(val);
            render.drawRect(canvas, MINIMAP_OFFSET_X + @as(i32, @intCast(x * MINIMAP_SCALE)), MINIMAP_OFFSET_Y + @as(i32, @intCast(y * MINIMAP_SCALE)), MINIMAP_SCALE - 1, MINIMAP_SCALE - 1, color);
        }
    }

    const scale_f = @as(f32, @floatFromInt(MINIMAP_SCALE));
    const px = MINIMAP_OFFSET_X + @as(i32, @intFromFloat(state.pos[0] * scale_f));
    const py = MINIMAP_OFFSET_Y + @as(i32, @intFromFloat(state.pos[1] * scale_f));

    render.drawCircle(canvas, px, py, 2, 2, render.colors.WHITE);
}

fn raycastColumn(canvas: *Canvas, state: *const State, x: i32, center_y: f32) void {
    const x_f = @as(f32, @floatFromInt(x));
    const w_f = @as(f32, @floatFromInt(SCREEN_WIDTH));
    const xcam = (2.0 * (x_f / w_f)) - 1.0;

    const dir = state.dir + state.plane * @as(Vec2, @splat(xcam));
    const pos = state.pos;
    var ipos = Vec2i{ @intFromFloat(pos[0]), @intFromFloat(pos[1]) };

    const abs_dir = @abs(dir);
    const deltadist = Vec2{
        if (abs_dir[0] < 1e-20) 1e30 else @abs(1.0 / dir[0]),
        if (abs_dir[1] < 1e-20) 1e30 else @abs(1.0 / dir[1]),
    };

    var sidedist: Vec2 = undefined;
    var step: Vec2i = undefined;

    if (dir[0] < 0) {
        step[0] = -1;
        sidedist[0] = (pos[0] - @as(f32, @floatFromInt(ipos[0]))) * deltadist[0];
    } else {
        step[0] = 1;
        sidedist[0] = (@as(f32, @floatFromInt(ipos[0] + 1)) - pos[0]) * deltadist[0];
    }

    if (dir[1] < 0) {
        step[1] = -1;
        sidedist[1] = (pos[1] - @as(f32, @floatFromInt(ipos[1]))) * deltadist[1];
    } else {
        step[1] = 1;
        sidedist[1] = (@as(f32, @floatFromInt(ipos[1] + 1)) - pos[1]) * deltadist[1];
    }

    var hit = false;
    var side: i32 = 0;
    var val: u8 = 0;

    while (!hit) {
        if (sidedist[0] < sidedist[1]) {
            sidedist[0] += deltadist[0];
            ipos[0] += step[0];
            side = 0;
        } else {
            sidedist[1] += deltadist[1];
            ipos[1] += step[1];
            side = 1;
        }

        val = mapCell(ipos[0], ipos[1]);
        if (val > 0) hit = true;
    }

    var dperp: f32 = if (side == 0) (sidedist[0] - deltadist[0]) else (sidedist[1] - deltadist[1]);
    if (dperp < MIN_WALL_DIST) dperp = MIN_WALL_DIST;

    const line_height = @as(f32, @floatFromInt(SCREEN_HEIGHT)) / dperp;
    const draw_start = -line_height / 2.0 + center_y;

    var y0: i32 = @intFromFloat(draw_start);
    var y1: i32 = @intFromFloat(draw_start + line_height);

    const ceiling_y1 = @max(0, @min(@as(i32, @intCast(SCREEN_HEIGHT)), y0));
    const floor_y0 = @max(0, @min(@as(i32, @intCast(SCREEN_HEIGHT)), y1));
    const floor_y1 = SCREEN_HEIGHT - 1;

    render.drawVerticalLine(canvas, x, 0, ceiling_y1, 1, 0xFF222222);
    render.drawVerticalLine(canvas, x, floor_y0, floor_y1, 1, 0xFF333333);

    var wall_x_f: f32 = if (side == 0)
        state.pos[1] + dperp * dir[1]
    else
        state.pos[0] + dperp * dir[0];
    wall_x_f -= @floor(wall_x_f);

    var tex_x = @as(i32, @intFromFloat(wall_x_f * @as(f32, @floatFromInt(TEX_WIDTH))));
    if (side == 0 and dir[0] > 0) tex_x = TEX_WIDTH - tex_x - 1;
    if (side == 1 and dir[1] < 0) tex_x = TEX_WIDTH - tex_x - 1;

    const step_tex = @as(f32, @floatFromInt(TEX_HEIGHT)) / line_height;
    var tex_pos = (@as(f32, @floatFromInt(y0)) - draw_start) * step_tex;

    y0 = @max(0, y0);
    y1 = @min(@as(i32, @intCast(SCREEN_HEIGHT)), y1);

    var color = wallColor(val);
    if (side == 1) color = render.colors.darken(color, 0.7);

    var wy: i32 = y0;
    while (wy < y1) : (wy += 1) {
        const tex_y = @as(i32, @intFromFloat(tex_pos)) & (TEX_HEIGHT - 1);
        tex_pos += step_tex;

        const pattern = (tex_x ^ tex_y);
        var col = color;
        if ((pattern & 16) != 0) {
            col = render.colors.darken(col, 0.7);
        }
        render.setPixel(canvas, x, wy, col);
    }
}

fn render_frame(canvas: *Canvas, state: *const State) void {
    const bob_offset = @as(i32, @intFromFloat(@sin(state.walk_timer * BOB_FREQ) * BOB_VIEW_Y));
    const center_y = (@as(f32, @floatFromInt(SCREEN_HEIGHT)) / 2.0) + @as(f32, @floatFromInt(bob_offset));

    var x: i32 = 0;
    while (x < SCREEN_WIDTH) : (x += 1) {
        raycastColumn(canvas, state, x, center_y);
    }

    drawMinimap(canvas, state);
}

fn rotate(state: *State, rot: f32) void {
    const d = state.dir;
    const p = state.plane;
    const cr = @cos(rot);
    const sr = @sin(rot);

    state.dir[0] = d[0] * cr - d[1] * sr;
    state.dir[1] = d[0] * sr + d[1] * cr;
    state.plane[0] = p[0] * cr - p[1] * sr;
    state.plane[1] = p[0] * sr + p[1] * cr;
}

inline fn tryMoveAxis(state: *State, move_step: Vec2, axis: usize) void {
    const next = state.pos[axis] + move_step[axis];

    const map_x = @as(i32, @intFromFloat(if (axis == 0) next else state.pos[0]));
    const map_y = @as(i32, @intFromFloat(if (axis == 1) next else state.pos[1]));

    if (mapCell(map_x, map_y) == 0) {
        state.pos[axis] = next;
    }
}

fn update(state: *State, dt: f32, in: UserInput) void {
    const rotspeed = ROT_SPEED * dt;
    const movespeed = MOVE_SPEED * dt;

    if (in.left) rotate(state, rotspeed);
    if (in.right) rotate(state, -rotspeed);

    var move_dir: Vec2 = .{ 0, 0 };
    var moved = false;

    if (in.forward) {
        move_dir = state.dir;
        moved = true;
    }
    if (in.backward) {
        move_dir = -state.dir;
        moved = true;
    }

    if (in.escape) std.process.exit(0);

    if (moved) {
        state.walk_timer += dt;
        const move_step = move_dir * @as(Vec2, @splat(movespeed));

        tryMoveAxis(state, move_step, 0);
        tryMoveAxis(state, move_step, 1);
    } else {
        if (state.walk_timer > 0) state.walk_timer = 0;
    }
}

pub fn main(min_init: std.process.Init.Minimal) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded: std.Io.Threaded = .init(allocator, .{ .environ = min_init.environ });
    defer threaded.deinit();
    const io = threaded.io();

    try render.init(allocator, SCREEN_WIDTH, SCREEN_HEIGHT);
    defer render.deinit();

    const canvas = render.getCanvas();
    var state = init();
    window.init();

    var fps: render.FpsManager = try .init(io);
    fps.setTargetFPS(120.0);

    var quit = false;
    var timer = try std.time.Timer.start();
    var last_time: u64 = 0;

    while (!quit) {
        quit = window.pollEvents();

        const now = timer.read();
        const dt_ns = now - last_time;
        last_time = now;
        const dt = @as(f32, @floatFromInt(dt_ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));
        const clamped_dt = if (dt > MAX_DT) MAX_DT else dt;

        const user_input = UserInput{
            .forward = input.isKeyDown(.Up) or input.isKeyDown(.W),
            .backward = input.isKeyDown(.Down) or input.isKeyDown(.S),
            .left = input.isKeyDown(.Left) or input.isKeyDown(.A),
            .right = input.isKeyDown(.Right) or input.isKeyDown(.D),
            .escape = input.isKeyDown(.Escape),
        };

        update(&state, clamped_dt, user_input);
        render_frame(canvas, &state);
        window.present();

        try fps.drawFPS(canvas, SCREEN_WIDTH - 80, 0, render.colors.WHITE);
        try fps.waitForNextFrame();
    }
}
