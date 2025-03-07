const std = @import("std");

// Constants for project configuration
const PROJECT_NAME = "zeta";
const VERSION = "0.1.0";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Generate git commit information
    const git_commit_step = b.addSystemCommand(&[_][]const u8{ "git", "rev-parse", "--short", "HEAD" });
    git_commit_step.setCwd(.{ .cwd_relative = b.build_root.path.? });

    // Generate build date information
    const build_date_step = b.addSystemCommand(&[_][]const u8{ "date", "+%Y-%m-%d %H:%M:%S" });

    // Create build options that can be accessed at compile time
    const version_options = b.addOptions();
    version_options.addOption([]const u8, "version", VERSION);
    version_options.addOption(bool, "enable_git_integration", true);

    // For file content, we'll use a separate module instead
    const version_zig = b.addWriteFile("version.zig",
        \\pub const VERSION = "
    ++ VERSION ++
        \\";
        \\pub const GIT_COMMIT = @embedFile("git_commit.txt");
        \\pub const BUILD_DATE = @embedFile("build_date.txt");
        \\
        \\pub const VersionInfo = struct {
        \\    version: []const u8,
        \\    git_commit: []const u8,
        \\    build_date: []const u8,
        \\};
        \\
        \\pub fn getVersionInfo() VersionInfo {
        \\    return VersionInfo{
        \\        .version = VERSION,
        \\        .git_commit = GIT_COMMIT,
        \\        .build_date = BUILD_DATE,
        \\    };
        \\}
    );

    // Create version module
    const version_module = b.createModule(.{
        .root_source_file = version_zig.getDirectory(), // Use getOutput() instead of the step directly
        .target = target,
        .optimize = optimize,
    });

    // 1. CORE MODULE - Shared functionality used by both versions
    const core_module = b.createModule(.{
        .root_source_file = b.path("src/core/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add version and metadata information to core module
    core_module.addOptions("build_options", version_options);
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
    minimal_module.addOptions("build_options", version_options);

    // 3. FULL VERSION MODULE
    const full_module = b.createModule(.{
        .root_source_file = b.path("src/full/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link full module to core
    full_module.addImport("zeta_core", core_module);
    full_module.addImport("zeta_version", version_module);
    full_module.addOptions("build_options", version_options);

    // Write git commit and build date files
    const git_commit_file = b.addWriteFile("git_commit.txt", "");
    git_commit_file.step.dependOn(&git_commit_step.step);
    const build_date_file = b.addWriteFile("build_date.txt", "");
    build_date_file.step.dependOn(&build_date_step.step);

    // Make version module depend on these files
    version_module.addImport("git_commit_file", b.createModule(.{
        .root_source_file = git_commit_file.getDirectory(),
    }));
    version_module.addImport("build_date_file", b.createModule(.{
        .root_source_file = build_date_file.getDirectory(),
    }));

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

    const minimal_tests = b.addTest(.{
        .root_source_file = b.path("src/minimal/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    minimal_tests.root_module.addImport("zeta_core", core_module);

    const full_tests = b.addTest(.{
        .root_source_file = b.path("src/full/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    full_tests.root_module.addImport("zeta_core", core_module);

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
        cross_core_module.addOptions("build_options", version_options);
        cross_core_module.addImport("zeta_version", version_module);

        const cross_minimal_module = b.createModule(.{
            .root_source_file = b.path("src/minimal/main.zig"),
            .target = b.resolveTargetQuery(cross_target),
            .optimize = .ReleaseFast,
        });
        cross_minimal_module.addImport("zeta_core", cross_core_module);
        cross_minimal_module.addImport("zeta_version", version_module);
        cross_minimal_module.addOptions("build_options", version_options);

        const cross_full_module = b.createModule(.{
            .root_source_file = b.path("src/full/main.zig"),
            .target = b.resolveTargetQuery(cross_target),
            .optimize = .ReleaseFast,
        });
        cross_full_module.addImport("zeta_core", cross_core_module);
        cross_full_module.addImport("zeta_version", version_module);
        cross_full_module.addOptions("build_options", version_options);

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
