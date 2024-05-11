const std = @import("std");
const rl = @import("raylib.zig");
const LogLevel = @import("log.zig").LogLevel;
const Logger = @import("log.zig").Logger;

pub fn GamgineApp(GameStateT: type) type {
    return struct {
        const Self = @This();
        const ThisRenderCallback = RenderCallback(GameStateT);
        const ThisSystem = System(GameStateT);

        appname: [:0]const u8,
        logger: Logger,
        window_config: WindowConfig,
        
        // allocators
        gpa: std.mem.Allocator,
        frame_allocator: std.mem.Allocator,

        // render
        render_queue: std.ArrayList(ThisRenderCallback),

        // systems
        on_start_systems: std.ArrayList(ThisSystem),
        on_update_systems: std.ArrayList(ThisSystem),


        // entry point
        pub fn run(self: *Self, game_state: *GameStateT) !void { 
            self.init();
            defer self.deinit();

            self.start(game_state);

            while (!rl.WindowShouldClose()) {
                const dt = rl.GetFrameTime();
                self.update(game_state, dt);
                self.draw(game_state, dt);
            }
        } 

        fn init(self: *Self) void {
            self.initWindow();
        }

        fn deinit(self: *Self) void {
            _ = self;
            rl.CloseWindow();
        }

        fn initWindow(self: *const Self) void {
            const width = if (self.window_config.is_full_screen) rl.GetScreenWidth() else self.window_config.width; 
            const height = if (self.window_config.is_full_screen) rl.GetScreenHeight() else self.window_config.height; 
            rl.InitWindow(width, height, self.appname);

            if (self.window_config.is_full_screen) {
                rl.ToggleFullscreen();
            }
        }

        fn start(self: *Self, game_state: *GameStateT) void {
            for (self.on_start_systems.items) |s| {
                s.callback(self, game_state, 0);
            }
        }

        fn update(self: *Self, game_state: *GameStateT, dt: f32) void {
            for (self.on_update_systems.items) |s| {
                s.callback(self, game_state, dt);
            }
        }

        fn draw(self: *Self, game_state: *GameStateT, dt: f32) void {
            rl.BeginDrawing();
            defer rl.EndDrawing();
            rl.ClearBackground(rl.RAYWHITE);


            for (self.render_queue.items) |cb| {
                cb.callback(self, game_state, dt);
            }
        }
    };
}

pub const WindowConfig = struct {
    width:  i32 = 800,
    height: i32 = 600,
    is_full_screen: bool = false,
};


pub fn RenderCallback(comptime GameStateT: type) type {
    const Callback = *const fn (*GamgineApp(GameStateT), *GameStateT, f32) void;

    return struct {
        layer: i32,
        callback: Callback, 

        pub fn create(layer: i32, callback: Callback) RenderCallback(GameStateT) {
            return .{
                .layer = layer,
                .callback = callback,
            };
        }
    };
}

pub fn System(comptime GameStateT: type) type {
    const Callback = *const fn (*GamgineApp(GameStateT), *GameStateT, f32) void;

    return struct {
        callback: Callback, 

        pub fn create(callback: Callback) System(GameStateT) {
            return .{
                .callback = callback,
            };
        }
    };
}

pub const SystemCallTime = enum {
    start, update
};

pub fn Gamgine(comptime GameStateT: type) type {
    return struct {
        const Self = @This();

        appname: [:0]const u8,
        window_config: WindowConfig,
        logger: Logger = Logger{},

        // allocators
        gpa: std.mem.Allocator = std.heap.page_allocator,
        frame_allocator: std.mem.Allocator = std.heap.page_allocator,

        // render
        render_queue: ?std.ArrayList(RenderCallback(GameStateT)) = null,

        // systems
        on_start_systems: ?std.ArrayList(System(GameStateT)) = null,
        on_update_systems: ?std.ArrayList(System(GameStateT)) = null,

        pub fn create(appname: [:0]const u8, window_config: WindowConfig) Self {
            return Gamgine(GameStateT){
                .appname = appname,
                .window_config = window_config,
            };
        }

        // Building funcitons
        pub fn build(self: *const Self) GamgineApp(GameStateT) {
            self.logger.core_log(LogLevel.info, "Building application \"{s}\"", .{self.appname});

            const render_queue = self.render_queue orelse std.ArrayList(RenderCallback(GameStateT)).init(self.gpa);

            if (render_queue.items.len == 0) {
                self.logger.core_log(LogLevel.warning, "No render callbacks were added to the application.", .{});
            } else {
                const comparator = struct {
                    fn lessThan(_: @TypeOf(.{}), a: RenderCallback(GameStateT), b: RenderCallback(GameStateT)) bool {
                        return a.layer < b.layer;
                    }
                };
                std.sort.block(RenderCallback(GameStateT), render_queue.items, .{}, comparator.lessThan);
            }

            const on_start_systems = self.on_start_systems orelse std.ArrayList(System(GameStateT)).init(self.gpa);
            const on_update_systems = self.on_update_systems orelse std.ArrayList(System(GameStateT)).init(self.gpa);

            return GamgineApp(GameStateT){
                .appname = self.appname,
                .logger = self.logger,
                .window_config = self.window_config,
                .gpa = self.gpa,
                .frame_allocator = self.frame_allocator,
                .render_queue = render_queue,
                .on_start_systems = on_start_systems,
                .on_update_systems = on_update_systems,
            };
        }

        pub fn setGpa(self: *Self, gpa: std.mem.Allocator) *Self {
            self.gpa = gpa;
            return self;
        }

        pub fn setFrameAllocator(self: *Self, frame_allocator: std.mem.Allocator) *Self {
            self.frame_allocator = frame_allocator;
            return self;
        } 

        fn appendToArrayList(
            self: *Self,
            comptime T: type,
            arr: *std.ArrayList(T),
            elem: T,
            err_message: [:0]const u8,
        ) void {
            arr.append(elem) catch |err| {
                self.logger.core_log(LogLevel.err, "{s}: {any}", .{err_message, err});
            };
        }

        pub fn addRenderCallback(self: *Self, cb: RenderCallback(GameStateT)) *Self {
            if (self.render_queue == null) {
                self.render_queue = std.ArrayList(RenderCallback(GameStateT)).init(self.gpa);
            }

            const rq = &(self.render_queue orelse unreachable);
            self.appendToArrayList(RenderCallback(GameStateT), rq, cb, "Cannot add render callback to the queue");

            return self;
        }

        pub fn addSystem(self: *Self, call_time: SystemCallTime, system: System(GameStateT)) *Self {
            switch (call_time) {
                SystemCallTime.start => {
                    if (self.on_start_systems == null) {
                        self.on_start_systems = std.ArrayList(System(GameStateT)).init(self.gpa);
                    }

                    const systems = &(self.on_start_systems orelse unreachable);
                    self.appendToArrayList(System(GameStateT), systems, system, "Cannot add start system");
                },
                SystemCallTime.update => {
                    if (self.on_update_systems == null) {
                        self.on_update_systems = std.ArrayList(System(GameStateT)).init(self.gpa);
                    }

                    const systems = &(self.on_update_systems orelse unreachable);
                    self.appendToArrayList(System(GameStateT), systems, system, "Cannot add update system");
                }
            }

            return self;
        }
    };
}

