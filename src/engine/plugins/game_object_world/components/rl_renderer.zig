const std = @import("std");
const rl = @import("../../../core/external/raylib.zig");
const log = @import("../../../core/log.zig");
const gow = @import("../game_object_world.zig");
const Transform2d = @import("rl_transform.zig").Transform2d;
const RendererPlugin = @import("../rl_renderer.zig").RlRendererPlugin;

pub const Renderer2d = struct {
    const Self = @This();

    texture: rl.Texture,
    layer: i32,
    transform: *const Transform2d,
    renderer_plugin: *RendererPlugin,

    pub fn create(texture: rl.Texture, layer: i32) Self { 
        return Self{
            .texture = texture,
            .transform = &Transform2d.Empty,
            .layer = layer,
            .renderer_plugin = undefined,
        };
    }

    pub fn start(self: *Self, owner: *gow.GameObject) void {
        const maybe_transform = owner.getComponentData(Transform2d);
        if (maybe_transform) |t| {
            self.transform = t;
        } else {
            owner.app.logger.
                core_log(log.LogLevel.warning, 
                    "Object {d} has Renderer2d Component without a Transform2d Component, by default it will be rendered at position (0,0).", 
                    .{owner.id});
        }


        self.renderer_plugin = owner.app.queryPlugin(RendererPlugin) orelse {
            owner.app.logger.core_log(log.LogLevel.fatal, 
                "RlRendererPlugin is required for rl_renderer.Renderer2d to work. Shutting down.", .{});
            std.process.exit(1);
        };

        self.renderer_plugin.addRenderer2d(self);
    }

    pub fn update(self: *Self, _: f32, _: *gow.GameObject) void {
        _ = self;
    }

    pub fn destroy(self: *Self, _: *gow.GameObject) void {
        self.renderer_plugin.removeRenderer2d(self);
        rl.UnloadTexture(self.texture);
    }


    pub fn clone(self: *const Self) Self {
        const new_texture = rl.LoadTextureFromImage(rl.LoadImageFromTexture(self.texture));
        return Renderer2d.create(new_texture, self.layer);
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



