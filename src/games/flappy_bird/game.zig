const std = @import("std");
const gg = @import("../../engine/core/gamgine.zig");
const rl = @import("../../engine/core/external/raylib.zig");
const utils = @import("../../engine/core/utils.zig");
const gow = @import("../../engine/plugins/game_object_world/game_object_world.zig");
const Renderer2d = @import("../../engine/plugins/game_object_world/components/rl_renderer.zig").Renderer2d;
const TextRenderer = @import("../../engine/plugins/game_object_world/components/text_renderer.zig").TextRenderer;
const RendererPlugin = @import("../../engine/plugins/game_object_world/rl_renderer.zig").RlRendererPlugin;
const Transform2d = @import("../../engine/plugins/game_object_world/components/rl_transform.zig").Transform2d;
const SceneManager = @import("../../engine/services/scenes/scene_manager_gow.zig").SceneManager;
const Scene = @import("../../engine/services/scenes/scene_manager_gow.zig").Scene;
const log = @import("../../engine/core/log.zig");
const InputPlugin = @import("../../engine/plugins/inputs/rl_input.zig").InputPlugin;
const Key = @import("../../engine/plugins/inputs/rl_input.zig").KeyboardKey;
const assets = @import("../../engine/services/assets.zig");
const animator = @import("../../engine/plugins/game_object_world/components/sprite_animator.zig");


pub const GamePlugin = struct {
    const Self = @This();

    const cwd = "src/games/flappy_bird/";

    // Do not change the name of `iplugin` variable
    iplugin: gg.IPlugin,

    // Add other dependecies from GamgineApp here
    app: *const gg.GamgineApp,
    world: *gow.GameObjectWorldPlugin,

    player_collider: *const Collider,
    colliders: std.ArrayList(*const Collider),
    last_collision: ?*const Collider,

    pipe_width: f32,
    pipe_height: f32,
    bird_side: f32,
    gap_height: f32,

    score: i32,
    score_font_size: i32,
    score_buf: [16]u8,
    score_str: [:0]u8,

    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IPlugin {
        var plugin: *Self = try app.gpa.create(Self);
        plugin.iplugin.updateFn = update;
        plugin.iplugin.startUpFn = startUp;
        plugin.iplugin.tearDownFn = tearDown;
        plugin.iplugin.getTypeIdFn = getTypeId;

        // Initialize all internal fields here
        plugin.app = app;
        plugin.player_collider = undefined;
        plugin.colliders = std.ArrayList(*const Collider).init(app.gpa);
        plugin.last_collision = null;

        plugin.pipe_width = @as(f32, @floatFromInt(app.window_config.width)) / 10;
        plugin.pipe_height = @floatFromInt(app.window_config.height);
        plugin.bird_side = @as(f32, @floatFromInt(app.window_config.width)) / 15;
        plugin.gap_height = plugin.bird_side * 3;

        plugin.score = 0;
        plugin.score_font_size = 72;
        plugin.score_buf = std.mem.zeroes([16]u8);
        plugin.score_str = @ptrCast(plugin.score_buf[0..0]);

        return &plugin.iplugin;
    }

    fn startUp(iplugin: *gg.IPlugin) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin);

        // Initialize dependecies from GamgineApp here

        // to get rid of messages about successfully updated textures
        rl.SetTraceLogLevel(rl.LOG_WARNING);

        self.world = self.app.queryPlugin(gow.GameObjectWorldPlugin) orelse unreachable;

        const scene_manager = self.app.queryService(SceneManager) orelse unreachable;
        scene_manager.addScene(Scene{
            .name = "Main Scene",
            .world = self.world,
            .onLoadFn = loadMainScene,
            .onUnloadFn = unloadMainScene,
            .main_camera = rl.Camera2D{
                .offset = rl.Vector2Zero(),
                .target = rl.Vector2Zero(),
                .rotation = 0,
                .zoom = 1,
            },
        });

        scene_manager.loadScene("Main Scene");

        self.updateScoreStr();
    }

    fn gameower(self: *Self) void {
        const scene_manager = self.app.queryService(SceneManager) orelse unreachable;
        scene_manager.loadScene("Main Scene");
        self.score = 0;
        self.updateScoreStr();
    }

    fn updateScoreStr(self: *Self) void {
        self.score_str = @ptrCast(std.fmt.bufPrint(&self.score_buf, "{}", .{self.score}) catch { unreachable; });
        self.score_str[self.score_str.len] = 0;
    }

    fn checkPlayerCollisions(self: *Self) void {
        const player_bounds = rl.Rectangle{
            .x = self.player_collider.transform.position.x,
            .y = self.player_collider.transform.position.y,
            .width =  self.player_collider.width,
            .height = self.player_collider.height,
        };

        if (player_bounds.y < 0 or player_bounds.y + player_bounds.height > @as(f32, @floatFromInt(self.app.window_config.height))) {
            self.gameower();
            return;
        }


        for (self.colliders.items) |collider| {
            const bounds = rl.Rectangle{
                .x = collider.transform.position.x,
                .y = collider.transform.position.y,
                .width = collider.width,
                .height = collider.height,
            };

            if (rl.CheckCollisionRecs(player_bounds, bounds)) {
                switch (collider.tag) {
                    ColliderTag.pipe => {
                        self.gameower();
                        break;
                    },
                    ColliderTag.gap => {
                        if (collider != self.last_collision) {
                            self.score += 1;
                            self.updateScoreStr();
                        }
                    },
                    ColliderTag.player => unreachable,
                }

                self.last_collision = collider;
            }
        }
    }

    fn update(iplugin: *gg.IPlugin, _: f32) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin);

        self.checkPlayerCollisions();
    }

    fn tearDown(iplugin: *gg.IPlugin) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);
        self.colliders.deinit();
        self.app.gpa.destroy(self);
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }

    fn removeCollider(self: *Self, collider: *const Collider) void {
        for (0..self.colliders.items.len) |i| {
            if (self.colliders.items[i] == collider) {
                _ = self.colliders.swapRemove(i);
                return;
            }
        }
    }

    fn unloadMainScene(_: *Scene, app: *const gg.GamgineApp) void {
        log.Logger.app_log(log.LogLevel.info, "Unloading Main Scene", .{});
        var world = app.queryPlugin(gow.GameObjectWorldPlugin) orelse unreachable;
        world.clean();
    }

    fn loadMainScene(scene: *Scene, app: *const gg.GamgineApp) void {
        log.Logger.app_log(log.LogLevel.info, "Loading Main Scene", .{});

        var game = app.queryPlugin(GamePlugin) orelse unreachable;

        _ = game.createPlayer(scene.world, app);

        const pipes_speed: f32 = 400;
        _ = game.createPipeSpawner(scene.world, app, 2, pipes_speed);
        _ = game.createScoreText(scene.world, app);

        const bg_speed: f32 = 200;
        _ = game.createBackgroundSpawner(bg_speed);
        
        const renderer = app.queryPlugin(RendererPlugin) orelse unreachable;
        renderer.main_camera = scene.main_camera;

        scene.world.startWorld();
    }
    
    fn getOrLoadBlankTextureAsset(
        name: []const u8, 
        color: rl.Color, 
        width: i32, height: i32, 
        allocator: std.mem.Allocator
    ) *assets.TextureAsset {
        const asset = assets.AssetManager.getAsset(assets.TextureAsset, name) 
            orelse assets.TextureAsset.loadBlankTextureWithColor(name, color, width, height, allocator) 
            orelse unreachable;

        return asset;
    }

    fn createScoreText(self: *Self, world: *gow.GameObjectWorldPlugin, _: *const gg.GamgineApp) *gow.GameObject {
        const score_txt = world.newObject("Score Text") orelse unreachable;
        const score_shadow_txt = world.newObject("Score Shadow Text") orelse unreachable;

        const fb_font_path = Self.cwd ++ "resources/assets/fonts/flappy_font_numbers.ttf";
        const fb_font_numbers = assets.FontAsset.getOrLoad(fb_font_path) orelse unreachable;

        const text_x: f32 = @as(f32, @floatFromInt(self.app.window_config.width)) / 2;


        _ = score_txt
            .addComponent(Transform2d, Transform2d.create(rl.Vector2{.x = text_x, .y = 50}, 0, rl.Vector2{.x = 1, .y = 1}))
            .addComponent(TextRenderer, TextRenderer.create(
                    self.score_str,
                    fb_font_numbers,
                    @floatFromInt(self.score_font_size),
                    1, 0, rl.WHITE, true, false
            ));

        _ = score_shadow_txt
            .addComponent(Transform2d, Transform2d.create(rl.Vector2{.x = text_x + 5, .y = 50 + 5}, 0, rl.Vector2{.x = 1, .y = 1}))
            .addComponent(TextRenderer, TextRenderer.create(
                    self.score_str,
                    fb_font_numbers,
                    @floatFromInt(self.score_font_size),
                    1, -1, rl.BLACK, true, false
            ));

        return score_txt;
    }

    fn createPlayer(self: *Self, world: *gow.GameObjectWorldPlugin, app: *const gg.GamgineApp) *gow.GameObject {
        const player = world.newObject("Player") orelse unreachable;

        const side_int: i32 = @intFromFloat(self.bird_side);
        const collider_side = self.bird_side - self.bird_side * 0.1;


        const texture_path = Self.cwd ++ "resources/assets/sprites/bird.png";
        const player_texture_asset = assets.TextureAsset.getOrLoadResizedHeight(texture_path, side_int) orelse unreachable;

        // correction probably will not work on different resolutions
        const texture_side_corrected: f32 = @floatFromInt(player_texture_asset.texture.height - 2); 

        const texture_frame_rec = rl.Rectangle{
            .x = 0, 
            .y = 0, 
            .width = texture_side_corrected, 
            .height = texture_side_corrected,
        };

        const animations_fps = 8;
        const player_animations = [_]animator.SpriteAnimation{
            animator.SpriteAnimation.create(
                "Idle",
                animations_fps,
                1,
                texture_side_corrected,
                texture_side_corrected,
                true,
            ),
            animator.SpriteAnimation.create(
                    "Flap",
                    animations_fps,
                    4,
                    texture_side_corrected,
                    texture_side_corrected,
                    false,
            )
        };

        _ = player
            .addComponent(CharacterController, CharacterController.create(750))
            .addComponent(Transform2d, Transform2d.create(rl.Vector2{.x = 50, .y = 275}, 0, rl.Vector2{.x = 1, .y = 1}))
            .addComponent(Collider, Collider.create(collider_side, collider_side, ColliderTag.player))
            .addComponent(animator.SpriteAnimator, animator.SpriteAnimator.createWithManyAnimations(app.gpa, &player_animations))
            .addComponent(Renderer2d, Renderer2d.createWithCustomFrameRec(player_texture_asset, 0, rl.WHITE, true, texture_frame_rec));

        self.player_collider = player.getComponentData(Collider) orelse unreachable;

        return player;
    }

    fn createPipeSpawner(
        self: *Self, 
        world: *gow.GameObjectWorldPlugin, 
        app: *const gg.GamgineApp, 
        interval: f32, 
        move_speed: f32
    ) *gow.GameObject {
        const spawner = world.newObject("Pipe Spawner") orelse unreachable;

        _ = app;
        const bottom_texture_path = Self.cwd ++ "resources/assets/sprites/pipe_bottom.png";
        const bottom_pipe_texture_asset =
            assets.TextureAsset.getOrLoadResized(bottom_texture_path, @intFromFloat(self.pipe_width), @intFromFloat(self.pipe_height)) orelse unreachable;

        const top_pipe_prefab = self.createPipePrefab("Top Pipe Prefab", move_speed, bottom_pipe_texture_asset);
        const bottom_pipe_prefab = self.createPipePrefab("Bottom Pipe Prefab", move_speed, bottom_pipe_texture_asset);

        const score_prefab = self.createScorePrefab("Score Prefab", move_speed);

        _ = spawner.addComponent(PipeSpawner, PipeSpawner.create(interval, top_pipe_prefab, bottom_pipe_prefab, score_prefab, self.gap_height));

        return spawner;
    }

    fn createScorePrefab(self: *Self, name: []const u8, move_speed: f32) *gow.GameObject {
        const maybe_prefab = self.world.getPrefab(name);
        if (maybe_prefab) |prefab| return prefab;

        var prefab = self.world.createPrefab(name) orelse unreachable;

        _ = prefab 
            .addComponent(Transform2d, Transform2d.create(rl.Vector2Zero(), 0, rl.Vector2{.x = 1, .y = 1}))
            .addComponent(AutoMover, AutoMover.create(move_speed, rl.Vector2{.x = -1, .y = 0}, self.pipe_width))
            .addComponent(Collider, Collider.create(self.pipe_width, self.gap_height, ColliderTag.gap));

        return prefab;
    }

    fn createPipePrefab(
        self: *Self, 
        name: []const u8, 
        move_speed: f32, 
        texture_asset: *assets.TextureAsset
    ) *gow.GameObject {
        const maybe_prefab = self.world.getPrefab(name);
        if (maybe_prefab) |prefab| return prefab;

        var prefab = self.world.createPrefab(name) orelse unreachable;

        _ = prefab 
            .addComponent(Transform2d, Transform2d.create(rl.Vector2Zero(), 0, rl.Vector2{.x = 1, .y = 1}))
            .addComponent(AutoMover, AutoMover.create(move_speed, rl.Vector2{.x = -1, .y = 0}, self.pipe_width))
            .addComponent(Collider, Collider.create(self.pipe_width, self.pipe_height, ColliderTag.pipe))
            .addComponent(Renderer2d, Renderer2d.create(texture_asset, 0, rl.WHITE, true));


        return prefab;
    }

    fn createBackgroundSpawner(self: *Self, move_speed: f32) *gow.GameObject {
        const spawner = self.world.newObject("Backgound Spawner") orelse unreachable;

        const background_path = Self.cwd ++ "resources/assets/sprites/background_orange.png";
        const background_texture_asset =
            assets.TextureAsset.getOrLoadResizedHeight( // resize only by height since it is square texture
                background_path, 
                self.app.window_config.height
            ) orelse unreachable;

        const bg_width = background_texture_asset.texture.width;

        const bg = self.createBackgroundPrefab("Background", rl.Vector2Zero(), background_texture_asset);

        _ = spawner.addComponent(
            BackgroundSpawner,
            BackgroundSpawner.create(bg, bg_width, move_speed, -1)
        );

       return spawner;
    }

    fn createBackgroundPrefab(
        self: *Self, 
        name: []const u8, 
        position: rl.Vector2, 
        texture_asset: *assets.TextureAsset,
    ) *gow.GameObject {
        const maybe_prefab = self.world.getPrefab(name);
        if (maybe_prefab) |prefab| return prefab;

        const prefab = self.world.createPrefab(name) orelse unreachable;

        const bg_tint = rl.Color{.r = 255, .g = 255, .b = 255, .a = 150};
        _ = prefab
            .addComponent(Transform2d, Transform2d.create(position, 0, rl.Vector2{.x = 1, .y = 1}))
            .addComponent(Renderer2d, Renderer2d.create(texture_asset, -10, bg_tint, true));

        return prefab;
    }
};


const BackgroundSpawner = struct {
    const Self = @This();

    world: *gow.GameObjectWorldPlugin,
    prefab: *const gow.GameObject,
    object_width: i32,
    move_speed: f32,
    x_dir: f32,

    transforms: [3]*Transform2d,
    spawned: [3]*gow.GameObject,

    pub fn create(prefab: *const gow.GameObject, object_width: i32, move_speed: f32, x_dir: f32) Self { 
        return Self{
            .world = undefined,
            .prefab = prefab,
            .object_width = object_width,
            .move_speed = move_speed,
            .x_dir = x_dir,
            .transforms = undefined,
            .spawned = undefined,
        };
    }

    pub fn start(self: *Self, owner: *gow.GameObject) void {
        self.world = owner.app.queryPlugin(gow.GameObjectWorldPlugin) orelse unreachable;

        for (0..self.transforms.len) |i| {
            const bg = self.spawn();
            var transform = bg.getComponentDataMut(Transform2d) orelse unreachable;
            transform.position.x = @floatFromInt(self.object_width * @as(i32, @intCast(i)));
            self.transforms[i] = transform;
            self.spawned[i] = bg;
        }
    }

    pub fn update(self: *Self, dt: f32, _: *gow.GameObject) void {
        for (0..self.transforms.len) |i| {
            self.transforms[i].translate(
                rl.Vector2{
                    .x = self.x_dir * self.move_speed * dt, 
                    .y = 0
                }
            );
        }

        const max_x = self.transforms[0].position.x + @as(f32, @floatFromInt(self.object_width));
        if (max_x <= 0) {
            const bg = self.spawned[0];
            const transform = self.transforms[0];

            for (1..self.spawned.len) |i| {
                self.spawned[i-1] = self.spawned[i];
                self.transforms[i-1] = self.transforms[i];
            }

            transform.position.x += @as(f32, @floatFromInt(self.object_width)) * 3;
            self.transforms[2] = transform;
            self.spawned[2] = bg;
        }
    }

    pub fn destroy(_: *Self, _: *gow.GameObject) void {
    }

    pub fn clone(self: *const Self) Self {
        return BackgroundSpawner.create(self.prefab, self.object_width, self.move_speed, self.x_dir);
    }

    pub fn setActive(_: *Self, _: bool) void {
    }

    fn spawn(self: *Self) *gow.GameObject {
        return self.prefab.clone(self.world) orelse unreachable;
    }
};


const PipeSpawner = struct {
    const Self = @This();

    cooldown: f32,
    interval: f32,
    world: *gow.GameObjectWorldPlugin,
    top_pipe_prefab: *const gow.GameObject,
    bottom_pipe_prefab: *const gow.GameObject,
    score_prefab: *const gow.GameObject,
    gap_height: f32,
    game: *GamePlugin,
    window_config: gg.WindowConfig,

    pub fn create(spawn_interval: f32, 
        top_pipe_prefab: *const gow.GameObject, bottom_pipe_prefab: *const gow.GameObject,
        score_prefab: *const gow.GameObject, gap_height: f32
    ) Self { 
        return Self{
            .cooldown = 0,
            .interval = spawn_interval,
            .world = undefined,
            .top_pipe_prefab = top_pipe_prefab,
            .bottom_pipe_prefab = bottom_pipe_prefab,
            .score_prefab = score_prefab,
            .gap_height = gap_height,
            .game = undefined,
            .window_config = undefined,
        };
    }

    pub fn start(self: *Self, owner: *gow.GameObject) void {
        self.world = owner.app.queryPlugin(gow.GameObjectWorldPlugin) orelse unreachable;
        self.game = owner.app.queryPlugin(GamePlugin) orelse unreachable;
        self.window_config = owner.app.window_config;
    }

    pub fn update(self: *Self, dt: f32, _: *gow.GameObject) void {
        self.cooldown -= dt;
        if (self.cooldown > 0) return;

        self.cooldown = self.interval;
        self.spawn();
    }

    pub fn destroy(_: *Self, _: *gow.GameObject) void {
    }

    pub fn clone(self: *const Self) Self {
        return PipeSpawner.create(self.interval, self.top_pipe_prefab, self.bottom_pipe_prefab, self.score_prefab, self.gap_height);
    }

    pub fn setActive(_: *Self, _: bool) void {
    }

    fn spawn(self: *Self) void {
        var top_y: f32 = 0;
        const pipe_height: f32 = @floatFromInt(self.window_config.height);

        {
            const pipe_top = self.top_pipe_prefab.clone(self.world) orelse unreachable;
            const collider = pipe_top.getComponentData(Collider) orelse {
                std.debug.print("{s}\n", .{pipe_top.name});
                unreachable;
            };
            self.game.colliders.append(collider) catch { unreachable; };
            var transform = pipe_top.getComponentDataMut(Transform2d) orelse unreachable;

            const bot_pos = @as(i32, @intFromFloat(-self.gap_height));
            const top_pos = -self.window_config.height;
            top_y = @floatFromInt(rl.GetRandomValue(top_pos, bot_pos));

            transform.position.x = @floatFromInt(self.window_config.width);
            transform.position.y = top_y;
        }

        {
            const pipe_bottom = self.bottom_pipe_prefab.clone(self.world) orelse unreachable;
            self.game.colliders.append(pipe_bottom.getComponentDataMut(Collider) orelse unreachable) catch { unreachable; };
            var transform = pipe_bottom.getComponentDataMut(Transform2d) orelse unreachable;

            const y = top_y + pipe_height + self.gap_height + 10;

            transform.position.x = @floatFromInt(self.window_config.width);
            transform.position.y = y;
        }

        {
            const score = self.score_prefab.clone(self.world) orelse unreachable;
            self.game.colliders.append(score.getComponentDataMut(Collider) orelse unreachable) catch { unreachable; };
            var transform = score.getComponentDataMut(Transform2d) orelse unreachable;

            const y = top_y + pipe_height;

            transform.position.x = @floatFromInt(self.window_config.width);
            transform.position.y = y;
        }
    }
};


const AutoMover = struct {
    const Self = @This();

    speed: f32,
    direction: rl.Vector2,
    transform: *Transform2d,
    object_width: f32,

    world: *gow.GameObjectWorldPlugin,

    pub fn create(speed: f32, direction: rl.Vector2, object_width: f32) Self { 
        return Self{
            .speed = speed,
            .direction = direction,
            .transform = undefined,
            .object_width = object_width,
            .world = undefined,
        };
    }

    pub fn start(self: *Self, owner: *gow.GameObject) void {
        self.transform = owner.getComponentDataMut(Transform2d) orelse unreachable;
        self.world = owner.app.queryPlugin(gow.GameObjectWorldPlugin) orelse unreachable;
    }

    pub fn update(self: *Self, dt: f32, owner: *gow.GameObject) void {
        self.transform.translate(
            rl.Vector2{
                .x = self.direction.x * self.speed * dt, 
                .y = self.direction.y * self.speed * dt
            }
        );

        if (self.transform.position.x < -self.object_width) {
            self.world.destroyObject(owner);
        }
    }

    pub fn destroy(_: *Self, _: *gow.GameObject) void {
    }


    pub fn clone(self: *const Self) Self {
        return AutoMover.create(self.speed, self.direction, self.object_width);
    }

    pub fn setActive(_: *Self, _: bool) void {
    }

};

const ColliderTag = enum { player, pipe, gap, };

const Collider = struct {
    const Self = @This();

    transform: *Transform2d,
    width: f32,
    height: f32,
    tag: ColliderTag,

    game: *GamePlugin,

    owner: *gow.GameObject,

    pub fn create(width: f32, height: f32, tag: ColliderTag) Self {
        return Self{
            .transform = undefined,
            .width = width,
            .height = height,
            .tag = tag,
            .game = undefined,
            .owner = undefined,
        };
    }

    pub fn start(self: *Self, owner: *gow.GameObject) void {
        self.transform = owner.getComponentDataMut(Transform2d) orelse unreachable;
        self.game = owner.app.queryPlugin(GamePlugin) orelse unreachable;
        self.owner = owner;
    }

    pub fn update(_: *Self, _: f32, _: *gow.GameObject) void {
    }

    pub fn destroy(self: *Self, _: *gow.GameObject) void {
        self.game.removeCollider(self);
    }

    pub fn clone(self: *const Self) Self {
        return Self.create(self.width, self.height, self.tag);
    }

    pub fn setActive(_: *Self, _: bool) void {
    }
};

const CharacterController = struct {
    const Self = @This();

    transform: *Transform2d,
    input: *InputPlugin,

    velocity: f32, // only Y axis
    thrust_force: f32,

    character_animator: *animator.SpriteAnimator,

    const Gravity: f32 = 9.7 * 100;

    pub fn create(thrust_force: f32) Self {
        return Self{
            .transform = undefined,
            .input = undefined,
            .velocity = 0,
            .thrust_force = thrust_force,
            .character_animator = undefined,
        };
    }


    pub fn start(self: *Self, owner: *gow.GameObject) void {
        self.transform = owner.getComponentDataMut(Transform2d) orelse unreachable;
        self.input = owner.app.queryPlugin(InputPlugin) orelse unreachable;
        self.character_animator = owner.getComponentDataMut(animator.SpriteAnimator) orelse unreachable;
    }

    pub fn update(self: *Self, dt: f32, _: *gow.GameObject) void {
        if (self.input.isKeyPressedOnce(Key.KEY_SPACE)) {
            self.velocity -= self.thrust_force;
            self.character_animator.resetAndPlayAnimation("Flap");
        }

        self.velocity += Gravity * dt;

        self.lean();
        self.transform.translate(rl.Vector2{.x = 0, .y = self.velocity * dt});
    }

    pub fn destroy(_: *Self, _: *gow.GameObject) void {
    }

    pub fn clone(self: *const Self) Self {
        return CharacterController.create(self.thrust_force);
    }

    pub fn setActive(_: *Self, _: bool) void {
    }

    pub fn lean(self: *Self) void {
        const max_vel_y: f32 = 800;
        const vel_y = rl.Clamp(self.velocity, -max_vel_y, max_vel_y);
        const normalized_vel_y = vel_y / max_vel_y;
        const lean_angle = @sin(normalized_vel_y) * 35;
        self.transform.rotation = lean_angle;
    }
};

