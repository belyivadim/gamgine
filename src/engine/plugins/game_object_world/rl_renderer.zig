const std = @import("std");
const rl = @import("../../core/external/raylib.zig");
const gg = @import("../../core/gamgine.zig");
const utils = @import("../../core/utils.zig");

const gow = @import("game_object_world.zig");


pub const RlRendererPlugin = struct {
    const Self = @This();

    iplugin: gg.IPlugin,

    self_allocator: std.mem.Allocator,

    world: *gow.GameObjectWorldPlugin,


    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IPlugin {
        var renderer: *Self = try app.gpa.create(Self);
        renderer.iplugin.updateFn = update;
        renderer.iplugin.startUpFn = startUp;
        renderer.iplugin.tearDownFn = tearDown;
        renderer.iplugin.getTypeIdFn = getTypeId;
        renderer.self_allocator = app.gpa;
        renderer.world = app.queryPlugin(gow.GameObjectWorldPlugin) orelse undefined;

        return &renderer.iplugin;
    }

    fn startUp(_: *gg.IPlugin) void {
    }

    fn update(iplugin: *gg.IPlugin, _: f32) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);

        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.RAYWHITE);
        
        self.world.foo();
    }

    fn tearDown(iplugin: *gg.IPlugin) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);
        self.self_allocator.destroy(self);
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }
};
