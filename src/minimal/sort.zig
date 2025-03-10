const std = @import("std");
const zeta_core = @import("zeta_core");
const types = @import("types.zig");

const fs = zeta_core.fs;

pub fn compareEntries(context: types.SortContext, a: fs.FileEntry, b: fs.FileEntry) bool {
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
