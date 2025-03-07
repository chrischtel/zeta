// src/version.zig
pub const VERSION = "0.1.0";
pub const GIT_COMMIT = @embedFile("git_commit.txt");
pub const BUILD_DATE = @embedFile("build_date.txt");

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
