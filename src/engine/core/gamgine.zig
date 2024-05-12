const std = @import("std");
const rl = @import("external/raylib.zig");
const LogLevel = @import("log.zig").LogLevel;
const Logger = @import("log.zig").Logger;

pub const GamgineApp = struct {
    const Self = @This();

    appname: [:0]const u8,
    logger: Logger,
    window_config: WindowConfig,
    
    // allocators
    gpa: std.mem.Allocator,
    frame_allocator: std.mem.Allocator,

    // plugins
    plugins: std.ArrayList(*IPlugin),


    // entry point
    pub fn run(self: *Self) !void { 
        self.init();
        defer self.deinit();

        self.startUp();

        while (!rl.WindowShouldClose()) {
            const dt: f32 = rl.GetFrameTime();
            self.update(dt);
        }
    } 

    fn init(self: *Self) void {
        self.initWindow();
    }

    fn deinit(self: *Self) void {
        // TODO: free plugins
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

    fn startUp(self: *Self) void {
        for (self.plugins.items) |p| {
            p.startUp();
        }
    }

    fn update(self: *Self, dt: f32) void {
        for (self.plugins.items) |p| {
            p.update(dt);
        }
    }
};

pub const WindowConfig = struct {
    width:  i32 = 800,
    height: i32 = 600,
    is_full_screen: bool = false,
};

pub const IPlugin = struct {
    const Creator = *const fn(*const GamgineApp) error{OutOfMemory}!*IPlugin;

    startUpFn: *const fn (*IPlugin) void,
    updateFn: *const fn (*IPlugin, f32) void,

    pub fn startUp(self: *IPlugin) void {
        self.startUpFn(self);
    }

    pub fn update(self: *IPlugin, dt: f32) void {
        self.updateFn(self, dt);
    }
};


pub const Gamgine = struct {
    const Self = @This();

    appname: [:0]const u8,
    window_config: WindowConfig,
    logger: Logger = Logger{},

    // allocators
    gpa: std.mem.Allocator = std.heap.page_allocator,
    frame_allocator: std.mem.Allocator = std.heap.page_allocator,

    // plugins 
    plugin_creators: ?std.ArrayList(IPlugin.Creator) = null,

    // app
    app: GamgineApp = undefined,

    any_building_error_occured: bool = false,

    pub fn create(appname: [:0]const u8, window_config: WindowConfig) Self {
        return Gamgine{
            .appname = appname,
            .window_config = window_config,
        };
    }

    // Building funcitons
    pub fn build(self: *Self) !*GamgineApp {
        self.logger.core_log(LogLevel.info, "GAMEGINE: Building the application \"{s}\"", .{self.appname});

        //const render_queue = self.render_queue orelse std.ArrayList(RenderCallback(GameStateT)).init(self.gpa);

        //if (render_queue.items.len == 0) {
        //    self.logger.core_log(LogLevel.warning, "No render callbacks were added to the application.", .{});
        //} else {
        //    const comparator = struct {
        //        fn lessThan(_: @TypeOf(.{}), a: RenderCallback(GameStateT), b: RenderCallback(GameStateT)) bool {
        //            return a.layer < b.layer;
        //        }
        //    };
        //    std.sort.block(RenderCallback(GameStateT), render_queue.items, .{}, comparator.lessThan);
        //} 


        self.app = GamgineApp{
            .appname = self.appname,
            .logger = self.logger,
            .window_config = self.window_config,
            .gpa = self.gpa,
            .frame_allocator = self.frame_allocator,
            .plugins = std.ArrayList(*IPlugin).init(self.gpa),
        };

        if (self.plugin_creators) |creators| {
            self.logger.core_log(LogLevel.info, "GAMEGINE: Initializing plugins.\n", .{});
            for (creators.items) |c| {
                const plugin = try c(&self.app);
                try self.app.plugins.append(plugin);
            }
        } else {
            self.logger.core_log(LogLevel.warning, "GAMEGINE: No plugins were added to the application!\n", .{});
        }

        return &self.app;
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
            self.logger.core_log(LogLevel.err, "GAMEGINE: {s}: {any}", .{err_message, err});
            self.any_building_error_occured = true;
        };
    }

    pub fn addPlugin(self: *Self, plug_creator: IPlugin.Creator) *Self {
        if (self.plugin_creators == null) {
            self.plugin_creators = std.ArrayList(IPlugin.Creator).init(self.gpa);
        }

        const creators = &(self.plugin_creators orelse unreachable);
        self.appendToArrayList(IPlugin.Creator, creators, plug_creator, "Could not register plugin creator");

        return self;
    }
};

