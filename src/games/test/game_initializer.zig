const std = @import("std");
const gg = @import("../../engine/core/gamgine.zig");
const rl = @import("../../engine/core/external/raylib.zig");
const utils = @import("../../engine/core/utils.zig");
const gow = @import("../../engine/plugins/game_object_world/game_object_world.zig");
const Renderer2d = @import("../../engine/plugins/game_object_world/components/rl_renderer.zig").Renderer2d;
const Transform2d = @import("../../engine/plugins/game_object_world/components/rl_transform.zig").Transform2d;

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
        self.createTestObject(world, Transform2d.create(rl.Vector2Zero(), 0, rl.Vector2{.x = 1, .y = 1}));
        self.createTestObject(world, Transform2d.create(rl.Vector2{.x = 200, .y = 100}, 0, rl.Vector2{.x = 1, .y = 1}));
        self.createTestObject(world, Transform2d.create(rl.Vector2{.x = 500, .y = 300}, 45, rl.Vector2{.x = 1, .y = 1}));
        world.startWorld();
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


    fn createTestObject(self: *const Self, world: *gow.GameObjectWorldPlugin, transform: Transform2d) void {
        const square = world.newObject();
        if (square) |sq| {
            const maybe_texture = Renderer2d.createBlankTextureWithColor(rl.RED, 50, 50, self.app.gpa);
            if (maybe_texture) |texture| {
                _ = sq
                    .addComponent(Transform2d, transform)
                    .addComponent(Renderer2d, Renderer2d.create(texture));
            }
        }
    }
};
