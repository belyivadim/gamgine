const rl = @import("../../../core/external/raylib.zig");
const gow = @import("../game_object_world.zig");

pub const Transform2d = struct {
    const Self = @This();

    pub const Empty = create(rl.Vector2Zero(), 0, rl.Vector2Zero());

    position: rl.Vector2,
    rotation: f32, // as angles
    scale: rl.Vector2,

    pub fn create(position: rl.Vector2, rotation: f32, scale: rl.Vector2) Self {
        return Self{
            .position = position,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn translate(self: *Self, translation: rl.Vector2) void {
        self.position = rl.Vector2Add(self.position, translation);
    }

    pub fn rotate(self: *Self, angle: f32) void {
        self.rotation += angle;
    }

    pub fn scaleIt(self: *Self, factor: rl.Vector2) void {
        self.scale = rl.Vector2Multiply(self.scale, factor);
    }

    pub fn getRotationRad(self: *const Self) f32 {
        return self.rotation * rl.DEG2RAD;
    }


    pub fn start(_: *Self, _: *gow.GameObject) void {
    }

    pub fn update(_: *Self, _: f32, _: *gow.GameObject) void {
    }

    pub fn destroy(_: *Self, _: *gow.GameObject) void {
    }

    pub fn clone(self: *const Self) Self {
        return self.*;
    }

    pub fn setActive(_: *Self, _: bool) void {
    }
};

pub const Transform2dComponent = gow.Component(Transform2d);
