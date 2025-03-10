const std = @import("std");
const style = @import("style.zig");

pub fn printHeader(writer: std.fs.File.Writer, use_unicode: bool) !void {
    const top_left = style.Border.get("top_left", use_unicode);
    const horizontal = style.Border.get("horizontal", use_unicode);
    const top_right = style.Border.get("top_right", use_unicode);
    const vertical = style.Border.get("vertical", use_unicode);
    const mid_left = style.Border.get("mid_left", use_unicode);
    const mid_right = style.Border.get("mid_right", use_unicode);

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

pub fn printFooter(writer: std.fs.File.Writer, count: usize, use_unicode: bool) !void {
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
