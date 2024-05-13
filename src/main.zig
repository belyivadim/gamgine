const test_game = @import("games/test/entry.zig");

pub fn main() !void {
    try test_game.entry();
}

