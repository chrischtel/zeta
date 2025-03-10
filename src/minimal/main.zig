const std = @import("std");
const args = @import("args.zig");
const style = @import("style.zig");
const list = @import("list.zig");

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse args
    const options = try args.parseArgs(allocator);

    // Show help if requested
    if (options.show_help) {
        return args.printHelp();
    }

    // Show version if requested
    if (options.show_version) {
        return args.printVersion();
    }

    // Determine if we should use color and unicode
    const use_color = style.shouldUseColor(options.no_color);
    const use_unicode = style.shouldUseUnicode(options.force_ascii);

    // List the directory
    try list.listDirectory(allocator, options.path, options.show_hidden, options.sort_method, options.reverse, use_color, use_unicode);
}
