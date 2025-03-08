const ver = @import("zeta_version");
const std = @import("std");
pub fn main() !void {
    const info = ver.getVersionInfo();

    std.debug.print("Version: {s}\n", .{info.version});
    std.debug.print("Core Version: {s}\n", .{info.version_core});
    std.debug.print("Prerelease: {s}\n", .{if (info.prerelease) |p| p else "none"});
    std.debug.print("Build Metadata: {s}\n", .{info.build_meta});
    std.debug.print("Git Commit: {s}\n", .{info.git_commit});
    std.debug.print("Build Date: {s}\n", .{info.build_date});
    std.debug.print("Is Prerelease: {}\n", .{info.isPrerelease()});
}
