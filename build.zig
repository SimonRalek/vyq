const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "vyq",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("clap", clap.module("clap"));

    exe.linkSystemLibrary("readline");

    b.installArtifact(exe);
    b.exe_dir = "./";
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/scanner.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const release_step = b.step("release", "Build and install release builds for all targets");

    const release_targets: []const std.zig.CrossTarget = &.{
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
    };

    const wasm_target = std.zig.CrossTarget{ .cpu_arch = .wasm32, .os_tag = .freestanding };
    const wasm_exe = b.addSharedLibrary(.{
        .name = "vyq",
        .root_source_file = .{ .path = "src/wasm.zig" },
        .target = wasm_target,
        .optimize = .ReleaseFast,
    });
    wasm_exe.rdynamic = true;
    const wasm_dir = b.addInstallArtifact(wasm_exe, .{
        .dest_dir = .{
            .override = .{ .custom = "../www/" },
        },
    });
    release_step.dependOn(&wasm_dir.step);

    for (release_targets) |release_target| {
        const release_exe = b.addExecutable(.{
            .name = "vyq",
            .root_source_file = .{ .path = "src/main.zig" },
            .target = release_target,
            .optimize = .ReleaseFast,
        });

        release_exe.linkLibC();
        release_exe.addModule("clap", clap.module("clap"));

        if (release_target.os_tag == .linux) {
            release_exe.addIncludePath(.{ .path = "/usr/include" });
            release_exe.addLibraryPath(.{ .path = "/usr/lib/x86_64-linux-gnu" });
            release_exe.linkSystemLibrary("readline");
        }

        const installed_release_exe = b.addInstallArtifact(release_exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = try release_target.zigTriple(b.allocator),
                },
            },
        });

        release_step.dependOn(&installed_release_exe.step);
    }
}
