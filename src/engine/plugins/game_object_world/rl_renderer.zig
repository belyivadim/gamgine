const std = @import("std");
const rl = @import("../../core/external/raylib.zig");
const gg = @import("../../core/gamgine.zig");
const utils = @import("../../core/utils.zig");
const log = @import("../../core/log.zig");

const gow = @import("game_object_world.zig");

pub const IRenderer2d = struct {
    renderFn: *const fn(*IRenderer2d, f32) void,
    /// NOTE: at first all of the objects with camera mode are drawn
    ///     and then all of the objects without camera mode,
    ///     so it is like 2 different groups of layers
    layer: i32,
    camera_mode_required: bool,

    pub fn render(irenderer: *IRenderer2d, dt: f32) void {
        irenderer.renderFn(irenderer, dt);
    }
};


pub const RlRendererPlugin = struct {
    const Self = @This();

    iplugin: gg.IPlugin,

    self_allocator: std.mem.Allocator,

    app: *const gg.GamgineApp,
    world: *gow.GameObjectWorldPlugin,

    render_queue_w_camera: std.ArrayList(*IRenderer2d),
    render_queue: std.ArrayList(*IRenderer2d),

    // by default will be null,
    // can be changed at any time
    main_camera: ?rl.Camera2D,


    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IPlugin {
        var renderer: *Self = try app.gpa.create(Self);
        renderer.iplugin.updateFn = update;
        renderer.iplugin.startUpFn = startUp;
        renderer.iplugin.tearDownFn = tearDown;
        renderer.iplugin.getTypeIdFn = getTypeId;
        renderer.self_allocator = app.gpa;
        renderer.render_queue_w_camera = std.ArrayList(*IRenderer2d).init(app.gpa);
        renderer.render_queue = std.ArrayList(*IRenderer2d).init(app.gpa);
        renderer.main_camera = null;

        renderer.app = app;

        return &renderer.iplugin;
    }

    fn startUp(iplugin: *gg.IPlugin) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);

        self.world = self.app.queryPlugin(gow.GameObjectWorldPlugin) orelse {
            log.Logger.core_log(log.LogLevel.fatal, 
                "RlRendererPlugin from game_object_world cannot work without GameObjectWorldPlugin. Shutting down.", .{});
            std.process.exit(1);
        };
    }

    fn update(iplugin: *gg.IPlugin, dt: f32) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin);

        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.RAYWHITE);

        var camera_mode_has_been_started = false;
        
        if (self.main_camera) |cam| {
            rl.BeginMode2D(cam);
            camera_mode_has_been_started = true;
        }

        for (self.render_queue_w_camera.items) |irenderer| {
            irenderer.render(dt);
        }

        if (camera_mode_has_been_started) {
            rl.EndMode2D();
        }

        for (self.render_queue.items) |irenderer| {
            irenderer.render(dt);
        }
    }

    fn tearDown(iplugin: *gg.IPlugin) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);
        self.render_queue_w_camera.deinit();
        self.render_queue.deinit();
        self.self_allocator.destroy(self);
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }

    fn addToQueue(queue: std.ArrayList(*IRenderer2d), renderer2d: *IRenderer2d) void {
        for (0..queue.items.len) |i| {
            if (queue.items[i].layer > renderer2d.layer) {
                const index = if (i == 0) 0 else i - 1;
                queue.insert(index, renderer2d) catch |err| {
                    log.Logger.core_log(log.LogLevel.err, "RlRendererPlugin could not add renderer component to the queue: {any}", .{err});
                    return;
                };
                return;
            }
        }

        // all elements are on layers below, append to the end
        queue.append(renderer2d) catch |err| {
            log.Logger.core_log(log.LogLevel.err, "RlRendererPlugin could not add renderer component to the queue: {any}", .{err});
            return;
        };
    }

    pub fn addRenderer2d(self: *Self, renderer2d: *IRenderer2d) void {
        var queue = &self.render_queue;
        if (renderer2d.camera_mode_required) {
            queue = &self.render_queue_w_camera;
        }

        for (0..queue.items.len) |i| {
            if (queue.items[i].layer > renderer2d.layer) {
                const index = if (i == 0) 0 else i - 1;
                queue.insert(index, renderer2d) catch |err| {
                    log.Logger.core_log(log.LogLevel.err, "RlRendererPlugin could not add renderer component to the queue: {any}", .{err});
                    return;
                };
                return;
            }
        }

        // all elements are on layers below, append to the end
        queue.append(renderer2d) catch |err| {
            log.Logger.core_log(log.LogLevel.err, "RlRendererPlugin could not add renderer component to the queue: {any}", .{err});
            return;
        };
    }

    pub fn removeRenderer2d(self: *Self, renderer2d: *const IRenderer2d) void {
        var queue = &self.render_queue;
        if (renderer2d.camera_mode_required) {
            queue = &self.render_queue_w_camera;
        }

        for (0..queue.items.len) |i| {
            if (queue.items[i] == renderer2d) {
                _ = queue.orderedRemove(i);
                return;
            }
        }
    }
};

