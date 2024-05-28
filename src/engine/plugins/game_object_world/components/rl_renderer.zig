const std = @import("std");
const rl = @import("../../../core/external/raylib.zig");
const log = @import("../../../core/log.zig");
const gow = @import("../game_object_world.zig");
const Transform2d = @import("rl_transform.zig").Transform2d;
const RendererPlugin = @import("../rl_renderer.zig").RlRendererPlugin;
const IRenderer2d = @import("../rl_renderer.zig").IRenderer2d;
const TextureAsset = @import("../../../services/assets.zig").TextureAsset;

pub const Renderer2d = struct {
    const Self = @This();

    irenderer: IRenderer2d,

    texture_asset: *TextureAsset,
    frame_rec: rl.Rectangle,
    tint: rl.Color,
    transform: *const Transform2d,
    renderer_plugin: *RendererPlugin,

    is_active: bool,

    pub fn create(texture_asset: *TextureAsset, layer: i32, tint: rl.Color, camera_mode_required: bool) Self { 
        const frame_rec = rl.Rectangle{
            .x = 0, 
            .y = 0, 
            .width =  @floatFromInt(texture_asset.texture.width), 
            .height = @floatFromInt(texture_asset.texture.height),
        };
        return Self.createWithCustomFrameRec(texture_asset, layer, tint, camera_mode_required, frame_rec);
    }

    pub fn createWithCustomFrameRec(
        texture_asset: *TextureAsset, layer: i32, tint: rl.Color, 
        camera_mode_required: bool, frame_rec: rl.Rectangle
    ) Self {
        return Self{
            .irenderer = IRenderer2d{
                .renderFn = render,
                .layer = layer,
                .camera_mode_required = camera_mode_required,
            },
            .texture_asset = texture_asset,
            .frame_rec = frame_rec,
            .transform = &Transform2d.Empty,
            .tint = tint,
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
            self.renderer_plugin.addRenderer2d(&self.irenderer);
        }
    }

    pub fn update(self: *Self, _: f32, _: *gow.GameObject) void {
        _ = self;
    }

    pub fn destroy(self: *Self, _: *gow.GameObject) void {
        self.renderer_plugin.removeRenderer2d(&self.irenderer);
    }

    pub fn clone(self: *const Self) Self {
        return Renderer2d.createWithCustomFrameRec(
            self.texture_asset, self.irenderer.layer, self.tint, 
            self.irenderer.camera_mode_required, self.frame_rec);
    }

    pub fn setActive(self: *Self, active: bool) void {
        if (self.is_active == active) return;

        self.is_active = active;

        if (active) {
            self.renderer_plugin.addRenderer2d(&self.irenderer);
        } else {
            self.renderer_plugin.removeRenderer2d(&self.irenderer);
        }
    }

    pub fn getTextureImage(self: *const Self) rl.Image {
        return rl.LoadImageFromTexture(self.texture_asset.texture);
    }

    fn render(irenderer: *IRenderer2d, _: f32) void {
        const self: *Self = @fieldParentPtr("irenderer", irenderer);

        const dest = rl.Rectangle{
            .x = self.transform.position.x,
            .y = self.transform.position.y,
            .width =  self.frame_rec.width * self.transform.scale.x,
            .height = self.frame_rec.height * self.transform.scale.y,
        };

        const origin = rl.Vector2{.x = 0, .y = 0};

        rl.DrawTexturePro(
            self.texture_asset.texture,
            self.frame_rec,
            dest,
            origin,
            self.transform.rotation,
            self.tint
        );
    }
};

pub const Renderer2dComponent = gow.Component(Renderer2d);



