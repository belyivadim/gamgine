const std = @import("std");
const rl = @import("../../../core/external/raylib.zig");
const log = @import("../../../core/log.zig");
const gow = @import("../game_object_world.zig");
const Transform2d = @import("rl_transform.zig").Transform2d;
const RendererPlugin = @import("../rl_renderer.zig").RlRendererPlugin;
const TextureAsset = @import("../../../services/assets.zig").TextureAsset;

pub const Renderer2d = struct {
    const Self = @This();

    texture_asset: *TextureAsset,
    layer: i32,
    transform: *const Transform2d,
    renderer_plugin: *RendererPlugin,

    is_active: bool,

    pub fn create(texture_asset: *TextureAsset, layer: i32) Self { 
        return Self{
            .texture_asset = texture_asset,
            .transform = &Transform2d.Empty,
            .layer = layer,
            .renderer_plugin = undefined,
            .is_active = true,
        };
    }

    pub fn start(self: *Self, owner: *gow.GameObject) void {
        const maybe_transform = owner.getComponentData(Transform2d);
        if (maybe_transform) |t| {
            self.transform = t;
        } else {
            log.Logger.
                core_log(log.LogLevel.warning, 
                    "Object {d} has Renderer2d Component without a Transform2d Component, by default it will be rendered at position (0,0).", 
                    .{owner.id});
        }


        self.renderer_plugin = owner.app.queryPlugin(RendererPlugin) orelse {
            log.Logger.core_log(log.LogLevel.fatal, 
                "RlRendererPlugin is required for rl_renderer.Renderer2d to work. Shutting down.", .{});
            std.process.exit(1);
        };

        if (self.is_active) {
            self.renderer_plugin.addRenderer2d(self);
        }
    }

    pub fn update(self: *Self, _: f32, _: *gow.GameObject) void {
        _ = self;
    }

    pub fn destroy(self: *Self, _: *gow.GameObject) void {
        self.renderer_plugin.removeRenderer2d(self);
    }

    pub fn clone(self: *const Self) Self {
        return Renderer2d.create(self.texture_asset, self.layer);
    }

    pub fn setActive(self: *Self, active: bool) void {
        if (self.is_active == active) return;

        self.is_active = active;

        if (active) {
            self.renderer_plugin.addRenderer2d(self);
        } else {
            self.renderer_plugin.removeRenderer2d(self);
        }
    }

    pub fn getTextureImage(self: *const Self) rl.Image {
        return rl.LoadImageFromTexture(self.texture_asset.texture);
    }
};

pub const Renderer2dComponent = gow.Component(Renderer2d);



