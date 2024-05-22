const std = @import("std");
const gg = @import("../../engine/core/gamgine.zig");
const rl = @import("../../engine/core/external/raylib.zig");
const utils = @import("../../engine/core/utils.zig");
const gow = @import("../../engine/plugins/game_object_world/game_object_world.zig");
const Renderer2d = @import("../../engine/plugins/game_object_world/components/rl_renderer.zig").Renderer2d;
const RendererPlugin = @import("../../engine/plugins/game_object_world/rl_renderer.zig").RlRendererPlugin;
const Transform2d = @import("../../engine/plugins/game_object_world/components/rl_transform.zig").Transform2d;
const CharacterController = @import("character_controller.zig").CharacterController;
const SceneManager = @import("../../engine/services/scenes/scene_manager_gow.zig").SceneManager;
const Scene = @import("../../engine/services/scenes/scene_manager_gow.zig").Scene;
const log = @import("../../engine/core/log.zig");

pub const InitWorldPlugin = struct {
    const Self = @This();

    // Do not change the name of `iplugin` variable
    iplugin: gg.IPlugin,

    // Add other dependecies from GamgineApp here
    app: *const gg.GamgineApp,

    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IPlugin {
        var plugin: *Self = try app.gpa.create(Self);
        plugin.iplugin.updateFn = update;
        plugin.iplugin.startUpFn = startUp;
        plugin.iplugin.tearDownFn = tearDown;
        plugin.iplugin.getTypeIdFn = getTypeId;

        // Initialize all internal fields here
        plugin.app = app;

        return &plugin.iplugin;
    }

    fn startUp(iplugin: *gg.IPlugin) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin);

        // Initialize dependecies from GamgineApp here

        const world = self.app.queryPlugin(gow.GameObjectWorldPlugin) orelse unreachable;

        const scene_manager = self.app.queryService(SceneManager) orelse unreachable;
        scene_manager.addScene(Scene{
            .name = "Main Scene",
            .world = world,
            .onLoadFn = loadMainScene,
            .main_camera = rl.Camera2D{
                .offset = rl.Vector2Zero(),
                .target = rl.Vector2{.x = -50, .y = -50},
                .rotation = 0,
                .zoom = 1,
            },
        });

        scene_manager.loadScene("Main Scene");
    }

    fn update(iplugin: *gg.IPlugin, _: f32) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin);
        _ = self;
    }

    fn tearDown(iplugin: *gg.IPlugin) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);
        self.app.gpa.destroy(self);
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }

    fn loadMainScene(scene: *Scene, app: *const gg.GamgineApp) void {
        const player = createTestObject(scene.world, Transform2d.create(rl.Vector2Zero(), 0, rl.Vector2{.x = 1, .y = 1}), rl.RED);
        _ = createTestObject(scene.world, Transform2d.create(rl.Vector2{.x = 200, .y = 100}, 0, rl.Vector2{.x = 1, .y = 1}), rl.BLUE);
        const maybe_to1 = createTestObject(scene.world, Transform2d.create(rl.Vector2{.x = 500, .y = 300}, 0, rl.Vector2{.x = 1, .y = 1}), rl.PINK);

        if (maybe_to1) |to1| {
            const maybe_to2 = to1.clone(scene.world);
            if (maybe_to2) |to2| {
                const maybe_transform = to2.getComponentDataMut(Transform2d);
                if (maybe_transform) |transform| {
                    transform.rotate(45);
                }
            }
        }

        if (player) |p| {
            _ = p.addComponent(CharacterController, CharacterController.create());

            if (p.getComponentDataMut(Renderer2d)) |r| {
                r.layer = 1;
            }
        }

        const renderer = app.queryPlugin(RendererPlugin) orelse unreachable;
        renderer.main_camera = scene.main_camera;

        scene.world.startWorld();

        if (player) |p| {
            scene.world.destroyObject(p);
        }
    }

    fn createTestObject(world: *gow.GameObjectWorldPlugin, transform: Transform2d, color: rl.Color) ?*gow.GameObject {
        const square = world.newObject();
        if (square) |sq| {
            // TODO: pass allocator to load scene function or maybe store it into Scene struct
            const maybe_texture = Renderer2d.createBlankTextureWithColor(color, 50, 50, std.heap.page_allocator);
            if (maybe_texture) |texture| {
                _ = sq
                    .addComponent(Transform2d, transform)
                    .addComponent(Renderer2d, Renderer2d.create(texture, 0));
            }
        }
        return square;
    }
};
