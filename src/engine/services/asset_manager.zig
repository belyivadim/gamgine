const std = @import("std");
const rl = @import("../core/external/raylib.zig");
const gg = @import("../core/gamgine.zig");
const log = @import("../core/log.zig");
const utils = @import("../core/utils.zig");

pub const AssetManager = struct {
    const Self = @This();

    var iservice: gg.IService = undefined;

    var textures: std.StringHashMap(TextureAsset) = undefined;

    pub fn make(app: *const gg.GamgineApp) error{OutOfMemory}!*gg.IService {
        Self.iservice.startUpFn = startUp;
        Self.iservice.tearDownFn = tearDown;
        Self.iservice.getTypeIdFn = getTypeId;

        Self.textures = std.StringHashMap(TextureAsset).init(app.gpa);

        return &Self.iservice;
    }


    fn startUp(_: *gg.IService) void {
    }


    fn tearDown(_: *gg.IService) void {
        var it = Self.textures.valueIterator();
        while (it.next()) |asset| {
            rl.UnloadTexture(asset.texture);
        }
        Self.textures.deinit();
    }

    pub fn getTypeId() utils.TypeId {
        return utils.typeId(Self);
    }

    pub fn getAsset(comptime T: type, name: []const u8) ?*T {
        switch (T) {
            TextureAsset => return Self.textures.getPtr(name),
            else => return null,
        }
    }
};

pub const TextureAsset = struct {
    const Self = @This();

    texture: rl.Texture,

    pub fn updateFromImage(self: *Self, image: rl.Image) void {
        std.debug.assert(self.texture.width == image.width);
        std.debug.assert(self.texture.height == image.height);

        rl.UpdateTexture(self.texture, image.data);
    }

    pub fn load(path: []const u8) ?*Self {
        if (Self.alreadyLoaded(path)) {
            return null;
        }

        const texture = rl.LoadTexture(path);
        return Self.loadFromMemoryForced(texture, path);
    }

    pub fn loadFromMemory(texture: rl.Texture, name: []const u8) ?*Self {
        if (Self.alreadyLoaded(name)) {
            rl.UnloadTexture(texture);
            return null;
        }

        return Self.loadFromMemoryForced(texture, name);
    } 

    pub fn reload(path: []const u8) ?*Self {
        if (!AssetManager.textures.contains(path)) {
            log.Logger.core_log(log.LogLevel.warning, "Could not reload TextureAsset \"{s}\", because it is not already loaded.", .{path});
            log.Logger.core_log(log.LogLevel.info, "NOTE: if you want to load asset, use `load` function instead.", .{});
            return null;
        }

        const texture = rl.LoadTexture(path);
        return Self.loadFromMemoryForced(texture, path);
    }

    pub fn unload(name: []const u8) void {
        const maybe_kv = AssetManager.textures.fetchRemove(name);
        if (maybe_kv) |kv| {
            rl.UnloadTexture(kv.value.texture);
        }
    }

    fn loadFromMemoryForced(texture: rl.Texture, name: []const u8) ?*Self {
        if (!rl.IsTextureReady(texture)) {
            log.Logger.core_log(log.LogLevel.err, "Texture: \"{s}\" is not ready.", .{name});
            rl.UnloadTexture(texture);
            return null;
        }

        AssetManager.textures.put(name, Self{.texture = texture}) catch |err| {
            log.Logger.core_log(log.LogLevel.err, "Could not add texture \"{s}\" to the AssetManager: {any}", .{name, err});
            rl.UnloadTexture(texture);
            return null;
        };

        return AssetManager.textures.getPtr(name);
    }

    fn alreadyLoaded(name: []const u8) bool {
        if (AssetManager.textures.contains(name)) {
            log.Logger.core_log(log.LogLevel.warning, "Could not load TextureAsset \"{s}\", because it was already loaded.", .{name});
            log.Logger.core_log(log.LogLevel.info, "NOTE: if you want to reload asset, use `reload` function instead.", .{});
            return true;
        }

        return false;
    }
};
