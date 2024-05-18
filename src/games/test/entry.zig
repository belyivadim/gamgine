const std = @import("std");
const gg = @import("../../engine/core/gamgine.zig");
const LogLevel = @import("../../engine/core/log.zig").LogLevel;
const renderer = @import("../../engine/plugins/game_object_world/rl_renderer.zig");
const gow = @import("../../engine/plugins/game_object_world/game_object_world.zig");
const InputPlugin = @import("../../engine/plugins/inputs/rl_input.zig").InputPlugin;
const init = @import("game_initializer.zig");

const Foo = struct {
    a: i32,
};

pub fn entry() !void {
    var gamgine = gg.Gamgine.create("Test", gg.WindowConfig{});
    
    _ = gamgine
       .setGpa(std.heap.page_allocator)
       .setFrameAllocator(std.heap.page_allocator)
       .addPlugin(InputPlugin.make)
       .addPlugin(init.InitWorldPlugin.make)
       .addPlugin(gow.GameObjectWorldPlugin.make)
       .addPlugin(renderer.RlRendererPlugin.make);

    if (gamgine.any_building_error_occured) {
        gamgine.logger.app_log(LogLevel.fatal, "Could not build the application!", .{});
        return error.Oops;
    }

    var app = try gamgine.build();
    try app.run();
}

