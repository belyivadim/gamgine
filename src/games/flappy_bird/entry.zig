const std = @import("std");
const gg = @import("../../engine/core/gamgine.zig");
const log = @import("../../engine/core/log.zig");
const renderer = @import("../../engine/plugins/game_object_world/rl_renderer.zig");
const gow = @import("../../engine/plugins/game_object_world/game_object_world.zig");
const InputPlugin = @import("../../engine/plugins/inputs/rl_input.zig").InputPlugin;
const SceneManager = @import("../../engine/services/scenes/scene_manager_gow.zig").SceneManager;
const AssetManager = @import("../../engine/services/asset_manager.zig").AssetManager;
const game = @import("game.zig");

pub fn entry() !void {
    var gamgine = gg.Gamgine.create("Flappy Bird", gg.WindowConfig{.height = 800, .width = 1000});
    
    _ = gamgine
       .setGpa(std.heap.page_allocator)
       .setFrameAllocator(std.heap.page_allocator)
       .addService(SceneManager.make)
       .addService(AssetManager.make)
       .addPlugin(InputPlugin.make)
       .addPlugin(gow.GameObjectWorldPlugin.make) // NOTE: put it before init plugin because of the way I am handling collisions
       .addPlugin(game.GamePlugin.make)
       .addPlugin(renderer.RlRendererPlugin.make);

    if (gamgine.any_building_error_occured) {
        log.Logger.app_log(log.LogLevel.fatal, "Could not build the application!", .{});
        return error.Oops;
    }

    var app = try gamgine.build();
    try app.run();
}

