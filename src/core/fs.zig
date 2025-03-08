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
    pub fn fromFileInfo(info: fs.File.Stat) FileType {
        return switch (info.kind) {
            .File => .regular,
            .Directory => .directory,
            .SymLink => .symlink,
            // Handle all special types generically for cross-platform compatibility
            .BlockDevice, .CharacterDevice, .NamedPipe, .UnixDomainSocket, .Whiteout => .special,
            else => .unknown,
        };
    }
};

/// Platform-agnostic file permissions
pub const FilePermissions = struct {
    /// Can the owner read
    owner_read: bool,
    /// Can the owner write
    owner_write: bool,
    /// Can the owner execute
    owner_execute: bool,
    /// Is this a readonly file
    readonly: bool,
    /// Is this a hidden file
    hidden: bool,
    /// Is this a system file (Windows)
    system: bool,

    /// Create from platform-specific file mode
    pub fn fromFileMode(mode: fs.File.Mode, name: []const u8) FilePermissions {
        var perms = FilePermissions{
            .owner_read = mode.read_owner,
            .owner_write = mode.write_owner,
            .owner_execute = mode.execute_owner,
            .readonly = !mode.write_owner,
            .hidden = false,
            .system = false,
        };

        // Handle hidden files across platforms
        if (name.len > 0 and name[0] == '.') {
            perms.hidden = true;
        }

        // Windows-specific attributes would be handled here in a real implementation
        // You'd need to use Windows-specific APIs for full attribute support

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
    /// Last modification time (nanoseconds since epoch)
    mtime: i128,
    /// Creation time (nanoseconds since epoch)
    ctime: i128,
    /// File extension (if any)
    extension: []const u8,

    /// Create a FileEntry from a directory entry and its stat info
    pub fn init(
        allocator: Alloc,
        dir_path: []const u8,
        entry_name: []const u8,
        stat: fs.File.Stat,
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

        return FileEntry{
            .allocator = allocator,
            .path = full_path,
            .name = name_copy,
            .file_type = FileType.fromFileInfo(stat),
            .size = stat.size,
            .permissions = FilePermissions.fromFileMode(stat.mode, entry_name),
            .mtime = stat.mtime,
            .ctime = stat.ctime,
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

/// Read all entries in a directory, returning an allocated slice of FileEntries
pub fn readDirectory(
    allocator: Alloc,
    path: []const u8,
    options: struct {
        include_hidden: bool = false,
        follow_symlinks: bool = false,
    },
) ![]FileEntry {
    // Handle paths in a cross-platform way
    const clean_path = try std.fs.path.resolve(allocator, &[_][]const u8{path});
    defer allocator.free(clean_path);

    var dir = try fs.openDirAbsolute(clean_path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList(FileEntry).init(allocator);
    defer {
        // If we return an error, free any entries we've already created
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
        // (more comprehensive check happens in the permissions struct)
        if (!options.include_hidden and entry.name[0] == '.') {
            continue;
        }

        // Handle stat failures gracefully - some files might not be accessible
        var stat: fs.File.Stat = undefined;
        stat = dir.statFile(entry.name) catch |err| {
            // Log the error but continue with other files
            std.log.warn("Failed to stat {s}: {s}", .{ entry.name, @errorName(err) });
            continue;
        };

        // Follow symlinks if requested
        if (options.follow_symlinks and stat.kind == .SymLink) {
            // Get the symlink target
            const target_path = try dir.readLink(entry.name, allocator);
            defer allocator.free(target_path);

            // Try to stat the target
            stat = fs.cwd().statFile(target_path) catch |err| {
                // If we can't stat the target, keep the original symlink stat
                std.log.warn("Failed to stat symlink target {s}: {s}", .{ target_path, @errorName(err) });
                stat;
            };

            // Keep the symlink type, just update other metadata
            stat.kind = .SymLink;
        }

        const file_entry = try FileEntry.init(allocator, clean_path, entry.name, stat);
        try entries.append(file_entry);
    }

    return entries.toOwnedSlice();
}

/// Free an array of FileEntries
pub fn freeDirectoryEntries(allocator: Alloc, entries: []FileEntry) void {
    for (entries) |*entry| {
        entry.deinit();
    }
    allocator.free(entries);
}
