const std = @import("std");
const zeta_version = @import("zeta_version");
const types = @import("types.zig");

pub fn parseArgs(allocator: std.mem.Allocator) !types.Options {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var options = types.Options{};

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

    return options;
}

pub fn printHelp() !void {
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

pub fn printVersion() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("zeta version {s}\n", .{zeta_version.VERSION});
    try stdout.print("https://github.com/yourusername/zeta\n", .{});
}
