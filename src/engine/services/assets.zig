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

    pub fn getOrLoad(path: []const u8) ?*Self {
        const maybe_asset = AssetManager.getAsset(TextureAsset, path);
        if (maybe_asset) |asset| return asset;

        const texture = rl.LoadTexture(@ptrCast(path));
        return Self.loadFromMemoryForced(texture, path);
    }

    pub fn getOrLoadResized(path: []const u8, desired_width: i32, desired_height: i32) ?*Self {
        var old_texture: ?rl.Texture = null;

        const maybe_asset = AssetManager.getAsset(TextureAsset, path);
        if (maybe_asset) |asset| {
            if (asset.texture.width == desired_width and asset.texture.height == desired_height) {
                return asset;
            } else {
                old_texture = asset.texture;
            }
        }

        var image = rl.LoadImage(@ptrCast(path));
        rl.ImageResizeNN(&image, desired_width, desired_height);
        if (!rl.IsImageReady(image)) {
            log.Logger.core_log(log.LogLevel.err, "Could not resize the image from file {s}", .{path});
            rl.UnloadImage(image);
            return null;
        }

        const new_texture = rl.LoadTextureFromImage(image);
        const maybe_new_asset = Self.loadFromMemoryForced(new_texture, path);

        if (maybe_new_asset == null) return null;

        if (old_texture) |texture| {
            rl.UnloadTexture(texture);
        }

        return maybe_new_asset;
    }

    pub fn getOrLoadResizedHeight(path: []const u8, desired_height: i32) ?*Self {
        var old_texture: ?rl.Texture = null;

        const maybe_asset = AssetManager.getAsset(TextureAsset, path);
        if (maybe_asset) |asset| {
            if (asset.texture.height == desired_height) {
                return asset;
            } else {
                old_texture = asset.texture;
            }
        }

        var image = rl.LoadImage(@ptrCast(path));
        if (!rl.IsImageReady(image)) {
            log.Logger.core_log(log.LogLevel.err, "Could not load image from file {s}", .{path});
            rl.UnloadImage(image);
            return null;
        }

        const desired_width = image.width * @divFloor(desired_height, image.height);
        rl.ImageResizeNN(&image, desired_width, desired_height);
        if (!rl.IsImageReady(image)) {
            log.Logger.core_log(log.LogLevel.err, "Could not resize the image from file {s}", .{path});
            rl.UnloadImage(image);
            return null;
        }

        const new_texture = rl.LoadTextureFromImage(image);
        const maybe_new_asset = Self.loadFromMemoryForced(new_texture, path);

        if (maybe_new_asset == null) return null;

        if (old_texture) |texture| {
            rl.UnloadTexture(texture);
        }

        return maybe_new_asset;
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


    pub fn loadBlankTextureWithColor(
        name: []const u8, 
        color: rl.Color, 
        width: i32, height: i32, 
        allocator: std.mem.Allocator
    ) ?*Self {
        if (Self.alreadyLoaded(name)) {
            return null;
        }

        const pixels = allocator.alloc(rl.Color, @intCast(width * height)) catch {
            return null;
        };
        defer allocator.free(pixels);
        @memset(pixels, color);

        const img = rl.Image{
            .data = @ptrCast(pixels),
            .width = width,
            .height = height,
            .mipmaps = 1,
            .format = rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        };

        const texture = rl.LoadTextureFromImage(img);

        return Self.loadFromMemoryForced(texture, name);
    }
};
