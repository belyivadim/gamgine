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

    frame_counter: i32 = 0,
    current_frame: i32 = 0,

    done: bool = false,

    pub fn create(
        name: []const u8, 
        fps: i32, number_of_frames: i32, 
        frame_width: f32, frame_height: f32, 
        loop: bool,
    ) Self {
        return Self{
            .name = name,
            .fps = fps,
            .number_of_frames = number_of_frames,
            .frame_width = frame_width,
            .frame_height = frame_height,
            .loop = loop,
        };
    }

    pub fn play(self: *Self, renderer: *Renderer2d) void {
        self.frame_counter += 1;

        if (self.frame_counter >= @divFloor(60, self.fps)) {
            self.frame_counter = 0;
            self.current_frame += 1;

            if (self.current_frame >= self.number_of_frames) {
                self.current_frame = 0;
                self.done = true;
            }

            const frame_x = @as(f32, @floatFromInt(self.current_frame)) * self.frame_width;
            renderer.frame_rec.x = frame_x;
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
    current_animation: *SpriteAnimation,
    renderer: *Renderer2d,

    pub fn create(allocator: std.mem.Allocator, initial_animation: SpriteAnimation) Self {
        var animator = Self{
            .animations = std.StringHashMap(SpriteAnimation).init(allocator),
            .renderer = undefined,
            .current_animation = undefined,
        };

        animator.addAnimation(initial_animation.name, initial_animation);
        animator.current_animation = animator.animations.getPtr(initial_animation.name) orelse unreachable;

        return animator;
    }


    /// sets first animation from @animations as initial animation
    pub fn createWithManyAnimations(allocator: std.mem.Allocator, animations: []const SpriteAnimation) Self {
        std.debug.assert(animations.len > 0);

        var animator = Self{
            .animations = std.StringHashMap(SpriteAnimation).init(allocator),
            .renderer = undefined,
            .current_animation = undefined,
        };

        for (animations) |anim| {
            animator.addAnimation(anim);
        }

        animator.current_animation = animator.animations.getPtr(animations[0].name) orelse unreachable;

        return animator;
    }

    pub fn start(self: *Self, owner: *gow.GameObject) void {
        self.renderer = owner.getComponentDataMut(Renderer2d) orelse {
            log.Logger.core_log(log.LogLevel.err, "SpriteAnimator: owner does not have a Renderer2d component.\nExiting...", .{});
            std.process.exit(1);
        };

        self.current_animation.play(self.renderer);
    }

    pub fn update(self: *Self, _: f32, _: *gow.GameObject) void {
        if (!self.current_animation.loop and self.current_animation.done) {
            return;
        }

        self.current_animation.play(self.renderer);
    }

    pub fn destroy(self: *Self, _: *gow.GameObject) void {
        self.animations.deinit();
    }

    pub fn clone(self: *const Self) Self {
        return Self{
            .animations = self.animations.clone() catch |err| {
                log.Logger.core_log(log.LogLevel.err, "SpriteAnimation: could not be cloned: {any}\nExiting...", .{err});
                std.process.exit(1);
            },
            .current_animation = self.current_animation,
            .renderer = undefined, // will be set in start
        };
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
