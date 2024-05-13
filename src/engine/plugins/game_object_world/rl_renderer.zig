const std = @import("std");
const rl = @import("../../core/external/raylib.zig");
const gg = @import("../../core/gamgine.zig");
const utils = @import("../../core/utils.zig");
const log = @import("../../core/log.zig");

const gow = @import("game_object_world.zig");


pub const RlRendererPlugin = struct {
    const Self = @This();

    iplugin: gg.IPlugin,

    self_allocator: std.mem.Allocator,

    app: *const gg.GamgineApp,
    world: *gow.GameObjectWorldPlugin,


    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IPlugin {
        var renderer: *Self = try app.gpa.create(Self);
        renderer.iplugin.updateFn = update;
        renderer.iplugin.startUpFn = startUp;
        renderer.iplugin.tearDownFn = tearDown;
        renderer.iplugin.getTypeIdFn = getTypeId;
        renderer.self_allocator = app.gpa;

        renderer.app = app;

        return &renderer.iplugin;
    }

    fn startUp(iplugin: *gg.IPlugin) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);

        self.world = self.app.queryPlugin(gow.GameObjectWorldPlugin) orelse {
            self.app.logger.core_log(log.LogLevel.fatal, 
                "RlRendererPlugin from game_object_world cannot work without GameObjectWorldPlugin. Shutting down.", .{});
            std.process.exit(1);
        };
    }

    fn update(iplugin: *gg.IPlugin, _: f32) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin);
        _ = self;

        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.RAYWHITE);
        
        //for (self.world.objects) |*obj| {
        //    for (obj.components) |comp| {
        //    }
        //}
    }

    fn tearDown(iplugin: *gg.IPlugin) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);
        self.self_allocator.destroy(self);
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }
};
