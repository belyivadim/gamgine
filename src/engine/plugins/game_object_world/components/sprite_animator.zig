const std = @import("std");
const rl = @import("../../../core/external/raylib.zig");
const gow = @import("../game_object_world.zig");
const Renderer2d = @import("rl_renderer.zig").Renderer2d;
const log = @import("../../../core/log.zig");

pub const SpriteAnimation = struct {
    const Self = @This();

    name: []const u8, 
    fps: i32,
    number_of_frames: i32,
    frame_width: f32,
    frame_height: f32,
    loop: bool,

    renderer: *Renderer2d,

    frame_counter: i32 = 0,
    current_frame: i32 = 0,

    done: bool = false,

    pub fn create(
        name: []const u8, 
        fps: i32, number_of_frames: i32, 
        frame_width: f32, frame_height: f32, 
        loop: bool,
        renderer: *Renderer2d
    ) Self {
        return Self{
            .name = name,
            .fps = fps,
            .number_of_frames = number_of_frames,
            .frame_width = frame_width,
            .frame_height = frame_height,
            .loop = loop,
            .renderer = renderer,
        };
    }

    pub fn play(self: *Self) void {
        self.frame_counter += 1;

        if (self.frame_counter >= @divFloor(60, self.fps)) {
            self.frame_counter = 0;
            self.current_frame += 1;

            if (self.current_frame >= self.number_of_frames) {
                self.current_frame = 0;
                self.done = true;
            }

            const frame_x = @as(f32, @floatFromInt(self.current_frame)) * self.frame_width;
            self.renderer.frame_rec.x = frame_x;
        }
    }

    pub fn reset(self: *Self) void {
        self.done = false;
        self.current_frame = 0;
        self.frame_counter = 0;
    }
};

pub const SpriteAnimator = struct {
    const Self = @This();

    animations: std.StringHashMap(SpriteAnimation),
    current_animation: ?*SpriteAnimation = null,

    pub fn create(allocator: std.mem.Allocator) Self {
        return Self{
            .animations = std.StringHashMap(SpriteAnimation).init(allocator),
        };
    }

    pub fn start(_: *Self, _: *gow.GameObject) void {
    }

    pub fn update(self: *Self, _: f32, _: *gow.GameObject) void {
        if (self.current_animation) |anim| {
            if (!anim.loop and anim.done) {
                self.current_animation = null;
                return;
            }

            anim.play();
        }
    }

    pub fn destroy(self: *Self, _: *gow.GameObject) void {
        self.animations.deinit();
    }

    pub fn clone(self: *const Self) Self {
        return Self.create(self.animations.allocator);
    }

    pub fn setActive(_: *Self, _: bool) void {
    }

    pub fn playAnimation(self: *Self, name: []const u8) void {
        const maybe_anim = self.animations.getPtr(name);
        if (maybe_anim != null) {
            self.current_animation = maybe_anim;
        } else {
            log.Logger.core_log(log.LogLevel.warning, "SpriteAnimator: animation {s} is not found", .{name});
        }
    }

    pub fn resetAnimation(self: *Self, name: []const u8) void {
        const maybe_anim = self.animations.getPtr(name);
        if (maybe_anim) |anim| {
            anim.reset();
        } else {
            log.Logger.core_log(log.LogLevel.warning, "SpriteAnimator: animation {s} is not found", .{name});
        }
    }

    pub fn resetAndPlayAnimation(self: *Self, name: []const u8) void {
        const maybe_anim = self.animations.getPtr(name);
        if (maybe_anim) |anim| {
            anim.reset();
            self.current_animation = anim;
        } else {
            log.Logger.core_log(log.LogLevel.warning, "SpriteAnimator: animation {s} is not found", .{name});
        }
    }

    pub fn addAnimation(self: *Self, animation: SpriteAnimation) void {
        self.animations.put(animation.name, animation) catch |err| {
            log.Logger.core_log(log.LogLevel.err, "SpriteAnimator: could not add animation {s}: {any}", .{animation.name, err});
        };
    }
};
