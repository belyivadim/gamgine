const gg = @import("engine/core/gamgine.zig");
const LogLevel = @import("engine/core/log.zig").LogLevel;
const std = @import("std");

const rl = @import("engine/core/external/raylib.zig");

const cbw = @import("engine/plugins/component_based_world.zig");

const GameState = i32;
const GamgineApp = gg.GamgineApp(GameState);
const RenderCallback = gg.RenderCallback(GameState);
const System = gg.System(GameState);


fn drawSomething(_: *GamgineApp, game_state: *i32, _: f32) void {
    rl.DrawRectangle(100, 100, game_state.*, game_state.*, rl.RED);
}

fn drawSomethingElse(_: *GamgineApp, game_state: *GameState, _: f32) void {
    rl.DrawRectangle(game_state.*, 150, 100, 100, rl.BLUE);
}


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
       .addPlugin(cbw.GameObjectWorldPlugin.make);

    if (gamgine.any_building_error_occured) {
        return error.Oops;
    }

    var app = try gamgine.build();
    try app.run();

    var comp = cbw.Component(Foo).create(Foo{.a = 69});
    const icomp = &comp.icomponent;

    const foo = icomp.getData(Foo);
    if (foo) |f| {
        std.debug.print("{d}\n", .{f.a}); 
    } else {
        std.debug.print("Wrong data type!\n", .{}); 
    }
}

