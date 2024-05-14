const std = @import("std");
const rl = @import("../../../core/external/raylib.zig");
const log = @import("../../../core/log.zig");
const gow = @import("../game_object_world.zig");
const Transform2d = @import("rl_transform.zig").Transform2d;

pub const Renderer2d = struct {
    const Self = @This();
    texture: rl.Texture,
    transform: *const Transform2d,

    pub fn create(texture: rl.Texture) Self { 
        return Self{
            .texture = texture,
            .transform = &Transform2d.Empty,
        };
    }

    pub fn start(self: *Self, owner: *gow.GameObject) void {
        const maybe_transform = owner.getComponentData(Transform2d);
        if (maybe_transform) |t| {
            self.transform = t;
        } else {
            owner.logger.
                core_log(log.LogLevel.warning, 
                    "Object {d} has Renderer2d Component without a Transform2d Component, by default it will be rendered at position (0,0).", 
                    .{owner.id});
        }
    }

    pub fn update(self: *Self, _: f32, _: *gow.GameObject) void {
        rl.DrawTextureEx(self.texture, self.transform.position, self.transform.rotation, 1, rl.WHITE);
    }

    pub fn destroy(self: *Self, _: *gow.GameObject) void {
        rl.UnloadTexture(self.texture);
    }


    pub fn createBlankTextureWithColor(color: rl.Color, width: i32, height: i32, allocator: std.mem.Allocator) ?rl.Texture {
        const pixels = allocator.alloc(rl.Color, @intCast(width * height)) catch {
            return null;
        };
        defer allocator.free(pixels);
        @memset(pixels, color);

        const img = rl.Image{
            .data = @ptrCast(pixels),
            .width = width,
            .height = height,
            .mipmaps = 1,
            .format = rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        };

        return rl.LoadTextureFromImage(img);
    }
};

pub const Renderer2dComponent = gow.Component(Renderer2d);



