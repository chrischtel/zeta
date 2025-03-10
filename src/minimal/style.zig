const std = @import("std");
const zeta_core = @import("zeta_core");

const fs = zeta_core.fs;

// Simple function to check if we should use color
pub fn shouldUseColor(no_color: bool) bool {
    if (no_color) return false;

    // Check NO_COLOR environment variable
    const no_color_env = std.process.getEnvVarOwned(std.heap.page_allocator, "NO_COLOR") catch "";
    defer if (no_color_env.len > 0) std.heap.page_allocator.free(no_color_env);
    if (no_color_env.len > 0) return false;

    return true; // Default to color
}

// Simple function to check if we should use Unicode
pub fn shouldUseUnicode(force_ascii: bool) bool {
    if (force_ascii) return false;
    return true; // Default to unicode
}

pub fn getFileIcon(file_type: fs.FileType, extension: []const u8, use_unicode: bool) []const u8 {
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

pub fn getColorForFileType(file_type: fs.FileType, use_color: bool) []const u8 {
    if (!use_color) return "";

    return switch (file_type) {
        .directory => "\x1b[1;34m", // Bold blue
        .symlink => "\x1b[1;36m", // Bold cyan
        .regular => "\x1b[0m", // Default
        .special => "\x1b[1;33m", // Bold yellow
        .unknown => "\x1b[0;35m", // Magenta
    };
}

pub fn getColorForExtension(extension: []const u8, use_color: bool) []const u8 {
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

pub fn getResetCode() []const u8 {
    return "\x1b[0m";
}
