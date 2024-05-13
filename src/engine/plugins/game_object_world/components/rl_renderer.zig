const rl = @import("../../../core/external/raylib.zig");
const log = @import("../../../core/log.zig");
const gow = @import("../game_object_world.zig");
const Transform2d = @import("rl_transform.zig").Transform2d;

pub const Renderer2d = struct {
    const Self = @This();
    color: rl.Color,
    transform: *const Transform2d,

    pub fn create(owner: *const gow.GameObject, color: rl.Color) Self {
        const maybe_transform = owner.getComponentData(Transform2d);
        var transform: *const Transform2d = undefined;
        if (maybe_transform) |t| {
            transform = t;
        } else {
            owner.logger.
                core_log(log.LogLevel.warning, 
                    "Object {d} has Renderer2d Component without a Transform2d Component, it will not be rendered.", 
                    .{owner.id});
            transform = &Transform2d.Empty;
        }

        return Self{
            .color = color,
            .transform = transform,
        };
    }

    pub fn update(self: *Self, _: f32) void {
        rl.DrawRectangle(
            @intFromFloat(self.transform.position.x), 
            @intFromFloat(self.transform.position.y), 
            @intFromFloat(self.transform.scale.x * 50), 
            @intFromFloat(self.transform.scale.y * 50), 
            self.color);
    }
};

pub const Renderer2dComponent = gow.Component(Renderer2d);

