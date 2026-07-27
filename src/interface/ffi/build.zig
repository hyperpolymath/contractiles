// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Contractiles FFI build configuration.
//
// Builds the FFI implementation as a static library (linked against libc,
// since main.zig uses std.heap.c_allocator to match the C-facing allocation
// contract), and wires `zig build test` to run both the in-module unit
// tests (src/main.zig) and the separate integration tests (test/integration_test.zig).

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const lib = b.addLibrary(.{
        .name = "contractiles",
        .linkage = .static,
        .root_module = main_mod,
    });
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_module = main_mod,
    });
    const run_main_tests = b.addRunArtifact(main_tests);

    const integration_mod = b.createModule(.{
        .root_source_file = b.path("test/integration_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "contractiles", .module = main_mod },
        },
    });
    const integration_tests = b.addTest(.{
        .root_module = integration_mod,
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);

    const test_step = b.step("test", "Run unit and integration tests");
    test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_integration_tests.step);
}
