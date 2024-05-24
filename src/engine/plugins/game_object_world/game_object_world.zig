const std = @import("std");
const log = @import("../../core/log.zig");
const gg = @import("../../core/gamgine.zig");
const rl = @import("../../core/external/raylib.zig");

const utils = @import("../../core/utils.zig");


pub const GameObject = struct {
    const Self = @This();

    pub const max_name_length = 255;
    
    id: usize,
    name: [max_name_length + 1]u8, // cstr
    is_active: bool,
    components: std.ArrayList(*IComponent),
    allocator: std.mem.Allocator,
    app: *const gg.GamgineApp,

    fn create(name: []const u8, allocator: std.mem.Allocator, app: *const gg.GamgineApp) Self {
        var go = Self{
            .id = 0, // TODO: assign unique id
            .name = std.mem.zeroes([max_name_length + 1]u8),
            .is_active = true,
            .components = std.ArrayList(*IComponent).init(allocator),
            .allocator = allocator,
            .app = app,
        };


        const copy_len = if (name.len <= max_name_length) name.len else max_name_length;
        std.mem.copyForwards(u8, &go.name, name[0..copy_len]);
        go.name[copy_len] = 0;

        return go;
    }

    fn destroy(self: *Self) void {
        for (self.components.items) |comp| {
            comp.destroy(self);
        }
        self.components.deinit();
    }

    fn update(self: *Self, dt: f32) void {
        if (!self.is_active) return;

        for (self.components.items) |comp| {
            comp.update(dt, self);
        }
    }

    fn start(self: *Self) void {
        for (self.components.items) |comp| {
            comp.start(self);
        }
    }

    pub fn nameSlice(self: *const Self) []const u8 {
        const len = std.mem.len(@as([*:0]const u8, @ptrCast(&self.name)));
        return self.name[0..len];
    }

    pub fn setActive(self: *Self, active: bool) void {
        self.is_active = active;

        for (self.components.items) |comp| {
            comp.setActive(active);
        }
    }

    pub fn clone(self: *const Self, world: *GameObjectWorldPlugin) ?*GameObject {
        const maybe_cloned_go = world.newObject(self.nameSlice());

        if (maybe_cloned_go) |cloned_go| {
            for (self.components.items) |comp| {
                const maybe_cloned_icomp = comp.clone(self.allocator);
                if (maybe_cloned_icomp) |cloned_icomp| {
                    cloned_go.components.append(cloned_icomp) catch |err| {
                        self.app.logger.core_log(log.LogLevel.err, "Could not add component to the game object: {any}", .{err});
                        cloned_icomp.destroy(cloned_go);
                        continue;
                    };
                }
            }

            cloned_go.start();

            return cloned_go;
        } else {
            return null;
        }
    }

    pub fn addComponent(
        self: *Self, 
        comptime CompDataT: type,
        component_data: CompDataT,
    ) *Self {
        const component = Component(CompDataT).make(component_data, self.allocator) orelse {
            self.app.logger.core_log(log.LogLevel.err, "Could not create component.", .{});
            return self;
        };

        self.components.append(&component.icomponent) catch |err| {
            self.app.logger.core_log(log.LogLevel.err, "Could not add component to the game object: {any}", .{err});
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
    objectsToDestroy: std.ArrayList(*const GameObject),

    prefabs: std.StringArrayHashMap(GameObject), // TODO: maybe use just HashMap ?

    allocator: std.mem.Allocator,
    app: *const gg.GamgineApp,

    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IPlugin {
        var world: *Self = try app.gpa.create(Self);

        world.iplugin.updateFn = update;
        world.iplugin.startUpFn = startUp;
        world.iplugin.tearDownFn = tearDown;
        world.iplugin.getTypeIdFn = getTypeId;
        world.objects = std.ArrayList(GameObject).init(app.gpa);
        world.objectsToDestroy = std.ArrayList(*const GameObject).init(app.gpa);
        world.prefabs = std.StringArrayHashMap(GameObject).init(app.gpa);
        world.allocator = app.gpa;
        world.app = app;

        return &world.iplugin;
    }

    pub fn newObject(self: *Self, name: []const u8) ?*GameObject {
        self.objects.append(GameObject.create(name, self.allocator, self.app)) catch |err| {
            self.app.logger.core_log(log.LogLevel.err, "Could not create game object: {any}", .{err});
            return null;
        };

        return &self.objects.items[self.objects.items.len - 1];
    } 

    pub fn destroyObject(self: *Self, game_object: *GameObject) void {
        self.objectsToDestroy.append(game_object) catch |err| {
            self.app.logger.core_log(log.LogLevel.err, "Could not schedule destruction of object {any}", .{err});
        }; 
    }

    pub fn createPrefab(self: *Self, name: []const u8) ?*GameObject {
        if (self.getPrefab(name) != null) return null;

        self.prefabs.put(name, GameObject.create(name, self.allocator, self.app)) catch |err| {
            self.app.logger.core_log(log.LogLevel.err, "Could not create prefab {s}: {any}", .{name, err});
            return null;
        };

        return self.getPrefab(name);
    }

    pub fn getPrefab(self: *Self, name: []const u8) ?*GameObject {
        return self.prefabs.getPtr(name);
    }

    pub fn destroyPrefab(self: *Self, name: []const u8) void {
        _ = self.prefabs.swapRemove(name);
    }

    fn startUp(_: *gg.IPlugin) void {
    }

    fn update(iplugin: *gg.IPlugin, dt: f32) void {
        const self: *Self = @fieldParentPtr("iplugin", iplugin); 

        for (self.objectsToDestroy.items) |obj| {
            for (0..self.objects.items.len) |i| {
                if (&self.objects.items[i] == obj) {
                    self.objects.items[i].destroy();
                    _ = self.objects.swapRemove(i);
                    break;
                }
            }
        }

        self.objectsToDestroy.clearRetainingCapacity();

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
        self.objectsToDestroy.deinit();
        self.prefabs.deinit();
        self.allocator.destroy(self);
    }

    pub fn startWorld(self: *const Self) void {
        for (self.objects.items) |*obj| {
            obj.start();
        }
    }

    pub fn clean(self: *Self) void {
        for (self.objects.items) |*o| {
            o.destroy();
        }
        self.objects.clearRetainingCapacity();
        self.objectsToDestroy.clearRetainingCapacity();
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }
};

pub const IComponent = struct {
    getDataMutFn: *const fn (*IComponent) *anyopaque,
    getDataFn: *const fn (*const IComponent) *const anyopaque,
    getDataTypeIdFn: *const fn(*const IComponent) usize,

    startFn: *const fn(*IComponent, *GameObject) void,
    updateFn: *const fn(*IComponent, f32, *GameObject) void,
    destroyFn: *const fn(*IComponent, *GameObject) void,

    cloneFn: *const fn(*const IComponent, std.mem.Allocator) ?*IComponent,

    setActiveFn: *const fn (*IComponent, active: bool) void,
    is_active: bool = true,

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

    pub fn start(self: *IComponent, owner: *GameObject) void {
        self.startFn(self, owner);
    }

    pub fn update(self: *IComponent, dt: f32, owner: *GameObject) void {
        if (!self.is_active) return;

        self.updateFn(self, dt, owner);
    }

    pub fn destroy(self: *IComponent, owner: *GameObject) void {
        self.destroyFn(self, owner);
    }

    pub fn clone(self: *const IComponent, allocator: std.mem.Allocator) ?*IComponent {
        return self.cloneFn(self, allocator);
    }

    pub fn setActive(self: *IComponent, active: bool) void {
        self.setActiveFn(self, active);
    }
};

pub fn Component(comptime T: type) type {
    return struct {
        const Self = @This();

        data: T,
        icomponent: IComponent,

        pub fn create(component_data: T) Component(T) {
            return .{
                .data = component_data,
                .icomponent = IComponent{
                    .getDataMutFn = getDataMut, 
                    .getDataFn = getData,
                    .getDataTypeIdFn = getDataTypeId,
                    .startFn = start,
                    .updateFn = update,
                    .destroyFn = destroy,
                    .cloneFn = clone,
                    .setActiveFn = setActive,
                },
            };
        }
        
        pub fn make(component_data: T, allocator: std.mem.Allocator) ?*Component(T) {
            const component = allocator.create(Component(T)) catch {
                return null;
            };

            component.* = Component(T).create(component_data);

            return component;
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

        pub fn start(icomponent: *IComponent, owner: *GameObject) void {
            const self: *Component(T) = @fieldParentPtr("icomponent", icomponent);
            self.data.start(owner);
        }

        pub fn update(icomponent: *IComponent, dt: f32, owner: *GameObject) void {
            const self: *Component(T) = @fieldParentPtr("icomponent", icomponent);
            self.data.update(dt, owner);
        }
        
        pub fn destroy(icomponent: *IComponent, owner: *GameObject) void {
            const self: *Component(T) = @fieldParentPtr("icomponent", icomponent);
            self.data.destroy(owner);
        }

        pub fn clone(icomponent: *const IComponent, allocator: std.mem.Allocator) ?*IComponent {
            const self: *const Component(T) = @fieldParentPtr("icomponent", icomponent);
            const maybe_comp = Component(T).make(self.data.clone(), allocator);

            if (maybe_comp) |comp| {
                return &comp.icomponent;
            } else {
                return null;
            }
        }

        pub fn setActive(icomponent: *IComponent, active: bool) void {
            const self: *Component(T) = @fieldParentPtr("icomponent", icomponent);
            icomponent.is_active = active;
            self.data.setActive(active);
        }
    };
}
