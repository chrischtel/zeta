const std = @import("std");
const Alloc = std.mem.Allocator;
const time = std.time;
const fs = std.fs;
const builtin = @import("builtin");

/// FileType represents the type of file system entry across platforms
pub const FileType = enum {
    regular,
    directory,
    symlink,
    special, // Covers devices, pipes, sockets for cross-platform simplicity
    unknown,

    /// Determine file type from stat info with platform-specific handling
    pub fn fromFileKind(kind: fs.File.Kind) FileType {
        return switch (kind) {
            .file => .regular,
            .directory => .directory,
            .sym_link => .symlink,
            // Handle all special types generically for cross-platform compatibility
            .block_device, .character_device, .named_pipe, .unix_domain_socket, .whiteout => .special,
            else => .unknown,
        };
    }
};

/// Platform-agnostic file permissions
// Enhanced FilePermissions structure
pub const FilePermissions = struct {
    readable: bool,
    writable: bool,
    executable: bool,
    hidden: bool,

    // Unix specific (will be false on Windows)
    owner_read: bool = false,
    owner_write: bool = false,
    owner_execute: bool = false,
    group_read: bool = false,
    group_write: bool = false,
    group_execute: bool = false,
    other_read: bool = false,
    other_write: bool = false,
    other_execute: bool = false,

    // Windows specific
    system: bool = false,
    archive: bool = false,

    // Format permissions for display
    // Format permissions for display
    pub fn format(self: FilePermissions, file_type: FileType) []const u8 {
        // Create a static buffer for the result
        var buf: [10]u8 = undefined;

        if (builtin.os.tag == .windows) {
            // Windows-style attributess
            buf[0] = if (self.readable) @as(u8, 'R') else @as(u8, '-');
            buf[1] = if (self.writable) @as(u8, 'W') else @as(u8, '-');
            buf[2] = if (self.hidden) @as(u8, 'H') else @as(u8, '-');
            buf[3] = if (file_type == .directory) @as(u8, 'D') else @as(u8, '-');
            return buf[0..4];
        } else {
            // Unix-style permissions
            buf[0] = if (self.owner_read) @as(u8, 'r') else @as(u8, '-');
            buf[1] = if (self.owner_write) @as(u8, 'w') else @as(u8, '-');
            buf[2] = if (self.owner_execute) @as(u8, 'x') else @as(u8, '-');
            buf[3] = if (self.group_read) @as(u8, 'r') else @as(u8, '-');
            buf[4] = if (self.group_write) @as(u8, 'w') else @as(u8, '-');
            buf[5] = if (self.group_execute) @as(u8, 'x') else @as(u8, '-');
            buf[6] = if (self.other_read) @as(u8, 'r') else @as(u8, '-');
            buf[7] = if (self.other_write) @as(u8, 'w') else @as(u8, '-');
            buf[8] = if (self.other_execute) @as(u8, 'x') else @as(u8, '-');
            return buf[0..9];
        }
    }

    pub fn fromPath(path: []const u8) FilePermissions {
        // Create default permissions without checking the actual file
        var perms = FilePermissions{
            .readable = true,
            .writable = true,
            .executable = false,
            .hidden = false,
        };

        // Check if file is hidden based on name
        const name = std.fs.path.basename(path);
        if (name.len > 0 and name[0] == '.') {
            perms.hidden = true;
        }

        // For executable files on Windows, check extension
        if (builtin.os.tag == .windows) {
            const ext = std.fs.path.extension(path);
            if (std.mem.eql(u8, ext, ".exe") or
                std.mem.eql(u8, ext, ".bat") or
                std.mem.eql(u8, ext, ".cmd"))
            {
                perms.executable = true;
            }
        }

        return perms;
    }
};
/// FileEntry represents a single file system entry with cross-platform metadata
pub const FileEntry = struct {
    /// Allocator that owns the entry's strings
    allocator: Alloc,
    /// Full path to the file
    path: []const u8,
    /// Just the filename portion
    name: []const u8,
    /// File type (regular, directory, etc)
    file_type: FileType,
    /// File size in bytes
    size: u64,
    /// File permissions in platform-agnostic format
    permissions: FilePermissions,
    /// Last modification time (seconds since epoch)
    mtime: i64,
    /// Creation time if available (seconds since epoch)
    ctime: i64,
    /// File extension (if any)
    extension: []const u8,

    /// Create a FileEntry from a directory entry and its stat info
    pub fn init(
        allocator: Alloc,
        dir_path: []const u8,
        entry_name: []const u8,
        stat: fs.File.Stat,
        follow_symlinks: bool,
    ) !FileEntry {
        // Allocate and store the path and name
        const name_copy = try allocator.dupe(u8, entry_name);
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry_name });

        // Find extension
        var extension: []const u8 = "";
        if (std.mem.lastIndexOf(u8, entry_name, ".")) |dot_index| {
            if (dot_index < entry_name.len - 1) {
                extension = try allocator.dupe(u8, entry_name[dot_index + 1 ..]);
            }
        }

        // Get file type
        const file_type = FileType.fromFileKind(stat.kind);

        // Get correct size for symlinks if needed
        const size = stat.size;
        if (follow_symlinks and file_type == .symlink) {
            // In a real implementation, you'd get the target info here
            // For now we'll just use the link's size
        }

        // Get permissions, handling any errors
        const permissions = FilePermissions.fromPath(full_path);

        return FileEntry{
            .allocator = allocator,
            .path = full_path,
            .name = name_copy,
            .file_type = file_type,
            .size = size,
            .permissions = permissions,
            .mtime = @intCast(@divFloor(stat.mtime, std.time.ns_per_s)),
            .ctime = @intCast(@divFloor(stat.ctime, std.time.ns_per_s)),
            .extension = extension,
        };
    }

    /// Free memory owned by this entry
    pub fn deinit(self: *FileEntry) void {
        self.allocator.free(self.path);
        self.allocator.free(self.name);
        if (self.extension.len > 0) {
            self.allocator.free(self.extension);
        }
    }
};

pub fn readDirectory(
    allocator: Alloc,
    path: []const u8,
    options: struct {
        include_hidden: bool = false,
        follow_symlinks: bool = false,
    },
) ![]FileEntry {
    var dir = try fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList(FileEntry).init(allocator);
    defer {
        if (@errorReturnTrace()) |_| {
            for (entries.items) |*entry| {
                entry.deinit();
            }
            entries.deinit();
        }
    }

    var it = dir.iterate();
    while (try it.next()) |entry| {
        // Skip hidden files if not requested
        if (!options.include_hidden and entry.name.len > 0 and entry.name[0] == '.') {
            continue;
        }

        // Use entry.kind to determine file type
        var file_info: fs.File.Stat = undefined;

        // Handle entries based on their type
        if (entry.kind == .directory) {
            // For directories, use a different approach
            var subdir = dir.openDir(entry.name, .{}) catch |err| {
                std.log.warn("Failed to open directory {s}: {s}", .{ entry.name, @errorName(err) });
                continue;
            };
            defer subdir.close();

            file_info = subdir.stat() catch |err| {
                std.log.warn("Failed to stat directory {s}: {s}", .{ entry.name, @errorName(err) });
                continue;
            };
        } else {
            // For regular files and other types, use statFile
            file_info = dir.statFile(entry.name) catch |err| {
                std.log.warn("Failed to stat {s}: {s}", .{ entry.name, @errorName(err) });
                continue;
            };
        }

        // Create entry
        const file_entry = try FileEntry.init(allocator, path, entry.name, file_info, options.follow_symlinks);
        try entries.append(file_entry);
    }

    // Return the entries
    return entries.toOwnedSlice();
}

/// Free an array of FileEntries
pub fn freeDirectoryEntries(allocator: Alloc, entries: []FileEntry) void {
    for (entries) |*entry| {
        entry.deinit();
    }
    allocator.free(entries);
}
