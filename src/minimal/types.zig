const std = @import("std");

pub const SortMethod = enum {
    name, // Sort by name (alphabetical)
    size, // Sort by file size
    time, // Sort by modification time
    extension, // Sort by file extension
};

pub const SortContext = struct {
    method: SortMethod,
    dirs_first: bool = true,
    reverse: bool = false,
};

pub const ColorSupport = enum { none, basic };

pub const Options = struct {
    path: []const u8 = ".",
    show_hidden: bool = false,
    show_help: bool = false,
    show_version: bool = false,
    sort_method: SortMethod = .name,
    reverse: bool = false,
    no_color: bool = false,
    force_ascii: bool = false,
};
