// This file is auto-generated by build.zig. Do not modify manually.
pub const VERSION = "0.1.0";
pub const GIT_COMMIT = "cd4cace";
pub const BUILD_DATE = "07.03.2025 22:35:24,53";

pub const VersionInfo = struct {
    version: []const u8,
    git_commit: []const u8,
    build_date: []const u8,
};

pub fn getVersionInfo() VersionInfo {
    return VersionInfo{
        .version = VERSION,
        .git_commit = GIT_COMMIT,
        .build_date = BUILD_DATE,
    };
}