const std = @import("std");
const zeta_core = @import("zeta_core");
const zeta_version = @import("zeta_version");

const fs = zeta_core.fs;
const format = zeta_core.format;

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Default options
    var options = struct {
        path: []const u8 = ".",
        show_hidden: bool = false,
        show_help: bool = false,
        show_version: bool = false,
    }{};

    // Parse arguments
    if (args.len > 1) {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--all")) {
                options.show_hidden = true;
            } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                options.show_help = true;
            } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                options.show_version = true;
            } else if (!std.mem.startsWith(u8, arg, "-")) {
                options.path = arg;
            }
        }
    }

    // Show help if requested
    if (options.show_help) {
        return printHelp();
    }

    // Show version if requested
    if (options.show_version) {
        return printVersion();
    }

    // List the directory
    try listDirectory(allocator, options.path, options.show_hidden);
}

fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(
        \\zeta - A modern directory listing tool
        \\
        \\USAGE:
        \\  zeta [OPTIONS] [PATH]
        \\
        \\OPTIONS:
        \\  -a, --all       Show hidden files
        \\  -h, --help      Show this help message
        \\  -v, --version   Show version information
        \\
        \\EXAMPLES:
        \\  zeta              List current directory
        \\  zeta -a           List current directory including hidden files
        \\  zeta /path/to/dir List specific directory
        \\
    );
}

fn printVersion() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("zeta version {s}\n", .{zeta_version.VERSION});
    try stdout.print("https://github.com/yourusername/zeta\n", .{});
}

fn listDirectory(allocator: std.mem.Allocator, path: []const u8, show_hidden: bool) !void {
    const stdout = std.io.getStdOut().writer();

    // Read directory entries
    const entries = try fs.readDirectory(allocator, path, .{
        .include_hidden = show_hidden,
        .follow_symlinks = false,
    });
    defer fs.freeDirectoryEntries(allocator, entries);

    // Sort entries (directories first, then alphabetical)
    std.sort.insertion(fs.FileEntry, entries, {}, compareEntries);

    // Calculate column widths
    var max_size_width: usize = 4; // "SIZE"
    for (entries) |entry| {
        const size_str = try format.formatSize(allocator, entry.size);
        defer allocator.free(size_str);
        max_size_width = @max(max_size_width, size_str.len);
    }

    // Print header
    try stdout.writeAll("    NAME                             SIZE    MODIFIED\n");

    // Print entries
    for (entries) |entry| {
        // Format size
        const size_str = try format.formatSize(allocator, entry.size);
        defer allocator.free(size_str);

        // Format time
        const time_str = try format.formatTime(allocator, entry.mtime);
        defer allocator.free(time_str);

        // Get file icon
        const icon = format.getFileIcon(entry.file_type, entry.extension);

        // Format padded name (truncate if too long)
        const display_name = if (entry.name.len > 28)
            try std.fmt.allocPrint(allocator, "{s}...", .{entry.name[0..25]})
        else
            try std.fmt.allocPrint(allocator, "{s: <28}", .{entry.name});
        defer allocator.free(display_name);

        // Format padded size
        const padded_size = try std.fmt.allocPrint(allocator, "{s: >8}", .{size_str});
        defer allocator.free(padded_size);

        // Print with color based on file type
        const color_code = getColorForFileType(entry.file_type);
        try stdout.print("{s}{s} {s}{s} {s}  {s}\n", .{
            color_code,
            icon,
            display_name,
            getResetCode(),
            padded_size,
            time_str,
        });
    }
}

fn compareEntries(context: void, a: fs.FileEntry, b: fs.FileEntry) bool {
    _ = context;

    // Directories come first
    if (a.file_type == .directory and b.file_type != .directory) {
        return true;
    }
    if (a.file_type != .directory and b.file_type == .directory) {
        return false;
    }

    // Then sort by name
    return std.mem.lessThan(u8, a.name, b.name);
}

fn getColorForFileType(file_type: fs.FileType) []const u8 {
    return switch (file_type) {
        .directory => "\x1b[1;34m", // Bold blue
        .symlink => "\x1b[1;36m", // Bold cyan
        .regular => "\x1b[0m", // Default
        .special => "\x1b[1;33m", // Bold yellow
        .unknown => "\x1b[0;35m", // Magenta
    };
}

fn getResetCode() []const u8 {
    return "\x1b[0m";
}
