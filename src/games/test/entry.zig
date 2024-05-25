const std = @import("std");
const gg = @import("../../engine/core/gamgine.zig");
const log = @import("../../engine/core/log.zig");
const renderer = @import("../../engine/plugins/game_object_world/rl_renderer.zig");
const gow = @import("../../engine/plugins/game_object_world/game_object_world.zig");
const InputPlugin = @import("../../engine/plugins/inputs/rl_input.zig").InputPlugin;
const scene_manager = @import("../../engine/services/scenes/scene_manager_gow.zig");
const init = @import("game_initializer.zig");

pub fn entry() !void {
    var gamgine = gg.Gamgine.create("Test", gg.WindowConfig{});
    
    _ = gamgine
       .setGpa(std.heap.page_allocator)
       .setFrameAllocator(std.heap.page_allocator)
       .addService(scene_manager.SceneManager.make)
       .addPlugin(InputPlugin.make)
       .addPlugin(init.InitWorldPlugin.make)
       .addPlugin(gow.GameObjectWorldPlugin.make)
       .addPlugin(renderer.RlRendererPlugin.make);

    if (gamgine.any_building_error_occured) {
        log.logger.app_log(log.LogLevel.fatal, "Could not build the application!", .{});
        return error.Oops;
    }

    var app = try gamgine.build();
    try app.run();
}

