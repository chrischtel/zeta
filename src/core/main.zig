const std = @import("std");
const builtin = @import("builtin");

// Export the current platform info
pub const platform = struct {
    pub const is_windows = builtin.os.tag == .windows;
    pub const is_macos = builtin.os.tag == .macos;
    pub const is_linux = builtin.os.tag == .linux;

    pub const path_separator = if (is_windows) '\\' else '/';

    pub const system_name = @tagName(builtin.os.tag);
};

// Export all file system functionality
pub const fs = @import("fs.zig");

// Export all formatting utilities
pub const format = @import("format.zig");

// Export standard testing
test {
    std.testing.refAllDeclsRecursive(@This());
}
