const std = @import("std");

pub const Inst = std.math.ByteAlignedInt(std.math.IntFittingRange(-999, 999));
pub const Memory = [100]Inst;
