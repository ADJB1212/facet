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
const MOUSE_SENS = 0.0025;
const PITCH_SENS = 0.0022;
const MAX_PITCH = std.math.degreesToRadians(45.0);
const PITCH_PIXELS = 140.0;
const RECOIL_KICK = std.math.degreesToRadians(2.5);
const RECOIL_RETURN = 12.0;

const BOB_FREQ = 10.0;
const BOB_VIEW_Y = 3.0;
const WEAPON_BOB = 5.0;

const HIT_MARK_TIME = 0.12;
const FIRE_COOLDOWN = 0.2;
const MUZZLE_FLASH_TIME = 0.08;

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
    mouse_dx: f32,
    mouse_dy: f32,
    fire: bool,
};

const State = struct {
    pos: Vec2,
    dir: Vec2,
    plane: Vec2,
    walk_timer: f32,
    pitch: f32,
    hit_timer: f32,
    last_hit_pos: Vec2,
    recoil: f32,
    fire_cooldown: f32,
    muzzle_timer: f32,
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

fn isBorderCell(x: i32, y: i32) bool {
    return x == 0 or y == 0 or x == MAP_SIZE - 1 or y == MAP_SIZE - 1;
}

fn raycastCell(x: i32, y: i32) u8 {
    if (mapIndex(x, y)) |idx| {
        if (isBorderCell(x, y)) return MAPDATA[idx];
        return 0;
    }
    return 1;
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

const RayHit = struct {
    hit: bool,
    pos: Vec2,
    cell: Vec2i,
    val: u8,
    dist: f32,
    side: i32,
};

fn castRay(pos: Vec2, dir: Vec2) RayHit {
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

        val = raycastCell(ipos[0], ipos[1]);
        if (val > 0) hit = true;
    }

    var dperp: f32 = if (side == 0) (sidedist[0] - deltadist[0]) else (sidedist[1] - deltadist[1]);
    if (dperp < MIN_WALL_DIST) dperp = MIN_WALL_DIST;

    const hit_pos = pos + dir * @as(Vec2, @splat(dperp));
    return .{
        .hit = true,
        .pos = hit_pos,
        .cell = ipos,
        .val = val,
        .dist = dperp,
        .side = side,
    };
}

fn init() State {
    return .{
        .pos = .{ 2.0, 2.0 },
        .dir = normalize(.{ -1.0, 0.1 }),
        .plane = .{ 0.0, 0.66 },
        .walk_timer = 0.0,
        .pitch = 0.0,
        .hit_timer = 0.0,
        .last_hit_pos = .{ 0.0, 0.0 },
        .recoil = 0.0,
        .fire_cooldown = 0.0,
        .muzzle_timer = 0.0,
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

    const dir_end_x = px + @as(i32, @intFromFloat(state.dir[0] * scale_f * 1.5));
    const dir_end_y = py + @as(i32, @intFromFloat(state.dir[1] * scale_f * 1.5));
    render.drawLine(canvas, px, py, dir_end_x, dir_end_y, 1, render.colors.WHITE);

    if (state.hit_timer > 0.0) {
        const hx = MINIMAP_OFFSET_X + @as(i32, @intFromFloat(state.last_hit_pos[0] * scale_f));
        const hy = MINIMAP_OFFSET_Y + @as(i32, @intFromFloat(state.last_hit_pos[1] * scale_f));
        render.drawCircle(canvas, hx, hy, 2, 1, render.colors.YELLOW);
    }
}

fn drawHud(canvas: *Canvas, state: *const State, center_y: f32) void {
    const cross_x = SCREEN_WIDTH / 2;
    const cross_y = @as(i32, @intFromFloat(center_y));
    const cross_size = 6;
    const gap = 3;

    render.drawLine(canvas, cross_x - cross_size - gap, cross_y, cross_x - gap, cross_y, 1, render.colors.WHITE);
    render.drawLine(canvas, cross_x + gap, cross_y, cross_x + cross_size + gap, cross_y, 1, render.colors.WHITE);
    render.drawLine(canvas, cross_x, cross_y - cross_size - gap, cross_x, cross_y - gap, 1, render.colors.WHITE);
    render.drawLine(canvas, cross_x, cross_y + gap, cross_x, cross_y + cross_size + gap, 1, render.colors.WHITE);

    if (state.hit_timer > 0.0) {
        render.drawLine(canvas, cross_x - 8, cross_y - 8, cross_x - 3, cross_y - 3, 1, render.colors.YELLOW);
        render.drawLine(canvas, cross_x + 8, cross_y - 8, cross_x + 3, cross_y - 3, 1, render.colors.YELLOW);
        render.drawLine(canvas, cross_x - 8, cross_y + 8, cross_x - 3, cross_y + 3, 1, render.colors.YELLOW);
        render.drawLine(canvas, cross_x + 8, cross_y + 8, cross_x + 3, cross_y + 3, 1, render.colors.YELLOW);
    }

    const bob_x = @as(i32, @intFromFloat(@sin(state.walk_timer * BOB_FREQ) * WEAPON_BOB));
    const bob_y = @as(i32, @intFromFloat(@abs(@cos(state.walk_timer * BOB_FREQ)) * WEAPON_BOB));
    const gun_w = 120;
    const gun_h = 70;
    const gun_x = (SCREEN_WIDTH / 2) - (gun_w / 2) + bob_x;
    const gun_y = SCREEN_HEIGHT - gun_h - 10 + bob_y;

    render.drawRect(canvas, gun_x, gun_y, gun_w, gun_h, 0xFF2B2B2B);
    render.drawRect(canvas, gun_x + 10, gun_y + 10, gun_w - 20, gun_h - 20, 0xFF4A4A4A);
    render.drawRect(canvas, gun_x + gun_w - 25, gun_y + 20, 16, 16, render.colors.RED);

    if (state.muzzle_timer > 0.0) {
        const alpha = @as(u8, @intFromFloat(std.math.clamp(state.muzzle_timer / MUZZLE_FLASH_TIME, 0.0, 1.0) * 180.0));
        const flash = render.colors.rgba(255, 240, 200, alpha);
        render.drawCircle(canvas, cross_x, cross_y, 24, 2, flash);
        render.drawCircle(canvas, cross_x + 40, cross_y + 50, 10, 2, flash);
    }
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
    const pitch_total = state.pitch + state.recoil;
    const center_y = (@as(f32, @floatFromInt(SCREEN_HEIGHT)) / 2.0) + @as(f32, @floatFromInt(bob_offset)) + (pitch_total * PITCH_PIXELS);

    var x: i32 = 0;
    while (x < SCREEN_WIDTH) : (x += 1) {
        raycastColumn(canvas, state, x, center_y);
    }

    drawMinimap(canvas, state);
    drawHud(canvas, state, center_y);
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

    if (in.mouse_dx != 0.0) {
        rotate(state, -in.mouse_dx * MOUSE_SENS);
    }

    if (in.mouse_dy != 0.0) {
        state.pitch = std.math.clamp(state.pitch - in.mouse_dy * PITCH_SENS, -MAX_PITCH, MAX_PITCH);
    }

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

    if (state.fire_cooldown > 0.0) {
        state.fire_cooldown = @max(0.0, state.fire_cooldown - dt);
    }
    if (state.muzzle_timer > 0.0) {
        state.muzzle_timer = @max(0.0, state.muzzle_timer - dt);
    }
    if (state.hit_timer > 0.0) {
        state.hit_timer = @max(0.0, state.hit_timer - dt);
    }
    if (state.recoil > 0.0) {
        state.recoil = @max(0.0, state.recoil - RECOIL_RETURN * dt);
    }

    if (in.fire and state.fire_cooldown <= 0.0) {
        state.fire_cooldown = FIRE_COOLDOWN;
        state.muzzle_timer = MUZZLE_FLASH_TIME;
        state.recoil = @min(state.recoil + RECOIL_KICK, MAX_PITCH);

        const hit = castRay(state.pos, state.dir);
        if (hit.hit) {
            state.hit_timer = HIT_MARK_TIME;
            state.last_hit_pos = hit.pos;
        }
    }
}

pub fn main(main_init: std.process.Init) !void {
    const arena: std.mem.Allocator = main_init.arena.allocator();

    var threaded: std.Io.Threaded = .init(arena, .{ .environ = main_init.minimal.environ });
    defer threaded.deinit();
    const io = threaded.io();

    try render.init(arena, SCREEN_WIDTH, SCREEN_HEIGHT);
    defer render.deinit();

    const canvas = render.getCanvas();
    var state = init();
    window.init();

    var fps: render.FpsManager = try .init(io);
    fps.setTargetFPS(120.0);

    var quit = false;
    var timer = try std.time.Timer.start();
    var last_time: u64 = 0;
    var last_mouse_pos = input.getMousePosition();
    var prev_mouse_down = false;

    while (!quit) {
        quit = window.pollEvents();

        const mouse_pos = input.getMousePosition();
        const mouse_dx = mouse_pos.x - last_mouse_pos.x;
        const mouse_dy = mouse_pos.y - last_mouse_pos.y;
        last_mouse_pos = mouse_pos;

        const now = timer.read();
        const dt_ns = now - last_time;
        last_time = now;
        const dt = @as(f32, @floatFromInt(dt_ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));
        const clamped_dt = if (dt > MAX_DT) MAX_DT else dt;

        const mouse_down = input.isMouseDown(.Left);
        const fire = mouse_down and !prev_mouse_down;
        prev_mouse_down = mouse_down;

        const user_input = UserInput{
            .forward = input.isKeyDown(.Up) or input.isKeyDown(.W),
            .backward = input.isKeyDown(.Down) or input.isKeyDown(.S),
            .left = input.isKeyDown(.Left) or input.isKeyDown(.A),
            .right = input.isKeyDown(.Right) or input.isKeyDown(.D),
            .escape = input.isKeyDown(.Escape),
            .fire = fire,
            .mouse_dx = mouse_dx,
            .mouse_dy = mouse_dy,
        };

        update(&state, clamped_dt, user_input);
        render_frame(canvas, &state);
        window.present();

        try fps.drawFPS(canvas, SCREEN_WIDTH - 70, 5, render.colors.WHITE);
        try fps.waitForNextFrame();
    }
}
