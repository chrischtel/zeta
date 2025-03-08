const std = @import("std");
const zeta_core = @import("zeta_core");
const zeta_version = @import("zeta_version");

const fs = zeta_core.fs;
const format = zeta_core.format;

pub const SortMethod = enum {
    name, // Sort by name (alphabetical)
    size, // Sort by file size
    time, // Sort by modification time
    extension, // Sort by file extension
};

const SortContext = struct {
    method: SortMethod,
    dirs_first: bool = true,
    reverse: bool = false,
};

// Simplified color support enum
pub const ColorSupport = enum { none, basic };

// Simple function to check if we should use color
fn shouldUseColor(no_color: bool) bool {
    if (no_color) return false;

    // Check NO_COLOR environment variable
    const no_color_env = std.process.getEnvVarOwned(std.heap.page_allocator, "NO_COLOR") catch "";
    defer if (no_color_env.len > 0) std.heap.page_allocator.free(no_color_env);
    if (no_color_env.len > 0) return false;

    return true; // Default to color
}

// Simple function to check if we should use Unicode
fn shouldUseUnicode(force_ascii: bool) bool {
    if (force_ascii) return false;
    return true; // Default to unicode
}

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
        sort_method: SortMethod = .name,
        reverse: bool = false,
        no_color: bool = false,
        force_ascii: bool = false,
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
            } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--size")) {
                options.sort_method = .size;
            } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--time")) {
                options.sort_method = .time;
            } else if (std.mem.eql(u8, arg, "-X") or std.mem.eql(u8, arg, "--extension")) {
                options.sort_method = .extension;
            } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--reverse")) {
                options.reverse = true;
            } else if (std.mem.eql(u8, arg, "--no-color")) {
                options.no_color = true;
            } else if (std.mem.eql(u8, arg, "--ascii")) {
                options.force_ascii = true;
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

    // Determine if we should use color and unicode
    const use_color = shouldUseColor(options.no_color);
    const use_unicode = shouldUseUnicode(options.force_ascii);

    // List the directory
    try listDirectory(allocator, options.path, options.show_hidden, options.sort_method, options.reverse, use_color, use_unicode);
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
        \\  -a, --all         Show hidden files
        \\  -h, --help        Show this help message
        \\  -v, --version     Show version information
        \\  -s, --size        Sort by file size
        \\  -t, --time        Sort by modification time
        \\  -X, --extension   Sort by file extension
        \\  -r, --reverse     Reverse sort order
        \\      --no-color    Disable colorized output
        \\      --ascii       Force ASCII output (no Unicode)
        \\
        \\EXAMPLES:
        \\  zeta              List current directory
        \\  zeta -a           List current directory including hidden files
        \\  zeta /path/to/dir List specific directory
        \\
    );
}

fn printHeader(writer: std.fs.File.Writer, use_unicode: bool) !void {
    const top_left = if (use_unicode) "┏" else "+";
    const horizontal = if (use_unicode) "━" else "-";
    const top_right = if (use_unicode) "┓" else "+";
    const vertical = if (use_unicode) "┃" else "|";
    const mid_left = if (use_unicode) "┣" else "+";
    const mid_right = if (use_unicode) "┫" else "+";

    try writer.print("{s}", .{top_left});
    // Print a sequence of horizontal characters (for approximately 70 columns)
    for (0..70) |_| {
        try writer.print("{s}", .{horizontal});
    }
    try writer.print("{s}\n", .{top_right});

    try writer.print("{s} {s: <28} {s: >10} {s: <12} {s: <10} {s}\n", .{ vertical, "NAME", "SIZE", "PERMISSIONS", "MODIFIED", vertical });

    try writer.print("{s}", .{mid_left});
    for (0..70) |_| {
        try writer.print("{s}", .{horizontal});
    }
    try writer.print("{s}\n", .{mid_right});
}

fn printFooter(writer: std.fs.File.Writer, count: usize, use_unicode: bool) !void {
    const bottom_left = if (use_unicode) "┗" else "+";
    const horizontal = if (use_unicode) "━" else "-";
    const bottom_right = if (use_unicode) "┛" else "+";

    try writer.print("{s}", .{bottom_left});
    for (0..70) |_| {
        try writer.print("{s}", .{horizontal});
    }
    try writer.print("{s}\n", .{bottom_right});

    try writer.print("  {d} items displayed\n", .{count});
}

fn printVersion() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("zeta version {s}\n", .{zeta_version.VERSION});
    try stdout.print("https://github.com/yourusername/zeta\n", .{});
}

fn getFileIcon(file_type: fs.FileType, extension: []const u8, use_unicode: bool) []const u8 {
    if (!use_unicode) {
        // ASCII fallback icons
        return switch (file_type) {
            .directory => "DIR ",
            .symlink => "LNK ",
            .regular => "    ",
            .special => "SPC ",
            .unknown => "??? ",
        };
    }

    // Unicode icons for file types
    switch (file_type) {
        .directory => return "📁 ",
        .symlink => return "🔗 ",
        .special => return "⚙️  ",
        .unknown => return "❓ ",
        .regular => {}, // Fall through to check extensions
    }

    // Unicode icons based on extension for regular files
    if (std.mem.eql(u8, extension, "pdf")) return "📄 ";
    if (std.mem.eql(u8, extension, "txt")) return "📝 ";
    if (std.mem.eql(u8, extension, "md")) return "📝 ";
    if (std.mem.eql(u8, extension, "zip") or
        std.mem.eql(u8, extension, "rar") or
        std.mem.eql(u8, extension, "gz") or
        std.mem.eql(u8, extension, "tar")) return "📦 ";
    if (std.mem.eql(u8, extension, "mp3") or
        std.mem.eql(u8, extension, "wav") or
        std.mem.eql(u8, extension, "ogg")) return "🎵 ";
    if (std.mem.eql(u8, extension, "mp4") or
        std.mem.eql(u8, extension, "avi") or
        std.mem.eql(u8, extension, "mkv")) return "🎬 ";
    if (std.mem.eql(u8, extension, "jpg") or
        std.mem.eql(u8, extension, "png") or
        std.mem.eql(u8, extension, "gif")) return "🖼️  ";
    if (std.mem.eql(u8, extension, "exe") or
        std.mem.eql(u8, extension, "bat") or
        std.mem.eql(u8, extension, "cmd")) return "🚀 ";
    if (std.mem.eql(u8, extension, "sh")) return "⌨️  ";
    if (std.mem.eql(u8, extension, "zig")) return "⚡ ";

    // Default icon for regular files
    return "📄 ";
}

fn getColorForFileType(file_type: fs.FileType, use_color: bool) []const u8 {
    if (!use_color) return "";

    return switch (file_type) {
        .directory => "\x1b[1;34m", // Bold blue
        .symlink => "\x1b[1;36m", // Bold cyan
        .regular => "\x1b[0m", // Default
        .special => "\x1b[1;33m", // Bold yellow
        .unknown => "\x1b[0;35m", // Magenta
    };
}

fn getColorForExtension(extension: []const u8, use_color: bool) []const u8 {
    if (!use_color) return "";

    // Executable files
    if (std.mem.eql(u8, extension, "exe") or
        std.mem.eql(u8, extension, "sh") or
        std.mem.eql(u8, extension, "bat") or
        std.mem.eql(u8, extension, "cmd"))
    {
        return "\x1b[1;32m"; // Bold green
    }

    // Archives
    if (std.mem.eql(u8, extension, "zip") or
        std.mem.eql(u8, extension, "tar") or
        std.mem.eql(u8, extension, "gz") or
        std.mem.eql(u8, extension, "rar"))
    {
        return "\x1b[0;31m"; // Red
    }

    // Images
    if (std.mem.eql(u8, extension, "jpg") or
        std.mem.eql(u8, extension, "png") or
        std.mem.eql(u8, extension, "gif") or
        std.mem.eql(u8, extension, "bmp"))
    {
        return "\x1b[0;35m"; // Magenta
    }

    // Code files
    if (std.mem.eql(u8, extension, "zig") or
        std.mem.eql(u8, extension, "c") or
        std.mem.eql(u8, extension, "cpp") or
        std.mem.eql(u8, extension, "js") or
        std.mem.eql(u8, extension, "py"))
    {
        return "\x1b[0;33m"; // Yellow
    }

    return "\x1b[0m"; // Default color
}

fn getResetCode() []const u8 {
    return "\x1b[0m";
}

fn listDirectory(
    allocator: std.mem.Allocator,
    path: []const u8,
    show_hidden: bool,
    sort_method: SortMethod,
    reverse: bool,
    use_color: bool,
    use_unicode: bool,
) !void {
    const stdout = std.io.getStdOut().writer();

    // Read directory entries
    const entries = try fs.readDirectory(allocator, path, .{
        .include_hidden = show_hidden,
        .follow_symlinks = false,
    });
    defer fs.freeDirectoryEntries(allocator, entries);

    // Sort entries
    std.sort.insertion(fs.FileEntry, entries, SortContext{
        .method = sort_method,
        .dirs_first = true,
        .reverse = reverse,
    }, compareEntries);

    // Print header with Unicode option
    try printHeader(stdout, use_unicode);

    // Track count of displayed items
    var count: usize = 0;

    // Get vertical border character
    const vertical = if (use_unicode) "┃" else "|";

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
        const icon = getFileIcon(entry.file_type, entry.extension, use_unicode);

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

        // Get color code based on file type or extension
        const color_code = if (entry.file_type == .regular)
            getColorForExtension(entry.extension, use_color)
        else
            getColorForFileType(entry.file_type, use_color);

        const reset_code = if (use_color) getResetCode() else "";

        try stdout.print("{s} {s}{s}{s}{s} {s} {s} {s} {s}\n", .{
            vertical,
            color_code,
            icon,
            display_name,
            reset_code,
            padded_size,
            permissions_str,
            time_str,
            vertical,
        });
    }

    // Print footer
    try printFooter(stdout, count, use_unicode);
}

fn compareEntries(context: SortContext, a: fs.FileEntry, b: fs.FileEntry) bool {
    // Handle directories first if that option is set
    if (context.dirs_first) {
        if (a.file_type == .directory and b.file_type != .directory) {
            return !context.reverse; // true normally, false if reversed
        }
        if (a.file_type != .directory and b.file_type == .directory) {
            return context.reverse; // false normally, true if reversed
        }
    }

    // Both are directories or both are files, sort according to method
    const result = switch (context.method) {
        .name => std.mem.lessThan(u8, a.name, b.name),
        .size => a.size < b.size,
        .time => a.mtime > b.mtime, // Note: reversed by default for time (newer first)
        .extension => blk: {
            // First compare extensions
            if (a.extension.len == 0 and b.extension.len > 0) break :blk true;
            if (a.extension.len > 0 and b.extension.len == 0) break :blk false;
            const ext_cmp = std.mem.lessThan(u8, a.extension, b.extension);
            if (a.extension.len > 0 and b.extension.len > 0 and !std.mem.eql(u8, a.extension, b.extension)) {
                break :blk ext_cmp;
            }
            // If extensions are the same or both empty, fallback to name
            break :blk std.mem.lessThan(u8, a.name, b.name);
        },
    };

    return if (context.reverse) !result else result;
}
