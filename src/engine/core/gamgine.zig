const std = @import("std");
const rl = @import("external/raylib.zig");
const LogLevel = @import("log.zig").LogLevel;
const Logger = @import("log.zig").Logger;
const utils = @import("utils.zig");

pub const GamgineApp = struct {
    const Self = @This();

    pub const QueryPlugin = *const fn (*const Self, comptime type) ?*type;

    appname: [:0]const u8,
    logger: Logger,
    window_config: WindowConfig,
    
    // allocators
    gpa: std.mem.Allocator,
    frame_allocator: std.mem.Allocator,

    // plugins
    plugins: std.ArrayList(*IPlugin),

    // services
    services: std.ArrayList(*IService),


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

    pub fn queryPlugin(self: *const Self, comptime T: type) ?*T {
        for (self.plugins.items) |p| {
            if (p.getTypeId() == utils.typeId(T)) {
                return @ptrCast(@alignCast(p.getSelf(T)));
            }
        }

        return null;
    }

    pub fn queryService(self: *const Self, comptime T: type) ?*T {
        for (self.services.items) |s| {
            if (s.getTypeId() == utils.typeId(T)) {
                return @ptrCast(@alignCast(s.getSelf(T)));
            }
        }

        return null;
    }

    fn init(self: *Self) void {
        self.initWindow();
    }

    fn deinit(self: *Self) void {
        for (self.plugins.items) |p| {
            p.tearDown();
        }
        self.plugins.deinit();

        for (self.services.items) |s| {
            s.tearDown();
        }
        self.services.deinit();

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

        for (self.services.items) |s| {
            s.startUp();
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
    tearDownFn: *const fn (*IPlugin) void,
    getTypeIdFn: *const fn () utils.TypeId,

    pub fn startUp(self: *IPlugin) void {
        self.startUpFn(self);
    }

    pub fn update(self: *IPlugin, dt: f32) void {
        self.updateFn(self, dt);
    }

    pub fn tearDown(self: *IPlugin) void {
        self.tearDownFn(self);
    }

    pub fn getTypeId(self: *IPlugin) utils.TypeId {
        return self.getTypeIdFn();
    }

    pub fn getSelf(self: *IPlugin, comptime T: type) *T {
        const self_parent: *T = @fieldParentPtr("iplugin", self);
        return self_parent;
    }
};

pub const IService = struct {
    const Creator = *const fn(*const GamgineApp) error{OutOfMemory}!*IService;

    startUpFn: *const fn (*IService) void,
    tearDownFn: *const fn (*IService) void,
    getTypeIdFn: *const fn () utils.TypeId,

    pub fn startUp(self: *IService) void {
        self.startUpFn(self);
    }

    pub fn tearDown(self: *IService) void {
        self.tearDownFn(self);
    }

    pub fn getTypeId(self: *IService) utils.TypeId {
        return self.getTypeIdFn();
    }

    pub fn getSelf(self: *IService, comptime T: type) *T {
        const self_parent: *T = @fieldParentPtr("iservice", self);
        return self_parent;
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

    // services
    service_creators: ?std.ArrayList(IService.Creator) = null,

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
            .services = std.ArrayList(*IService).init(self.gpa),
        };

        if (self.service_creators) |creators| {
            self.logger.core_log(LogLevel.info, "GAMEGINE: Initializing Services.\n", .{});
            for (creators.items) |c| {
                const service = try c(&self.app);
                try self.app.services.append(service);
            }
        }

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

    pub fn addService(self: *Self, service_creator: IService.Creator) *Self {
        if (self.service_creators == null) {
            self.service_creators = std.ArrayList(IService.Creator).init(self.gpa);
        }

        const creators = &(self.service_creators orelse unreachable);
        self.appendToArrayList(IService.Creator, creators, service_creator, "Could not register service creator");

        return self;
    }
};

