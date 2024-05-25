const std = @import("std");

pub const LogLevel = enum(i32) {
    all     = 0,
    trace   = 1,
    debug   = 2,
    info    = 3,
    warning = 4,
    err     = 5,
    fatal   = 6,
    none    = 7,

    pub fn to_string(self: *const LogLevel) [:0]const u8 {
        return switch (self.*) {
            LogLevel.all => "ALL",
            LogLevel.trace => "TRACE",
            LogLevel.debug => "DEBUG",
            LogLevel.info => "INFO",
            LogLevel.warning => "WARNING",
            LogLevel.err => "ERROR",
            LogLevel.fatal => "FATAL",
            LogLevel.none => "NONE",
        };
    }

    pub fn lessThan(self: *const LogLevel, other: LogLevel) bool {
        return @intFromEnum(self.*) < @intFromEnum(other);
    }
};


pub const Logger = struct {
    const Self = @This();

    var log_level: LogLevel = LogLevel.info;

    pub fn app_log(
        comptime level: LogLevel, 
        comptime fmt: [:0]const u8, 
        args: anytype
    ) void {
        if (level.lessThan(Self.log_level)) return;

        const level_str = comptime level.to_string();
        std.debug.print("APP:" ++ level_str ++ ": " ++ fmt ++ "\n", args);
    }

    pub fn core_log(
        comptime level: LogLevel, 
        comptime fmt: [:0]const u8, 
        args: anytype
    ) void {
        if (level.lessThan(Self.log_level)) return;

        const level_str = comptime level.to_string();
        std.debug.print("CORE:" ++ level_str ++ ": " ++ fmt ++ "\n", args);
    }
};

