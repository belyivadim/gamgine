const gg = @import("engine/gamgine.zig");
const LogLevel = @import("engine/log.zig").LogLevel;
const std = @import("std");

const rl = @import("engine/raylib.zig");

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

pub fn main() !void {
    var gamgine = gg.Gamgine(i32).create("Test", gg.WindowConfig{});
    
    var app = gamgine
       .setGpa(std.heap.page_allocator)
       .setFrameAllocator(std.heap.page_allocator)
       .addRenderCallback(RenderCallback.create(-2, drawSomething))
       .addRenderCallback(RenderCallback.create(-1, drawSomethingElse))
       .addSystem(gg.SystemCallTime.update, System.create(update_logic))
       .build();

    var state: GameState = 69;
    try app.run(&state);
}
