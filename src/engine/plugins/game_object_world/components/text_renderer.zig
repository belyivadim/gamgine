const std = @import("std");
const rl = @import("../../../core/external/raylib.zig");
const log = @import("../../../core/log.zig");
const gow = @import("../game_object_world.zig");
const Transform2d = @import("rl_transform.zig").Transform2d;
const RendererPlugin = @import("../rl_renderer.zig").RlRendererPlugin;
const IRenderer2d = @import("../rl_renderer.zig").IRenderer2d;
const assets = @import("../../../services/assets.zig");

pub const TextRenderer = struct {
    const Self = @This();

    irenderer: IRenderer2d,

    text_str: [:0] const u8,
    font_asset: *assets.FontAsset,
    font_size: f32,
    spacing: f32,
    color: rl.Color,
    align_hor_center: bool,

    transform: *const Transform2d,
    renderer_plugin: *RendererPlugin,

    is_active: bool,

    pub fn create(
        text_str: [:0] const u8, 
        font_asset: *assets.FontAsset,
        font_size: f32,
        spacing: f32,
        layer: i32, 
        color: rl.Color, 
        align_hor_center: bool,
        camera_mode_required: bool
    ) Self { 
        return Self{
            .irenderer = IRenderer2d{
                .renderFn = render,
                .layer = layer,
                .camera_mode_required = camera_mode_required,
            },
            .text_str = text_str,
            .font_asset = font_asset,
            .font_size = font_size,
            .spacing = spacing,
            .transform = &Transform2d.Empty,
            .color = color,
            .align_hor_center = align_hor_center,
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
                    "Object {d} has TextRenderer Component without a Transform2d Component, by default it will be rendered at position (0,0).", 
                    .{owner.id});
        }


        self.renderer_plugin = owner.app.queryPlugin(RendererPlugin) orelse {
            log.Logger.core_log(log.LogLevel.fatal, 
                "RlRendererPlugin is required for TextRenderer to work. Shutting down.", .{});
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
        return TextRenderer.create(
            self.text_str,
            self.font_asset,
            self.font_size,
            self.spacing,
            self.irenderer.layer,
            self.color,
            self.align_hor_center,
            self.irenderer.camera_mode_required
        );
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

    fn render(irenderer: *IRenderer2d, _: f32) void {
        const self: *Self = @fieldParentPtr("irenderer", irenderer);

        const half_text_width: f32 = 
            if (self.align_hor_center) 
                rl.MeasureTextEx(self.font_asset.font, self.text_str, self.font_size, self.spacing).x / 2
            else
                0;

        const pos = rl.Vector2{
            .x = self.transform.position.x - half_text_width,
            .y = self.transform.position.y,
        };

        rl.DrawTextEx(self.font_asset.font, self.text_str, pos, self.font_size, self.spacing, self.color);
    }
};


