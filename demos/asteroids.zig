const std = @import("std");
const render = @import("renderer");
const window = @import("window");
const input = @import("input");

const math = std.math;

const Vector2 = @Vector(2, f32);

const Vec2 = struct {
    fn init(x: f32, y: f32) Vector2 {
        return .{ x, y };
    }

    fn add(a: Vector2, b: Vector2) Vector2 {
        return a + b;
    }

    fn sub(a: Vector2, b: Vector2) Vector2 {
        return a - b;
    }

    fn scale(v: Vector2, s: f32) Vector2 {
        return v * @as(Vector2, @splat(s));
    }

    fn rotate(v: Vector2, angle: f32) Vector2 {
        const c = math.cos(angle);
        const s = math.sin(angle);
        return .{
            v[0] * c - v[1] * s,
            v[0] * s + v[1] * c,
        };
    }

    fn distance(a: Vector2, b: Vector2) f32 {
        const d = a - b;
        return math.sqrt(d[0] * d[0] + d[1] * d[1]);
    }

    fn normalize(v: Vector2) Vector2 {
        const len = math.sqrt(v[0] * v[0] + v[1] * v[1]);
        return if (len == 0) .{ 0, 0 } else v * @as(Vector2, @splat(1.0 / len));
    }

    fn wrap(v: Vector2, bounds: Vector2) Vector2 {
        return Vec2.init(
            math.mod(f32, v[0], bounds[0]) catch 0,
            math.mod(f32, v[1], bounds[1]) catch 0,
        );
    }
};

const SCALE = 38.0;
const SIZE = Vec2.init(1920, 1080);

var canvas: *render.Canvas = undefined;

const Player = struct {
    pos: Vector2,
    vel: Vector2,
    rot: f32,
    deathTime: f32 = 0.0,

    fn isDead(self: @This()) bool {
        return self.deathTime != 0.0;
    }
};

const Asteroid = struct {
    pos: Vector2,
    vel: Vector2,
    size: AsteroidSize,
    seed: u64,
    remove: bool = false,
};

const AlienSize = enum {
    big,
    small,

    fn collisionSize(self: @This()) f32 {
        return switch (self) {
            .big => SCALE * 0.8,
            .small => SCALE * 0.5,
        };
    }

    fn dirChangeTime(self: @This()) f32 {
        return switch (self) {
            .big => 0.85,
            .small => 0.35,
        };
    }

    fn shotTime(self: @This()) f32 {
        return switch (self) {
            .big => 1.25,
            .small => 0.75,
        };
    }

    fn speed(self: @This()) f32 {
        return switch (self) {
            .big => 3,
            .small => 6,
        };
    }
};

const Alien = struct {
    pos: Vector2,
    dir: Vector2,
    size: AlienSize,
    remove: bool = false,
    lastShot: f32 = 0,
    lastDir: f32 = 0,
};

const ParticleType = enum {
    line,
    dot,
};

const Particle = struct {
    pos: Vector2,
    vel: Vector2,
    ttl: f32,

    values: union(ParticleType) {
        line: struct {
            rot: f32,
            length: f32,
        },
        dot: struct {
            radius: f32,
        },
    },
};

const Projectile = struct {
    pos: Vector2,
    vel: Vector2,
    ttl: f32,
    spawn: f32,
    remove: bool = false,
};

const State = struct {
    now: f32 = 0,
    delta: f32 = 0,
    player: Player,
    asteroids: std.ArrayListUnmanaged(Asteroid),
    asteroids_queue: std.ArrayListUnmanaged(Asteroid),
    particles: std.ArrayListUnmanaged(Particle),
    projectiles: std.ArrayListUnmanaged(Projectile),
    aliens: std.ArrayListUnmanaged(Alien),
    rand: std.Random,
    lives: usize = 0,
    last_score: usize = 0,
    score: usize = 0,
    reset: bool = false,
    last_space_press: bool = false,
};
var state: State = undefined;

fn drawLines(org: Vector2, scale: f32, rot: f32, points: []const Vector2, connect: bool) void {
    const Transformer = struct {
        org: Vector2,
        scale: f32,
        rot: f32,

        fn apply(self: @This(), p: Vector2) Vector2 {
            return Vec2.add(Vec2.scale(Vec2.rotate(p, self.rot), self.scale), self.org);
        }
    };

    const t = Transformer{
        .org = org,
        .scale = scale,
        .rot = rot,
    };

    const bound = if (connect) points.len else (points.len - 1);
    for (0..bound) |i| {
        const p1 = t.apply(points[i]);
        const p2 = t.apply(points[(i + 1) % points.len]);
        const x1: i32 = @intFromFloat(@round(p1[0]));
        const y1: i32 = @intFromFloat(@round(p1[1]));
        const x2: i32 = @intFromFloat(@round(p2[0]));
        const y2: i32 = @intFromFloat(@round(p2[1]));

        render.drawLine(canvas, x1, y1, x2, y2, 1, render.colors.WHITE);
    }
}

const AsteroidSize = enum {
    big,
    medium,
    small,

    fn score(self: @This()) usize {
        return switch (self) {
            .big => 20,
            .medium => 50,
            .small => 100,
        };
    }

    fn size(self: @This()) f32 {
        return switch (self) {
            .big => SCALE * 2.5,
            .medium => SCALE * 1.4,
            .small => SCALE * 0.8,
        };
    }

    fn collisionScale(self: @This()) f32 {
        return switch (self) {
            .big => 0.3,
            .medium => 0.50,
            .small => 0.75,
        };
    }

    fn velocityScale(self: @This()) f32 {
        return switch (self) {
            .big => 0.75,
            .medium => 1.8,
            .small => 2.5,
        };
    }
};

fn drawAsteroid(pos: Vector2, size: AsteroidSize, seed: u64) !void {
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    var points_data: [16]Vector2 = undefined;
    var points_len: usize = 0;
    const n = random.intRangeLessThan(i32, 8, 15);

    for (0..@intCast(n)) |i| {
        var radius = 0.3 + (0.2 * random.float(f32));
        if (random.float(f32) < 0.2) radius -= 0.2;

        const angle: f32 = (@as(f32, @floatFromInt(i)) * (math.tau / @as(f32, @floatFromInt(n)))) + (math.pi * 0.125 * random.float(f32));
        points_data[points_len] = Vec2.scale(Vec2.init(math.cos(angle), math.sin(angle)), radius);
        points_len += 1;
    }

    drawLines(pos, size.size(), 0.0, points_data[0..points_len], true);
}

fn splatLines(allocator: std.mem.Allocator, pos: Vector2, count: usize) !void {
    for (0..count) |_| {
        const angle = math.tau * state.rand.float(f32);
        try state.particles.append(allocator, .{
            .pos = Vec2.add(pos, Vec2.init(state.rand.float(f32) * 3, state.rand.float(f32) * 3)),
            .vel = Vec2.scale(Vec2.init(math.cos(angle), math.sin(angle)), 2.0 * state.rand.float(f32)),
            .ttl = 3.0 + state.rand.float(f32),
            .values = .{
                .line = .{
                    .rot = math.tau * state.rand.float(f32),
                    .length = SCALE * (0.6 + (0.4 * state.rand.float(f32))),
                },
            },
        });
    }
}

fn splatDots(allocator: std.mem.Allocator, pos: Vector2, count: usize) !void {
    for (0..count) |_| {
        const angle = math.tau * state.rand.float(f32);
        try state.particles.append(allocator, .{
            .pos = Vec2.add(pos, Vec2.init(state.rand.float(f32) * 3, state.rand.float(f32) * 3)),
            .vel = Vec2.scale(Vec2.init(math.cos(angle), math.sin(angle)), 2.0 + 4.0 * state.rand.float(f32)),
            .ttl = 0.5 + (0.4 * state.rand.float(f32)),
            .values = .{
                .dot = .{
                    .radius = SCALE * 0.025,
                },
            },
        });
    }
}

fn hitAsteroid(allocator: std.mem.Allocator, a: *Asteroid, impact: ?Vector2) !void {
    state.score += a.size.score();
    a.remove = true;

    try splatDots(allocator, a.pos, 10);

    if (a.size == .small) return;

    for (0..2) |_| {
        const dir = Vec2.normalize(a.vel);
        const size: AsteroidSize = switch (a.size) {
            .big => .medium,
            .medium => .small,
            else => unreachable,
        };

        try state.asteroids_queue.append(allocator, .{
            .pos = a.pos,
            .vel = Vec2.add(
                Vec2.scale(dir, a.size.velocityScale() * 2.2 * state.rand.float(f32)),
                if (impact) |i| Vec2.scale(i, 0.7) else Vec2.init(0, 0),
            ),
            .size = size,
            .seed = state.rand.int(u64),
        });
    }
}

fn update(allocator: std.mem.Allocator) !void {
    if (state.reset) {
        state.reset = false;
        try resetGame(allocator);
    }

    if (!state.player.isDead()) {
        const ROT_SPEED = 2;
        const SHIP_SPEED = 24;

        if (input.isKeyDown(.A) or input.isKeyDown(.Left)) {
            state.player.rot -= state.delta * math.tau * ROT_SPEED;
        }

        if (input.isKeyDown(.D) or input.isKeyDown(.Right)) {
            state.player.rot += state.delta * math.tau * ROT_SPEED;
        }

        const dirAngle = state.player.rot + (math.pi * 0.5);
        const shipDir = Vec2.init(math.cos(dirAngle), math.sin(dirAngle));

        if (input.isKeyDown(.W) or input.isKeyDown(.Up)) {
            state.player.vel = Vec2.add(state.player.vel, Vec2.scale(shipDir, state.delta * SHIP_SPEED));
        }

        const DRAG = 0.015;
        state.player.vel = Vec2.scale(state.player.vel, 1.0 - DRAG);
        state.player.pos = Vec2.add(state.player.pos, state.player.vel);
        state.player.pos = Vec2.wrap(state.player.pos, SIZE);

        const space_down = input.isKeyDown(.Space);
        if (space_down and !state.last_space_press) {
            try state.projectiles.append(allocator, .{
                .pos = Vec2.add(state.player.pos, Vec2.scale(shipDir, SCALE * 0.55)),
                .vel = Vec2.scale(shipDir, 10.0),
                .ttl = 2.0,
                .spawn = state.now,
            });

            state.player.vel = Vec2.add(state.player.vel, Vec2.scale(shipDir, -0.5));
        }
        state.last_space_press = space_down;

        for (state.projectiles.items) |*p| {
            if (!p.remove and (state.now - p.spawn) > 0.15 and Vec2.distance(state.player.pos, p.pos) < (SCALE * 0.7)) {
                p.remove = true;
                state.player.deathTime = state.now;
            }
        }
    }

    for (state.asteroids_queue.items) |a| {
        try state.asteroids.append(allocator, a);
    }
    try state.asteroids_queue.resize(allocator, 0);

    var i: usize = 0;
    while (i < state.asteroids.items.len) {
        var a = &state.asteroids.items[i];
        a.pos = Vec2.wrap(Vec2.add(a.pos, a.vel), SIZE);

        if (!state.player.isDead() and Vec2.distance(a.pos, state.player.pos) < a.size.size() * a.size.collisionScale()) {
            state.player.deathTime = state.now;
            try hitAsteroid(allocator, a, Vec2.normalize(state.player.vel));
        }

        for (state.aliens.items) |*l| {
            if (!l.remove and Vec2.distance(a.pos, l.pos) < a.size.size() * a.size.collisionScale()) {
                l.remove = true;
                try hitAsteroid(allocator, a, Vec2.normalize(state.player.vel));
            }
        }

        for (state.projectiles.items) |*p| {
            if (!p.remove and Vec2.distance(a.pos, p.pos) < a.size.size() * a.size.collisionScale()) {
                p.remove = true;
                try hitAsteroid(allocator, a, Vec2.normalize(p.vel));
            }
        }

        if (a.remove) {
            _ = state.asteroids.swapRemove(i);
        } else i += 1;
    }

    i = 0;
    while (i < state.particles.items.len) {
        var p = &state.particles.items[i];
        p.pos = Vec2.wrap(Vec2.add(p.pos, p.vel), SIZE);

        if (p.ttl > state.delta) {
            p.ttl -= state.delta;
            i += 1;
        } else {
            _ = state.particles.swapRemove(i);
        }
    }

    i = 0;
    while (i < state.projectiles.items.len) {
        var p = &state.projectiles.items[i];
        p.pos = Vec2.wrap(Vec2.add(p.pos, p.vel), SIZE);

        if (!p.remove and p.ttl > state.delta) {
            p.ttl -= state.delta;
            i += 1;
        } else {
            _ = state.projectiles.swapRemove(i);
        }
    }

    i = 0;
    while (i < state.aliens.items.len) {
        var a = &state.aliens.items[i];

        for (state.projectiles.items) |*p| {
            if (!p.remove and (state.now - p.spawn) > 0.15 and Vec2.distance(a.pos, p.pos) < a.size.collisionSize()) {
                p.remove = true;
                a.remove = true;
            }
        }

        if (!a.remove and Vec2.distance(a.pos, state.player.pos) < a.size.collisionSize()) {
            a.remove = true;
            state.player.deathTime = state.now;
        }

        if (!a.remove) {
            if ((state.now - a.lastDir) > a.size.dirChangeTime()) {
                a.lastDir = state.now;
                const angle = math.tau * state.rand.float(f32);
                a.dir = Vec2.init(math.cos(angle), math.sin(angle));
            }

            a.pos = Vec2.wrap(Vec2.add(a.pos, Vec2.scale(a.dir, a.size.speed())), SIZE);

            if ((state.now - a.lastShot) > a.size.shotTime()) {
                a.lastShot = state.now;
                const dir = Vec2.normalize(Vec2.sub(state.player.pos, a.pos));
                try state.projectiles.append(allocator, .{
                    .pos = Vec2.add(a.pos, Vec2.scale(dir, SCALE * 0.55)),
                    .vel = Vec2.scale(dir, 6.0),
                    .ttl = 2.0,
                    .spawn = state.now,
                });
            }
        }

        if (a.remove) {
            try splatDots(allocator, a.pos, 15);
            try splatLines(allocator, a.pos, 4);
            _ = state.aliens.swapRemove(i);
        } else i += 1;
    }

    if (state.player.deathTime == state.now) {
        try splatDots(allocator, state.player.pos, 20);
        try splatLines(allocator, state.player.pos, 5);
    }

    if (state.player.isDead() and (state.now - state.player.deathTime) > 3.0) {
        try resetStage();
    }

    if (state.asteroids.items.len == 0 and state.aliens.items.len == 0) {
        try resetAsteroids(allocator);
    }

    if ((state.last_score / 5000) != (state.score / 5000)) {
        try state.aliens.append(allocator, .{
            .pos = Vec2.init(if (state.rand.boolean()) 0 else SIZE[0] - SCALE, state.rand.float(f32) * SIZE[1]),
            .dir = Vec2.init(0, 0),
            .size = .big,
        });
    }

    if ((state.last_score / 8000) != (state.score / 8000)) {
        try state.aliens.append(allocator, .{
            .pos = Vec2.init(if (state.rand.boolean()) 0 else SIZE[0] - SCALE, state.rand.float(f32) * SIZE[1]),
            .dir = Vec2.init(0, 0),
            .size = .small,
        });
    }

    state.last_score = state.score;
}

fn drawAlien(pos: Vector2, size: AlienSize) void {
    const scale: f32 = switch (size) {
        .big => 1.0,
        .small => 0.5,
    };

    drawLines(pos, SCALE * scale, 0, &.{
        Vec2.init(-0.5, 0.0),
        Vec2.init(-0.3, 0.3),
        Vec2.init(0.3, 0.3),
        Vec2.init(0.5, 0.0),
        Vec2.init(0.3, -0.3),
        Vec2.init(-0.3, -0.3),
        Vec2.init(-0.5, 0.0),
        Vec2.init(0.5, 0.0),
    }, false);

    drawLines(pos, SCALE * scale, 0, &.{
        Vec2.init(-0.2, -0.3),
        Vec2.init(-0.1, -0.5),
        Vec2.init(0.1, -0.5),
        Vec2.init(0.2, -0.3),
    }, false);
}

const SHIP_EDGES = [_]Vector2{
    Vec2.init(-0.4, -0.5),
    Vec2.init(0.0, 0.5),
    Vec2.init(0.4, -0.5),
    Vec2.init(0.3, -0.4),
    Vec2.init(-0.3, -0.4),
};

fn render_frame(allocator: std.mem.Allocator) !void {
    for (0..state.lives) |i| {
        drawLines(Vec2.init(SCALE + (@as(f32, @floatFromInt(i)) * SCALE), SCALE), SCALE, -math.pi, &SHIP_EDGES, true);
    }

    const score_string = try std.fmt.allocPrint(allocator, "{d}", .{state.score});
    defer allocator.free(score_string);
    render.drawText(canvas, score_string, SIZE[0] - SCALE, SCALE, 3, render.colors.WHITE, .right);

    if (!state.player.isDead()) {
        drawLines(state.player.pos, SCALE, state.player.rot, &SHIP_EDGES, true);

        if ((input.isKeyDown(.W) or input.isKeyDown(.Up)) and @mod(@as(i32, @intFromFloat(state.now * 20)), 2) == 0) {
            drawLines(state.player.pos, SCALE, state.player.rot, &.{ Vec2.init(-0.3, -0.4), Vec2.init(0.0, -1.0), Vec2.init(0.3, -0.4) }, true);
        }
    }

    for (state.asteroids.items) |a| {
        try drawAsteroid(a.pos, a.size, a.seed);
    }

    for (state.aliens.items) |a| {
        drawAlien(a.pos, a.size);
    }

    for (state.particles.items) |p| {
        switch (p.values) {
            .line => |line| {
                drawLines(p.pos, line.length, line.rot, &.{ Vec2.init(-0.5, 0), Vec2.init(0.5, 0) }, true);
            },
            .dot => |dot| {
                render.drawCircle(canvas, @as(i32, @intFromFloat(@round(p.pos[0]))), @as(i32, @intFromFloat(@round(p.pos[1]))), @as(i32, @intFromFloat(@round(dot.radius))), 2, render.colors.WHITE);
            },
        }
    }

    for (state.projectiles.items) |p| {
        render.drawCircle(canvas, @as(i32, @intFromFloat(@round(p.pos[0]))), @as(i32, @intFromFloat(@round(p.pos[1]))), @as(i32, @intFromFloat(@round(@max(SCALE * 0.05, 1)))), 2, render.colors.WHITE);
    }
}

fn resetAsteroids(allocator: std.mem.Allocator) !void {
    try state.asteroids.resize(allocator, 0);

    for (0..(30 + state.score / 1500)) |_| {
        const angle = math.tau * state.rand.float(f32);
        const size = state.rand.enumValue(AsteroidSize);
        try state.asteroids_queue.append(allocator, .{ .pos = Vec2.init(
            state.rand.float(f32) * SIZE[0],
            state.rand.float(f32) * SIZE[1],
        ), .vel = Vec2.scale(Vec2.init(math.cos(angle), math.sin(angle)), size.velocityScale() * 3.0 * state.rand.float(f32)), .size = size, .seed = state.rand.int(u64) });
    }
}

fn resetGame(allocator: std.mem.Allocator) !void {
    state.lives = 3;
    state.score = 0;

    try resetStage();
    try resetAsteroids(allocator);
}

fn resetStage() !void {
    if (state.player.isDead()) {
        if (state.lives == 0) {
            state.reset = true;
        } else state.lives -= 1;
    }

    state.player.deathTime = 0.0;
    state.player = .{
        .pos = Vec2.scale(SIZE, 0.5),
        .vel = Vec2.init(0, 0),
        .rot = 0.0,
    };
}

pub fn main(min_init: std.process.Init.Minimal) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded: std.Io.Threaded = .init(allocator, .{ .environ = min_init.environ });
    defer threaded.deinit();
    const io = threaded.io();

    const clock = try std.Io.Clock.now(.real, io);
    const seed: u64 = @as(u64, @intCast(clock.toMilliseconds()));

    var prng = std.Random.DefaultPrng.init(seed);

    const rand = prng.random();

    try render.init(allocator, @as(usize, @intFromFloat(SIZE[0])), @as(usize, @intFromFloat(SIZE[1])));
    defer render.deinit();

    canvas = render.getCanvas();

    window.init();
    var fps: render.FpsManager = try .init(io);
    fps.setTargetFPS(120.0);

    var quit = false;
    var timer = try std.time.Timer.start();
    var last_time: u64 = 0;

    state = .{
        .player = .{ .pos = Vec2.scale(SIZE, 0.5), .vel = Vec2.init(0, 0), .rot = 0.0 },
        .asteroids = .{},
        .asteroids_queue = .{},
        .particles = .{},
        .projectiles = .{},
        .aliens = .{},
        .rand = rand,
    };
    defer state.asteroids.deinit(allocator);
    defer state.asteroids_queue.deinit(allocator);
    defer state.particles.deinit(allocator);
    defer state.projectiles.deinit(allocator);
    defer state.aliens.deinit(allocator);

    try resetGame(allocator);

    while (!quit) {
        quit = window.pollEvents();

        if (input.isKeyDown(.Escape)) std.process.exit(0);

        const now = timer.read();
        const dt_ns = now - last_time;
        last_time = now;
        const dt = @as(f32, @floatFromInt(dt_ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));

        const clamped_dt = if (dt > 0.1) 0.1 else dt;
        state.delta = clamped_dt;
        state.now += state.delta;

        try update(allocator);

        render.fillCanvas(canvas, render.colors.BLACK);

        try render_frame(allocator);

        window.present();

        try fps.drawFPS(canvas, @as(i32, @intFromFloat(SIZE[0])) - 80, 0, render.colors.WHITE);
        try fps.waitForNextFrame();
    }
}
