const std = @import("std");
const rl = @import("../../core/external/raylib.zig");
const gg = @import("../../core/gamgine.zig");
const log = @import("../../core/log.zig");
const utils = @import("../../core/utils.zig");
const gow = @import("../../plugins/game_object_world/game_object_world.zig");

pub const Scene = struct {
    name: [:0] const u8,
    world: *gow.GameObjectWorldPlugin,
    onLoadFn: ?*const fn(*Scene, app: *const gg.GamgineApp) void = null,
    onUnloadFn: ?*const fn(*Scene, app: *const gg.GamgineApp) void = null,
    main_camera: rl.Camera2D,

    pub fn load(self: *Scene, app: *const gg.GamgineApp) void {
        if (self.onLoadFn) |loader| {
            loader(self, app);
        }
    }

    pub fn unload(self: *Scene, app: *const gg.GamgineApp) void {
        if (self.onUnloadFn) |unloader| {
            unloader(self, app);
        }
    }
};

pub const SceneManager = struct {
    const Self = @This();

    // Do not change the name of `iservice` variable
    iservice: gg.IService,

    self_allocator: std.mem.Allocator,

    // Add other dependecies from GamgineApp here
    app: *const gg.GamgineApp,


    scenes: std.StringArrayHashMap(Scene),
    active_scene: ?*Scene,

    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IService {
        var service: *Self = try app.gpa.create(Self);
        service.iservice.startUpFn = startUp;
        service.iservice.tearDownFn = tearDown;
        service.iservice.getTypeIdFn = getTypeId;

        service.self_allocator = app.gpa;

        // Initialize all internal fields here 
        service.scenes = std.StringArrayHashMap(Scene).init(app.gpa);
        service.active_scene = null;
        
        // If dependecies from GamgineApp is needed
        // Save GamgineApp as a struct field and query any plugin you need
        service.app = app;

        return &service.iservice;
    }

    fn startUp(iservice: *gg.IService) void {
        const self: *Self = @fieldParentPtr("iservice", iservice);
        _ = self;

        // Initialize dependecies from GamgineApp here
    }

    fn tearDown(iservice: *gg.IService) void {
        var self: *Self = @fieldParentPtr("iservice", iservice);

        self.scenes.deinit();

        self.self_allocator.destroy(self);
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }

    pub fn addScene(self: *Self, scene: Scene) void {
        self.scenes.put(scene.name, scene) catch |err| {
            self.app.logger.core_log(log.LogLevel.err, "Scene manager could not add the scene: {any}.", .{err});
        };
    }

    pub fn loadScene(self: *Self, scene_name: [:0]const u8) void {
        var maybe_scene = self.scenes.get(scene_name);
        if (maybe_scene) |*scene| {
            if (self.active_scene) |active_scene| {
                active_scene.unload(self.app);
            }
            scene.load(self.app);
            self.active_scene = scene;
        } else {
            self.app.logger.core_log(log.LogLevel.err, "Scene manager could not load the scene \"{s}\", because it was not added.",
                .{scene_name});
        }
    }
};
