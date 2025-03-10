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
    const is_tty = std.io.getStdOut().isTty();
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
    // Documents
    if (std.mem.eql(u8, extension, "pdf")) return Icons.unicode.pdf;
    if (std.mem.eql(u8, extension, "txt") or
        std.mem.eql(u8, extension, "md") or
        std.mem.eql(u8, extension, "doc") or
        std.mem.eql(u8, extension, "docx")) return Icons.unicode.doc;

    // Archives
    if (std.mem.eql(u8, extension, "zip") or
        std.mem.eql(u8, extension, "rar") or
        std.mem.eql(u8, extension, "gz") or
        std.mem.eql(u8, extension, "tar") or
        std.mem.eql(u8, extension, "7z")) return Icons.unicode.archive;

    // Audio
    if (std.mem.eql(u8, extension, "mp3") or
        std.mem.eql(u8, extension, "wav") or
        std.mem.eql(u8, extension, "ogg") or
        std.mem.eql(u8, extension, "flac")) return Icons.unicode.audio;

    // Video
    if (std.mem.eql(u8, extension, "mp4") or
        std.mem.eql(u8, extension, "avi") or
        std.mem.eql(u8, extension, "mkv") or
        std.mem.eql(u8, extension, "mov") or
        std.mem.eql(u8, extension, "webm")) return Icons.unicode.video;

    // Images
    if (std.mem.eql(u8, extension, "jpg") or
        std.mem.eql(u8, extension, "jpeg") or
        std.mem.eql(u8, extension, "png") or
        std.mem.eql(u8, extension, "gif") or
        std.mem.eql(u8, extension, "bmp") or
        std.mem.eql(u8, extension, "svg") or
        std.mem.eql(u8, extension, "webp")) return Icons.unicode.image;

    // Executables
    if (std.mem.eql(u8, extension, "exe") or
        std.mem.eql(u8, extension, "bat") or
        std.mem.eql(u8, extension, "cmd")) return Icons.unicode.executable;

    // Scripts
    if (std.mem.eql(u8, extension, "sh") or
        std.mem.eql(u8, extension, "bash") or
        std.mem.eql(u8, extension, "zsh") or
        std.mem.eql(u8, extension, "fish")) return Icons.unicode.script;

    // Zig
    if (std.mem.eql(u8, extension, "zig")) return Icons.unicode.zig;

    // Default
    return Icons.unicode.regular;
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

    // Executable files
    if (std.mem.eql(u8, extension, "exe") or
        std.mem.eql(u8, extension, "sh") or
        std.mem.eql(u8, extension, "bat") or
        std.mem.eql(u8, extension, "cmd"))
    {
        return Color.bold_green;
    }

    // Archives
    if (std.mem.eql(u8, extension, "zip") or
        std.mem.eql(u8, extension, "tar") or
        std.mem.eql(u8, extension, "gz") or
        std.mem.eql(u8, extension, "rar") or
        std.mem.eql(u8, extension, "7z"))
    {
        return Color.red;
    }

    // Images
    if (std.mem.eql(u8, extension, "jpg") or
        std.mem.eql(u8, extension, "jpeg") or
        std.mem.eql(u8, extension, "png") or
        std.mem.eql(u8, extension, "gif") or
        std.mem.eql(u8, extension, "bmp") or
        std.mem.eql(u8, extension, "svg"))
    {
        return Color.magenta;
    }

    // Documents
    if (std.mem.eql(u8, extension, "pdf") or
        std.mem.eql(u8, extension, "doc") or
        std.mem.eql(u8, extension, "docx"))
    {
        return Color.cyan;
    }

    if (std.mem.eql(u8, extension, "txt") or
        std.mem.eql(u8, extension, "md"))
    {
        return Color.white;
    }

    // Code files
    if (std.mem.eql(u8, extension, "zig") or
        std.mem.eql(u8, extension, "c") or
        std.mem.eql(u8, extension, "cpp") or
        std.mem.eql(u8, extension, "h") or
        std.mem.eql(u8, extension, "hpp") or
        std.mem.eql(u8, extension, "js") or
        std.mem.eql(u8, extension, "py") or
        std.mem.eql(u8, extension, "rs") or
        std.mem.eql(u8, extension, "go") or
        std.mem.eql(u8, extension, "java"))
    {
        return Color.yellow;
    }

    // Media
    if (std.mem.eql(u8, extension, "mp3") or
        std.mem.eql(u8, extension, "wav") or
        std.mem.eql(u8, extension, "mp4") or
        std.mem.eql(u8, extension, "avi"))
    {
        return Color.bold_magenta;
    }

    return Color.reset;
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
