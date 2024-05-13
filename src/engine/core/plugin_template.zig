const std = @import("std");
const gg = @import("../core/gamgine.zig");
const utils = @import("../core/utils.zig");

pub const Plugin = struct {
    const Self = @This();

    // Do not change the name of `iplugin` variable
    iplugin: gg.IPlugin,

    // Add other dependecies from GamgineApp here
    // app: *const gg.GamgineApp,

    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IPlugin {
        var plugin: *Self = try app.gpa.create(Self);
        plugin.iplugin.updateFn = update;
        plugin.iplugin.startUpFn = startUp;
        plugin.iplugin.tearDownFn = tearDown;
        plugin.iplugin.getTypeIdFn = getTypeId;

        // Initialize all internal fields here 
        
        // If dependecies from GamgineApp is needed
        // Save GamgineApp as a struct field and query any plugin you need
        // plugin.app = app;

        return &plugin.iplugin;
    }

    fn startUp(iplugin: *gg.IPlugin) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin);
        _ = self;

        // Initialize dependecies from GamgineApp here
    }

    fn update(iplugin: *gg.IPlugin, _: f32) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin);
        _ = self;
    }

    fn tearDown(iplugin: *gg.IPlugin) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);
        self.self_allocator.destroy(self);
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }
};
