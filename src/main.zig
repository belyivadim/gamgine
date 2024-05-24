const game = @import("games/flappy_bird/entry.zig");

pub fn main() !void {
    try game.entry();
}

