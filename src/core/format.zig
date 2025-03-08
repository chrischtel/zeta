const std = @import("std");
const Allocator = std.mem.Allocator;
const fs = std.fs;
const time = std.time;
const builtin = @import("builtin");

const FileEntry = @import("fs.zig").FileEntry;
const FileType = @import("fs.zig").FileType;
const FilePermissions = @import("fs.zig").FilePermissions;

/// Format file size in human-readable form
pub fn formatSize(allocator: Allocator, size: u64) ![]const u8 {
    const units = [_][]const u8{ "B", "K", "M", "G", "T", "P" };
    var size_f: f64 = @floatFromInt(size);
    var unit_index: usize = 0;

    while (size_f >= 1024.0 and unit_index < units.len - 1) {
        size_f /= 1024.0;
        unit_index += 1;
    }

    if (unit_index == 0) {
        // For bytes, show as integer
        return std.fmt.allocPrint(allocator, "{d}{s}", .{ size, units[unit_index] });
    } else {
        // For KB and above, show with decimal
        return std.fmt.allocPrint(allocator, "{d:.1}{s}", .{ size_f, units[unit_index] });
    }
}

/// Format file permissions in a cross-platform way
pub fn formatPermissions(allocator: Allocator, perms: FilePermissions, file_type: FileType) ![]const u8 {
    if (builtin.os.tag == .windows) {
        // For Windows, use a simpler attribute-based format
        var attrs = [_]u8{ '-', '-', '-', '-' };

        if (perms.readable) attrs[0] = 'R';
        if (perms.hidden) attrs[1] = 'H';

        // Show directory/archive attribute
        if (file_type == .directory) {
            attrs[3] = 'D';
        } else if (file_type == .symlink) {
            attrs[3] = 'L';
        }

        return try allocator.dupe(u8, &attrs);
    } else {
        // For Unix-like systems, use traditional format
        var result = [_]u8{ '-', '-', '-', '-', '-', '-', '-', '-', '-', '-' };

        // File type indicator
        switch (file_type) {
            .directory => result[0] = 'd',
            .symlink => result[0] = 'l',
            .special => result[0] = 's',
            else => {},
        }

        // Owner permissions
        if (perms.owner_read) result[1] = 'r';
        if (perms.owner_write) result[2] = 'w';
        if (perms.owner_execute) result[3] = 'x';

        // Group/other permissions (simplified - in a real implementation
        // you'd get actual group/other permissions from the file)
        if (perms.owner_read) {
            result[4] = 'r';
            result[7] = 'r';
        }
        if (perms.owner_write and !perms.readonly) {
            result[5] = 'w';
            result[8] = 'w';
        }
        if (perms.owner_execute) {
            result[6] = 'x';
            result[9] = 'x';
        }

        return try allocator.dupe(u8, &result);
    }
}

/// Format timestamp as a human-readable date
pub fn formatTime(allocator: Allocator, timestamp: i128) ![]const u8 {
    // Convert nanoseconds to seconds
    const seconds: i64 = @intCast(@divFloor(timestamp, std.time.ns_per_s));

    // Get current time for comparison
    const current_time = std.time.timestamp();

    // Simple timestamp formatting without locale-specific functions
    var epoch_seconds: i64 = seconds;

    // Extract time components manually (simplified version)
    const seconds_per_day: i64 = 86400;
    const seconds_per_hour: i64 = 3600;
    const seconds_per_minute: i64 = 60;

    // Days since epoch (Jan 1, 1970)
    const days_since_epoch = @divFloor(epoch_seconds, seconds_per_day);
    epoch_seconds -= days_since_epoch * seconds_per_day;

    // Extract hour, minute
    const hour = @divFloor(epoch_seconds, seconds_per_hour);
    epoch_seconds -= hour * seconds_per_hour;

    const minute = @divFloor(epoch_seconds, seconds_per_minute);

    // Simple date formatting - just show the timestamp in a basic format
    // In a real implementation, you'd want proper date calculation
    const is_recent = (current_time - seconds) < (365 * 24 * 60 * 60);

    if (is_recent) {
        // For recent files, show a relative time
        const days_ago = @divFloor(current_time - seconds, seconds_per_day);

        if (days_ago == 0) {
            return std.fmt.allocPrint(allocator, "Today {:02}:{:02}", .{ hour, minute });
        } else if (days_ago == 1) {
            return std.fmt.allocPrint(allocator, "Yesterday", .{});
        } else {
            return std.fmt.allocPrint(allocator, "{d} days ago", .{days_ago});
        }
    } else {
        // For older files, show days since epoch (very simplified)
        return std.fmt.allocPrint(allocator, "{d} days ago", .{@divFloor(current_time - seconds, seconds_per_day)});
    }
}
/// Generate file type icon in a cross-platform way
pub fn getFileIcon(file_type: FileType, extension: []const u8) []const u8 {
    _ = extension; // Will use in full version

    // Return Unicode characters that work on modern terminals
    // across platforms
    return switch (file_type) {
        .directory => "📁",
        .symlink => "🔗",
        .regular => "📄",
        .special => "⚙️",
        .unknown => "❓",
    };
}

fn getMonthName(month: usize) []const u8 {
    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    return months[month];
}
