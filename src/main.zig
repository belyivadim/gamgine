const rl = @import("raylib.zig");

pub fn main() void {
    rl.InitWindow(800, 600, "Gamgine");
    defer rl.CloseWindow();

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.RAYWHITE);
    }
}
