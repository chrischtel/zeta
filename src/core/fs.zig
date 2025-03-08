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
        std.debug.print("File kind: {any}\n", .{kind});

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
pub const FilePermissions = struct {
    /// Can the file be read
    readable: bool,
    /// Can the file be written
    writable: bool,
    /// Can the file be executed
    executable: bool,
    /// Is this a hidden file
    hidden: bool,

    /// Create from platform-specific info
    pub fn fromPath(path: []const u8) FilePermissions {
        const name = std.fs.path.basename(path);

        // Default permissions - would need actual file checks in real implementation
        var perms = FilePermissions{
            .readable = true,
            .writable = true,
            .executable = false,
            .hidden = false,
        };

        // Handle hidden files across platforms
        if (name.len > 0 and name[0] == '.') {
            perms.hidden = true;
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

        return FileEntry{
            .allocator = allocator,
            .path = full_path,
            .name = name_copy,
            .file_type = file_type,
            .size = size,
            .permissions = FilePermissions.fromPath(full_path),
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
