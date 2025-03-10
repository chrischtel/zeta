const std = @import("std");
const zeta_core = @import("zeta_core");
const types = @import("types.zig");
const style = @import("style.zig");
const sort = @import("sort.zig");
const display = @import("display.zig");

const fs = zeta_core.fs;
const format = zeta_core.format;

pub fn listDirectory(
    allocator: std.mem.Allocator,
    path: []const u8,
    show_hidden: bool,
    sort_method: types.SortMethod,
    reverse: bool,
    no_color: bool,
    force_ascii: bool,
) !void {
    const stdout = std.io.getStdOut().writer();

    const style_config = style.createStyleConfig(no_color, force_ascii);

    // Read directory entries
    const entries = try fs.readDirectory(allocator, path, .{
        .include_hidden = show_hidden,
        .follow_symlinks = false,
    });
    defer fs.freeDirectoryEntries(allocator, entries);

    // Sort entries
    std.sort.insertion(fs.FileEntry, entries, types.SortContext{
        .method = sort_method,
        .dirs_first = true,
        .reverse = reverse,
    }, sort.compareEntries);

    // Print header with Unicode option
    try display.printHeader(stdout, style_config.use_unicode);

    // Track count of displayed items
    var count: usize = 0;

    // Get vertical border character
    const vertical = if (style_config.use_unicode) "┃" else "|";

    // Print entries
    for (entries) |entry| {
        count += 1;

        // Format size
        const size_str = try format.formatSize(allocator, entry.size);
        defer allocator.free(size_str);

        // Format time
        const time_str = try format.formatTime(allocator, entry.mtime);
        defer allocator.free(time_str);

        // Get file icon based on Unicode preference
        _ = style.getFileIcon(entry.file_type, entry.extension, style_config);

        // Format padded name (truncate if too long)
        const display_name = if (entry.name.len > 28)
            try std.fmt.allocPrint(allocator, "{s}...", .{entry.name[0..25]})
        else
            try std.fmt.allocPrint(allocator, "{s: <28}", .{entry.name});
        defer allocator.free(display_name);

        // Format padded size
        const padded_size = try std.fmt.allocPrint(allocator, "{s: >10}", .{size_str});
        defer allocator.free(padded_size);

        const permissions_str = try format.formatPermissions(allocator, entry.permissions, entry.file_type);
        defer allocator.free(permissions_str);

        // Get style for this entry in one call
        const entry_style = style.EntryStyle.create(entry, style_config);

        try stdout.print("{s} {s}{s}{s}{s} {s} {s} {s} {s}\n", .{
            vertical,
            entry_style.color,
            entry_style.icon,
            display_name,
            entry_style.reset,
            padded_size,
            permissions_str,
            time_str,
            vertical,
        });
    }

    // Print footer
    try display.printFooter(stdout, count, style_config.use_unicode);
}
