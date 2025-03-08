const ver = @import("zeta_version");
const std = @import("std");
pub fn main() !void {
    std.debug.print("Build Hash {s}", .{ver.getVersionInfo().build_meta});
}
//fixed
