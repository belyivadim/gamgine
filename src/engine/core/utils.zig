pub const TypeId = usize;

pub fn typeId(comptime T: type) TypeId {
    const H = struct {
        var byte: u8 = 0;
        var _ = T;
    };

    return @intFromPtr(&H.byte);
}
