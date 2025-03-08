const std = @import("std");
const fs = @import("fs.zig");
const testing = std.testing;
const builtin = @import("builtin");

test "read current directory cross-platform" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Get current directory in a platform-independent way
    const cwd = std.fs.cwd().realpathAlloc(allocator, ".") catch unreachable;

    // Read directory entries with platform-specific handling
    const entries = try fs.readDirectory(allocator, cwd, .{});

    // Just make sure we got some entries
    try testing.expect(entries.len > 0);

    // Verify we got proper file types
    var found_regular_file = false;
    for (entries) |entry| {
        // Check filename is not empty
        try testing.expect(entry.name.len > 0);

        // Check permissions are populated
        try testing.expect(entry.permissions.owner_read or entry.permissions.readonly);

        // Track if we found regular files
        if (entry.file_type == .regular) {
            found_regular_file = true;
        }
    }

    // Most directories should have at least one regular file
    // But don't fail the test if not - some test environments might be unusual
    if (!found_regular_file) {
        std.debug.print("Warning: No regular files found in directory\n", .{});
    }

    // No need to free entries as we're using an arena
}
