const std = @import("std");

const Foo = struct {
    a: i32,
};

fn bar(f: anytype) void {
    const foo: Foo = f;
    std.debug.print("{}\n", .{foo.a});
}

pub fn main() !void {
    bar(Foo{.a = 69});
}
