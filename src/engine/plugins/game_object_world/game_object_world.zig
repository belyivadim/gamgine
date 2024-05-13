const std = @import("std");
const log = @import("../../core/log.zig");
const gg = @import("../../core/gamgine.zig");
const rl = @import("../../core/external/raylib.zig");

const utils = @import("../../core/utils.zig");


pub const GameObject = struct {
    const Self = @This();

    id: usize,
    components: std.ArrayList(*IComponent),
    allocator: std.mem.Allocator,
    logger: *const log.Logger,

    fn create(allocator: std.mem.Allocator, logger: *const log.Logger) Self {
        return Self{
            .id = 0, // TODO: assign unique id
            .components = std.ArrayList(*IComponent).init(allocator),
            .allocator = allocator,
            .logger = logger,
        };
    }

    fn destroy(self: *Self) void {
        // TODO: free all components itself
        self.components.deinit();
    }

    fn update(self: *Self, dt: f32) void {
        for (self.components.items) |comp| {
            comp.update(dt);
        }
        //self.logger.app_log(log.LogLevel.info, "Updating game object", .{});
    }

    pub fn addComponent(
        self: *Self, 
        comptime CompDataT: type,
        component_data: CompDataT,
    ) *Self {
        const component = self.allocator.create(Component(CompDataT)) catch |err| {
            self.logger.core_log(log.LogLevel.err, "Could not create component: {any}", .{err});
            return self;
        };
        component.* = Component(CompDataT).create(component_data);

        self.components.append(&component.icomponent) catch |err| {
            self.logger.core_log(log.LogLevel.err, "Could not add component to the game object: {any}", .{err});
            self.allocator.destroy(component);
            return self;
        };

        return self;
    }

    pub fn getComponentDataMut(self: *const Self, comptime T: type) ?*T {
        for (self.components.items) |comp| {
            const data = comp.getDataMut(T);
            if (data != null) return data;
        }
        return null;
    }

    pub fn getComponentData(self: *const Self, comptime T: type) ?*const T {
        for (self.components.items) |comp| {
            const data = comp.getData(T);
            if (data != null) return data;
        }
        return null;
    }
};

pub const GameObjectWorldPlugin = struct {
    const Self = @This();

    iplugin: gg.IPlugin,

    objects: std.ArrayList(GameObject),
    allocator: std.mem.Allocator,
    logger: *const log.Logger,

    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IPlugin {
        var world: *Self = try app.gpa.create(Self);

        world.iplugin.updateFn = update;
        world.iplugin.startUpFn = startUp;
        world.iplugin.tearDownFn = tearDown;
        world.iplugin.getTypeIdFn = getTypeId;
        world.objects = std.ArrayList(GameObject).init(app.gpa);
        world.allocator = app.gpa;
        world.logger = &app.logger;

        return &world.iplugin;
    }

    pub fn foo(self: *const Self) void {
        self.logger.core_log(log.LogLevel.info, "Foo", .{});
    }

    pub fn newObject(self: *Self) ?*GameObject {
        self.objects.append(GameObject.create(self.allocator, self.logger)) catch |err| {
            self.logger.core_log(log.LogLevel.err, "Could not create game object: {any}", .{err});
            return null;
        };

        return &self.objects.items[self.objects.items.len - 1];
    } 

    fn startUp(_: *gg.IPlugin) void {
    }

    fn update(iplugin: *gg.IPlugin, dt: f32) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin);
        for (self.objects.items) |*o| {
            o.update(dt);
        }
    }

    fn tearDown(iplugin: *gg.IPlugin) void {
        var self: *Self = @fieldParentPtr("iplugin", iplugin);
        for (self.objects.items) |*o| {
            o.destroy();
        }
        self.objects.deinit();
        self.allocator.destroy(self);
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }
};

pub const IComponent = struct {
    getDataMutFn: *const fn (*IComponent) *anyopaque,
    getDataFn: *const fn (*const IComponent) *const anyopaque,
    getDataTypeIdFn: *const fn(*const IComponent) usize,
    updateFn: *const fn(*IComponent, f32) void,

    pub fn getDataMut(self: *IComponent, comptime T: type) ?*T {
        if (self.getDataTypeId() != utils.typeId(T)) return null;
        return @ptrCast(@alignCast(self.getDataMutFn(self)));
    }

    pub fn getData(self: *const IComponent, comptime T: type) ?*const T {
        if (self.getDataTypeId() != utils.typeId(T)) return null;
        const data = self.getDataFn(self);
        return @ptrCast(@alignCast(data));
    }

    pub fn getDataTypeId(self: *const IComponent) usize {
        return self.getDataTypeIdFn(self);
    }

    pub fn update(self: *IComponent, dt: f32) void {
        self.updateFn(self, dt);
    }

};

pub fn Component(comptime T: type) type {
    return struct {
        data: T,
        icomponent: IComponent,

        pub fn create(component_data: T) Component(T) {
            return .{
                .data = component_data,
                .icomponent = IComponent{
                    .getDataMutFn = getDataMut, 
                    .getDataFn = getData,
                    .getDataTypeIdFn = getDataTypeId,
                    .updateFn = update,
                },
            };
        }

        pub fn getDataMut(icomponent: *IComponent) *anyopaque {
            var self: *Component(T) = @fieldParentPtr("icomponent", icomponent);
            return &self.data;
        }

        pub fn getData(icomponent: *const IComponent) *const anyopaque {
            const self: *const Component(T) = @fieldParentPtr("icomponent", icomponent);
            return &self.data;
        }

        fn getDataTypeId(_: *const IComponent) utils.TypeId {
            return utils.typeId(T);
        }

        pub fn update(icomponent: *IComponent, dt: f32) void {
            const self: *Component(T) = @fieldParentPtr("icomponent", icomponent);
            self.data.update(dt);
        }
    };
}
