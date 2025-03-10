const std = @import("std");
const zeta_core = @import("zeta_core");
const fs = zeta_core.fs;

// ANSI color codes
pub const Color = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";

    pub const black = "\x1b[30m";
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const magenta = "\x1b[35m";
    pub const cyan = "\x1b[36m";
    pub const white = "\x1b[37m";

    pub const bold_black = "\x1b[1;30m";
    pub const bold_red = "\x1b[1;31m";
    pub const bold_green = "\x1b[1;32m";
    pub const bold_yellow = "\x1b[1;33m";
    pub const bold_blue = "\x1b[1;34m";
    pub const bold_magenta = "\x1b[1;35m";
    pub const bold_cyan = "\x1b[1;36m";
    pub const bold_white = "\x1b[1;37m";
};

// Icons for different file types
pub const Icons = struct {
    // ASCII icons
    pub const ascii = struct {
        pub const directory = "DIR ";
        pub const symlink = "LNK ";
        pub const regular = "    ";
        pub const special = "SPC ";
        pub const unknown = "??? ";
    };

    // Unicode icons
    pub const unicode = struct {
        pub const directory = "📁 ";
        pub const symlink = "🔗 ";
        pub const special = "⚙️  ";
        pub const unknown = "❓ ";

        // Default icon for regular files
        pub const regular = "📄 ";

        // File type icons based on extension
        pub const doc = "📝 ";
        pub const pdf = "📄 ";
        pub const archive = "📦 ";
        pub const audio = "🎵 ";
        pub const video = "🎬 ";
        pub const image = "🖼️  ";
        pub const executable = "🚀 ";
        pub const script = "⌨️  ";
        pub const zig = "⚡ ";
    };
};

// Style configuration
pub const StyleConfig = struct {
    use_color: bool,
    use_unicode: bool,
};

// Create a new style configuration based on options
pub fn createStyleConfig(no_color: bool, force_ascii: bool) StyleConfig {
    return .{
        .use_color = shouldUseColor(no_color),
        .use_unicode = shouldUseUnicode(force_ascii),
    };
}

// Terminal border characters
pub const Border = struct {
    pub const unicode = struct {
        pub const top_left = "┏";
        pub const top_right = "┓";
        pub const bottom_left = "┗";
        pub const bottom_right = "┛";
        pub const horizontal = "━";
        pub const vertical = "┃";
        pub const mid_left = "┣";
        pub const mid_right = "┫";
    };

    pub const ascii = struct {
        pub const top_left = "+";
        pub const top_right = "+";
        pub const bottom_left = "+";
        pub const bottom_right = "+";
        pub const horizontal = "-";
        pub const vertical = "|";
        pub const mid_left = "+";
        pub const mid_right = "+";
    };

    pub fn get(comptime field: []const u8, use_unicode: bool) []const u8 {
        if (use_unicode) {
            return @field(unicode, field);
        } else {
            return @field(ascii, field);
        }
    }
};

// Check if color should be used
pub fn shouldUseColor(no_color: bool) bool {
    if (no_color) return false;

    // Check NO_COLOR environment variable
    const no_color_env = std.process.getEnvVarOwned(std.heap.page_allocator, "NO_COLOR") catch "";
    defer if (no_color_env.len > 0) std.heap.page_allocator.free(no_color_env);
    if (no_color_env.len > 0) return false;

    // Check if stdout is a terminal
    const is_tty = std.io.getStdOut().isTty() catch false;
    if (!is_tty) return false;

    return true;
}

// Check if Unicode should be used
pub fn shouldUseUnicode(force_ascii: bool) bool {
    if (force_ascii) return false;

    // Could potentially check locale/terminal support here

    return true;
}

// Get file icon based on file type and extension
pub fn getFileIcon(file_type: fs.FileType, extension: []const u8, config: StyleConfig) []const u8 {
    if (!config.use_unicode) {
        return switch (file_type) {
            .directory => Icons.ascii.directory,
            .symlink => Icons.ascii.symlink,
            .regular => Icons.ascii.regular,
            .special => Icons.ascii.special,
            .unknown => Icons.ascii.unknown,
        };
    }

    // Unicode icons
    if (file_type != .regular) {
        return switch (file_type) {
            .directory => Icons.unicode.directory,
            .symlink => Icons.unicode.symlink,
            .special => Icons.unicode.special,
            .unknown => Icons.unicode.unknown,
            .regular => unreachable, // Handled below
        };
    }

    // Regular files - check extension
    return getFileIconByExtension(extension);
}

// Get icon for regular files based on extension
fn getFileIconByExtension(extension: []const u8) []const u8 {
    const map = std.ComptimeStringMap([]const u8, .{
        .{ "pdf", Icons.unicode.pdf },
        .{ "txt", Icons.unicode.doc },
        .{ "md", Icons.unicode.doc },
        .{ "doc", Icons.unicode.doc },
        .{ "docx", Icons.unicode.doc },
        .{ "zip", Icons.unicode.archive },
        .{ "rar", Icons.unicode.archive },
        .{ "gz", Icons.unicode.archive },
        .{ "tar", Icons.unicode.archive },
        .{ "7z", Icons.unicode.archive },
        .{ "mp3", Icons.unicode.audio },
        .{ "wav", Icons.unicode.audio },
        .{ "ogg", Icons.unicode.audio },
        .{ "flac", Icons.unicode.audio },
        .{ "mp4", Icons.unicode.video },
        .{ "avi", Icons.unicode.video },
        .{ "mkv", Icons.unicode.video },
        .{ "mov", Icons.unicode.video },
        .{ "webm", Icons.unicode.video },
        .{ "jpg", Icons.unicode.image },
        .{ "jpeg", Icons.unicode.image },
        .{ "png", Icons.unicode.image },
        .{ "gif", Icons.unicode.image },
        .{ "bmp", Icons.unicode.image },
        .{ "svg", Icons.unicode.image },
        .{ "webp", Icons.unicode.image },
        .{ "exe", Icons.unicode.executable },
        .{ "bat", Icons.unicode.executable },
        .{ "cmd", Icons.unicode.executable },
        .{ "sh", Icons.unicode.script },
        .{ "bash", Icons.unicode.script },
        .{ "zsh", Icons.unicode.script },
        .{ "fish", Icons.unicode.script },
        .{ "zig", Icons.unicode.zig },
    });

    return map.get(extension) orelse Icons.unicode.regular;
}

// Get color for file type
pub fn getColorForFileType(file_type: fs.FileType, config: StyleConfig) []const u8 {
    if (!config.use_color) return "";

    return switch (file_type) {
        .directory => Color.bold_blue,
        .symlink => Color.bold_cyan,
        .regular => Color.reset,
        .special => Color.bold_yellow,
        .unknown => Color.magenta,
    };
}

// Get color for file extension
pub fn getColorForExtension(extension: []const u8, config: StyleConfig) []const u8 {
    if (!config.use_color) return "";

    const map = std.ComptimeStringMap([]const u8, .{
        // Executable files
        .{ "exe", Color.bold_green },
        .{ "sh", Color.bold_green },
        .{ "bat", Color.bold_green },
        .{ "cmd", Color.bold_green },

        // Archives
        .{ "zip", Color.red },
        .{ "tar", Color.red },
        .{ "gz", Color.red },
        .{ "rar", Color.red },
        .{ "7z", Color.red },

        // Images
        .{ "jpg", Color.magenta },
        .{ "jpeg", Color.magenta },
        .{ "png", Color.magenta },
        .{ "gif", Color.magenta },
        .{ "bmp", Color.magenta },
        .{ "svg", Color.magenta },

        // Documents
        .{ "pdf", Color.cyan },
        .{ "doc", Color.cyan },
        .{ "docx", Color.cyan },
        .{ "txt", Color.white },
        .{ "md", Color.white },

        // Code files
        .{ "zig", Color.yellow },
        .{ "c", Color.yellow },
        .{ "cpp", Color.yellow },
        .{ "h", Color.yellow },
        .{ "hpp", Color.yellow },
        .{ "js", Color.yellow },
        .{ "py", Color.yellow },
        .{ "rs", Color.yellow },
        .{ "go", Color.yellow },
        .{ "java", Color.yellow },

        // Media
        .{ "mp3", Color.bold_magenta },
        .{ "wav", Color.bold_magenta },
        .{ "mp4", Color.bold_magenta },
        .{ "avi", Color.bold_magenta },
    });

    return map.get(extension) orelse Color.reset;
}

// Get reset code for colors
pub fn getResetCode(config: StyleConfig) []const u8 {
    return if (config.use_color) Color.reset else "";
}

// File entry display style
pub const EntryStyle = struct {
    icon: []const u8,
    color: []const u8,
    reset: []const u8,

    // Create a style for a file entry
    pub fn create(entry: fs.FileEntry, config: StyleConfig) EntryStyle {
        const icon = getFileIcon(entry.file_type, entry.extension, config);
        const color = if (entry.file_type == .regular)
            getColorForExtension(entry.extension, config)
        else
            getColorForFileType(entry.file_type, config);
        const reset = getResetCode(config);

        return .{
            .icon = icon,
            .color = color,
            .reset = reset,
        };
    }
};
