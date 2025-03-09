const std = @import("std");

// Constants for project configuration
const PROJECT_NAME = "zeta";
const VERSION = "0.0.0-alpha.1+fdc0fc3";

const VersionParts = struct {
    core: []const u8,
    prerelease: []const u8,
    has_prerelease: bool,
    build_meta: []const u8,
    has_build_meta: bool,
};

fn parseVersion(version: []const u8) VersionParts {
    var result = VersionParts{
        .core = version,
        .prerelease = "",
        .has_prerelease = false,
        .build_meta = "",
        .has_build_meta = false,
    };

    // Find prerelease part (after -)
    if (std.mem.indexOf(u8, version, "-")) |dash_idx| {
        // Set core version
        result.core = version[0..dash_idx];

        var pre_end = version.len;
        // Find build metadata part (after +)
        if (std.mem.indexOf(u8, version[dash_idx..], "+")) |plus_idx| {
            pre_end = dash_idx + plus_idx;
            result.build_meta = version[pre_end + 1 ..];
            result.has_build_meta = true;
        }

        result.prerelease = version[dash_idx + 1 .. pre_end];
        result.has_prerelease = true;
    } else if (std.mem.indexOf(u8, version, "+")) |plus_idx| {
        // No prerelease but has build metadata
        result.core = version[0..plus_idx];
        result.build_meta = version[plus_idx + 1 ..];
        result.has_build_meta = true;
    }

    return result;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get git commit hash
    var git_hash: []const u8 = "unknown";
    const git_result = std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = &[_][]const u8{ "git", "rev-parse", "--short", "HEAD" },
        .cwd = b.build_root.path,
    }) catch null;

    if (git_result) |result| {
        if (result.term.Exited == 0) {
            // Trim whitespace
            var stdout = result.stdout;
            var start: usize = 0;
            var end: usize = stdout.len;

            while (start < end and (stdout[start] == ' ' or stdout[start] == '\r' or
                stdout[start] == '\n' or stdout[start] == '\t'))
            {
                start += 1;
            }

            while (end > start and (stdout[end - 1] == ' ' or stdout[end - 1] == '\r' or
                stdout[end - 1] == '\n' or stdout[end - 1] == '\t'))
            {
                end -= 1;
            }

            git_hash = b.allocator.dupe(u8, stdout[start..end]) catch "unknown";
        }
        b.allocator.free(result.stdout);
        b.allocator.free(result.stderr);
    }
    defer if (git_hash.ptr != "unknown".ptr) b.allocator.free(git_hash);

    // Get build date
    var build_date: []const u8 = "unknown";
    const date_cmd = if (target.result.os.tag == .windows)
        &[_][]const u8{ "cmd", "/c", "echo %DATE% %TIME%" }
    else
        &[_][]const u8{ "date", "+%Y-%m-%d %H:%M:%S" };

    const date_result = std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = date_cmd,
    }) catch null;

    if (date_result) |result| {
        if (result.term.Exited == 0) {
            // Trim whitespace
            var stdout = result.stdout;
            var start: usize = 0;
            var end: usize = stdout.len;

            while (start < end and (stdout[start] == ' ' or stdout[start] == '\r' or
                stdout[start] == '\n' or stdout[start] == '\t'))
            {
                start += 1;
            }

            while (end > start and (stdout[end - 1] == ' ' or stdout[end - 1] == '\r' or
                stdout[end - 1] == '\n' or stdout[end - 1] == '\t'))
            {
                end -= 1;
            }

            build_date = b.allocator.dupe(u8, stdout[start..end]) catch "unknown";
        }
        b.allocator.free(result.stdout);
        b.allocator.free(result.stderr);
    }
    defer if (build_date.ptr != "unknown".ptr) b.allocator.free(build_date);

    // Generate version.zig file
    const version_source =
        \\// This file is auto-generated by build.zig. Do not modify manually.
        \\pub const VERSION = "0.0.0-alpha.1+fdc0fc3";  // Full version string
        \\pub const VERSION_CORE = "{s}";  // Just MAJOR.MINOR.PATCH
        \\pub const PRERELEASE = {s};  // alpha.1, beta.2, etc. or null
        \\pub const BUILD_META = "{s}";  // Git hash or other build info
        \\pub const GIT_COMMIT = "{s}";
        \\pub const BUILD_DATE = "{s}";
        \\
        \\pub const VersionInfo = struct {{
        \\    version: []const u8,
        \\    version_core: []const u8,
        \\    prerelease: ?[]const u8,
        \\    build_meta: []const u8,
        \\    git_commit: []const u8,
        \\    build_date: []const u8,
        \\    
        \\    pub fn isPrerelease(self: @This()) bool {{
        \\        return self.prerelease != null;
        \\    }}
        \\}};
        \\
        \\pub fn getVersionInfo() VersionInfo {{
        \\    return VersionInfo{{
        \\        .version = VERSION,
        \\        .version_core = VERSION_CORE,
        \\        .prerelease = PRERELEASE,
        \\        .build_meta = BUILD_META,
        \\        .git_commit = GIT_COMMIT,
        \\        .build_date = BUILD_DATE,
        \\    }};
        \\}}
    ;

    // Parse the version components
    const parsed = parseVersion(VERSION);
    const prerelease_str = if (parsed.has_prerelease)
        b.fmt("\"{s}\"", .{parsed.prerelease})
    else
        "null";
    const build_meta = if (parsed.has_build_meta)
        parsed.build_meta
    else
        git_hash;

    const formatted = std.fmt.allocPrint(b.allocator, version_source, .{
        VERSION,
        parsed.core,
        prerelease_str,
        build_meta,
        git_hash,
        build_date,
    }) catch unreachable;

    defer b.allocator.free(formatted);

    // Create directory for generated files
    const gen_dir = "src/generated";
    std.fs.cwd().makeDir(gen_dir) catch |err| {
        if (err != error.PathAlreadyExists) {
            std.debug.print("Warning: Failed to create directory: {s}\n", .{@errorName(err)});
        }
    };

    // Write version file
    const version_path = "src/generated/version.zig";
    const file = std.fs.cwd().createFile(
        version_path,
        .{ .read = true, .truncate = true },
    ) catch |err| {
        std.debug.print("Warning: Failed to create file: {s}\n", .{@errorName(err)});
        return;
    };
    defer file.close();

    file.writeAll(formatted) catch |err| {
        std.debug.print("Warning: Failed to write to file: {s}\n", .{@errorName(err)});
        return;
    };

    // Create a module for the generated version file
    const version_module = b.createModule(.{
        .root_source_file = b.path(version_path),
    });

    // 1. CORE MODULE - Shared functionality used by both versions
    const core_module = b.createModule(.{
        .root_source_file = b.path("src/core/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add version and metadata information to core module
    core_module.addImport("zeta_version", version_module);

    // 2. MINIMAL VERSION MODULE
    const minimal_module = b.createModule(.{
        .root_source_file = b.path("src/minimal/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link minimal module to core
    minimal_module.addImport("zeta_core", core_module);
    minimal_module.addImport("zeta_version", version_module);

    // 3. FULL VERSION MODULE
    const full_module = b.createModule(.{
        .root_source_file = b.path("src/full/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link full module to core
    full_module.addImport("zeta_core", core_module);
    full_module.addImport("zeta_version", version_module);

    // Create a static library for the core functionality
    const core_lib = b.addStaticLibrary(.{
        .name = "zeta_core",
        .root_module = core_module,
    });

    // Create the minimal executable
    const minimal_exe = b.addExecutable(.{
        .name = "zeta",
        .root_module = minimal_module,
    });

    // Create the full-featured executable
    const full_exe = b.addExecutable(.{
        .name = "zetaf",
        .root_module = full_module,
    });

    // Set install steps
    b.installArtifact(core_lib);
    b.installArtifact(minimal_exe);
    b.installArtifact(full_exe);

    // Create symbolic link for 'z' as alias to 'zetaf'
    const install_symlink = b.addSystemCommand(&[_][]const u8{
        "ln", "-sf", "zetaf", "z",
    });
    install_symlink.setCwd(.{ .cwd_relative = b.install_path });
    install_symlink.step.dependOn(b.getInstallStep());

    // Add run commands for testing
    const run_minimal = b.addRunArtifact(minimal_exe);
    if (b.args) |args| {
        run_minimal.addArgs(args);
    }

    const run_full = b.addRunArtifact(full_exe);
    if (b.args) |args| {
        run_full.addArgs(args);
    }

    // Define build steps
    const run_minimal_step = b.step("run-minimal", "Run the minimal version");
    run_minimal_step.dependOn(&run_minimal.step);

    const run_full_step = b.step("run-full", "Run the full-featured version");
    run_full_step.dependOn(&run_full.step);

    // Tests
    const core_tests = b.addTest(.{
        .root_source_file = b.path("src/core/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    core_tests.root_module.addImport("zeta_version", version_module);

    const minimal_tests = b.addTest(.{
        .root_source_file = b.path("src/minimal/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    minimal_tests.root_module.addImport("zeta_core", core_module);
    minimal_tests.root_module.addImport("zeta_version", version_module);

    const full_tests = b.addTest(.{
        .root_source_file = b.path("src/full/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    full_tests.root_module.addImport("zeta_core", core_module);
    full_tests.root_module.addImport("zeta_version", version_module);

    const run_core_tests = b.addRunArtifact(core_tests);
    const run_minimal_tests = b.addRunArtifact(minimal_tests);
    const run_full_tests = b.addRunArtifact(full_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_core_tests.step);
    test_step.dependOn(&run_minimal_tests.step);
    test_step.dependOn(&run_full_tests.step);

    // Cross-platform builds
    const platforms = [_]struct { name: []const u8, cpu_arch: std.Target.Cpu.Arch, os_tag: std.Target.Os.Tag }{
        .{ .name = "linux-x86_64", .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .name = "macos-aarch64", .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .name = "windows-x86_64", .cpu_arch = .x86_64, .os_tag = .windows },
    };

    // Store all platform build steps to reference them later
    var platform_steps = std.ArrayList(*std.Build.Step).init(b.allocator);

    for (platforms) |platform| {
        const platform_name = platform.name;

        // Create cross target query properly
        var cross_target = std.Target.Query{};
        cross_target.cpu_arch = platform.cpu_arch;
        cross_target.os_tag = platform.os_tag;

        // Create modules specific to this target
        const cross_core_module = b.createModule(.{
            .root_source_file = b.path("src/core/main.zig"),
            .target = b.resolveTargetQuery(cross_target),
            .optimize = .ReleaseFast,
        });
        cross_core_module.addImport("zeta_version", version_module);

        const cross_minimal_module = b.createModule(.{
            .root_source_file = b.path("src/minimal/main.zig"),
            .target = b.resolveTargetQuery(cross_target),
            .optimize = .ReleaseFast,
        });
        cross_minimal_module.addImport("zeta_core", cross_core_module);
        cross_minimal_module.addImport("zeta_version", version_module);

        const cross_full_module = b.createModule(.{
            .root_source_file = b.path("src/full/main.zig"),
            .target = b.resolveTargetQuery(cross_target),
            .optimize = .ReleaseFast,
        });
        cross_full_module.addImport("zeta_core", cross_core_module);
        cross_full_module.addImport("zeta_version", version_module);

        // Create cross-platform minimal executable
        const cross_minimal = b.addExecutable(.{
            .name = b.fmt("{s}-{s}", .{ PROJECT_NAME, platform_name }),
            .root_module = cross_minimal_module,
        });

        // Create cross-platform full executable
        const cross_full = b.addExecutable(.{
            .name = b.fmt("{s}f-{s}", .{ PROJECT_NAME, platform_name }),
            .root_module = cross_full_module,
        });

        // Installation step for cross-platform builds
        const install_cross_minimal = b.addInstallArtifact(cross_minimal, .{
            .dest_dir = .{ .override = .{ .custom = b.fmt("bin/{s}", .{platform_name}) } },
        });

        const install_cross_full = b.addInstallArtifact(cross_full, .{
            .dest_dir = .{ .override = .{ .custom = b.fmt("bin/{s}", .{platform_name}) } },
        });

        // Add steps for each platform
        const platform_step_name = b.fmt("build-{s}", .{platform_name});
        const platform_step = b.step(platform_step_name, b.fmt("Build for {s}", .{platform_name}));
        platform_step.dependOn(&install_cross_minimal.step);
        platform_step.dependOn(&install_cross_full.step);

        // Store the step for later reference
        platform_steps.append(platform_step) catch unreachable;
    }

    // Add a build-all step for all platforms
    const build_all_step = b.step("build-all", "Build for all platforms");
    for (platform_steps.items) |step| {
        build_all_step.dependOn(step);
    }
}
