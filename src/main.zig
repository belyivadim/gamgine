const gg = @import("engine/core/gamgine.zig");
const LogLevel = @import("engine/core/log.zig").LogLevel;
const std = @import("std");

const renderer = @import("engine/plugins/game_object_world/rl_renderer.zig");

const gow = @import("engine/plugins/game_object_world/game_object_world.zig");

const GameState = i32;
const GamgineApp = gg.GamgineApp(GameState);
const RenderCallback = gg.RenderCallback(GameState);
const System = gg.System(GameState);


fn update_logic(_: *GamgineApp, game_state: *GameState, _: f32) void {
    game_state.* += 1;
}

const Foo = struct {
    a: i32,
};

pub fn main() !void {
    var gamgine = gg.Gamgine.create("Test", gg.WindowConfig{});
    
    _ = gamgine
       .setGpa(std.heap.page_allocator)
       .setFrameAllocator(std.heap.page_allocator)
       .addPlugin(gow.GameObjectWorldPlugin.make)
       .addPlugin(renderer.RlRendererPlugin.make);

    if (gamgine.any_building_error_occured) {
        gamgine.logger.app_log(LogLevel.fatal, "Could not build the application!", .{});
        return error.Oops;
    }

    var app = try gamgine.build();
    try app.run();

    var comp = gow.Component(Foo).create(Foo{.a = 69});
    const icomp = &comp.icomponent;

    const foo = icomp.getData(Foo);
    if (foo) |f| {
        std.debug.print("{any}\n", .{f}); 
    } else {
        std.debug.print("Wrong data type!\n", .{}); 
    }
}

