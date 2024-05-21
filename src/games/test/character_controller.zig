const rl = @import("../../engine/core/external/raylib.zig");
const gow = @import("../../engine/plugins/game_object_world/game_object_world.zig");
const InputPlugin = @import("../../engine/plugins/inputs/rl_input.zig").InputPlugin;
const Key = @import("../../engine/plugins/inputs/rl_input.zig").KeyboardKey;
const Transform2d = @import("../../engine/plugins/game_object_world/components/rl_transform.zig").Transform2d;

pub const CharacterController = struct {
    const Self = @This();

    transform: *Transform2d,
    owner: *gow.GameObject,

    pub fn create() Self {
        return Self{
            .transform = undefined,
            .owner = undefined,
        };
    }


    pub fn start(self: *Self, owner: *gow.GameObject) void {
        self.owner = owner;
        self.transform = owner.getComponentDataMut(Transform2d) orelse unreachable;
    }

    pub fn update(self: *Self, _: f32, owner: *gow.GameObject) void {
        const maybe_input = owner.app.queryPlugin(InputPlugin);
        if (maybe_input) |input| {
            const keymap = [_]InputPlugin.KeyVector2Map{
                InputPlugin.KeyVector2Map{.key = Key.KEY_D,     .value = rl.Vector2{.x =  1, .y =  0}},
                InputPlugin.KeyVector2Map{.key = Key.KEY_A,     .value = rl.Vector2{.x = -1, .y =  0}},
                InputPlugin.KeyVector2Map{.key = Key.KEY_S,     .value = rl.Vector2{.x =  0, .y =  1}},
                InputPlugin.KeyVector2Map{.key = Key.KEY_W,     .value = rl.Vector2{.x =  0, .y = -1}},
                InputPlugin.KeyVector2Map{.key = Key.KEY_RIGHT, .value = rl.Vector2{.x =  1, .y =  0}},
                InputPlugin.KeyVector2Map{.key = Key.KEY_LEFT,  .value = rl.Vector2{.x = -1, .y =  0}},
                InputPlugin.KeyVector2Map{.key = Key.KEY_DOWN,  .value = rl.Vector2{.x =  0, .y =  1}},
                InputPlugin.KeyVector2Map{.key = Key.KEY_UP,    .value = rl.Vector2{.x =  0, .y = -1}},
            };
            const dir = input.mapKeysToVector2(keymap[0..]);
            self.transform.translate(rl.Vector2Scale(dir, 10)); }
    }

    pub fn destroy(_: *Self, _: *gow.GameObject) void {
    }

    pub fn clone(_: *const Self) Self {
        return CharacterController.create();
    }
};

