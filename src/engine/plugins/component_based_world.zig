const std = @import("std");
const log = @import("../core/log.zig");
const gg = @import("../core/gamgine.zig");
const rl = @import("../core/external/raylib.zig");

fn typeId(comptime T: type) usize {
    const H = struct {
        var byte: u8 = 0;
        var _ = T;
    };

    return @intFromPtr(&H.byte);
}


pub const GameObject = struct {
    const Self = @This();

    id: usize,
    components: std.ArrayList(*IComponent),
    allocator: std.mem.Allocator,
    logger: *const log.Logger,

    fn create(allocator: std.mem.allocator, logger: *const log.Logger) Self {
        return Self{
            .id = 0, // TODO: assign unique id
            .components = std.ArrayList(*IComponent).init(allocator),
            .allocator = allocator,
            .logger = logger,
        };
    }

    fn destroy(self: *Self) void {
        // TODO: free all components itself
        self.components.free();
    }

    pub fn addComponent(
        self: *Self, 
        comptime CompDataT: type,
        component_data: CompDataT,
    ) *Self {
        var component = self.allocator.create(Component(CompDataT).create(component_data)) catch |err| {
            self.logger.core_log(log.LogLevel.err, "Could not create component: {any}", .{err});
            return self;
        };

        self.components.append(&component) catch |err| {
            self.logger.core_log(log.LogLevel.err, "Could not add component to the game object: {any}", .{err});
            self.allocator.destroy(component);
            return self;
        };

        return self;
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
        world.objects = std.ArrayList(GameObject).init(app.gpa);
        world.allocator = app.gpa;
        world.logger = &app.logger;

        return &world.iplugin;
    }

    pub fn newObject(self: *Self) ?*GameObject {
        try self.objects.append(GameObject.create(self.allocator, self.logger)) catch |err| {
            self.logger.core_log(log.LogLevel.err, "Could not create game object: {any}", .{err});
            return null;
        };

        return &self.objects.items[self.object.items.len - 1];
    } 

    fn startUp(_: *gg.IPlugin) void {
    }

    fn update(iplugin: *gg.IPlugin, _: f32) void {
        _ = iplugin;
        // temp code to render something because it is the only plugin yet
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.RAYWHITE);
    }
};

pub const IComponent = struct {
    getDataMutFn: *const fn (*IComponent) *anyopaque,
    getDataFn: *const fn (*const IComponent) *const anyopaque,
    getDataTypeIdFn: *const fn(*const IComponent) usize,

    pub fn getDataMut(self: *IComponent, comptime T: type) ?*T {
        if (self.getDataTypeId() != typeId(T)) return null;
        return @ptrCast(@alignCast(self.getDataMutFn(self)));
    }

    pub fn getData(self: *const IComponent, comptime T: type) ?*const T {
        if (self.getDataTypeId() != typeId(T)) return null;
        const data = self.getDataFn(self);
        return @ptrCast(@alignCast(data));
    }

    pub fn getDataTypeId(self: *const IComponent) usize {
        return self.getDataTypeIdFn(self);
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

        fn getDataTypeId(icomponent: *const IComponent) usize {
            _ = icomponent;
            return typeId(T);
        }
    };
}
