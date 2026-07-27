// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// Contractiles FFI integration tests.
//
// These exercise the FFI surface declared in src/main.zig (which mirrors the
// Idris2 ABI in src/interface/Abi/Foreign.idr) end-to-end, as a separate
// compilation unit from the module's own inline unit tests.

const std = @import("std");
const contractiles = @import("contractiles");

test "lifecycle: create and destroy handle" {
    const handle = contractiles.contractiles_init() orelse return error.InitFailed;
    defer contractiles.contractiles_free(handle);

    try std.testing.expect(contractiles.contractiles_is_initialized(handle) == 1);
}

test "operations: process with valid handle" {
    const handle = contractiles.contractiles_init() orelse return error.InitFailed;
    defer contractiles.contractiles_free(handle);

    const result = contractiles.contractiles_process(handle, 42);
    try std.testing.expectEqual(contractiles.Result.ok, result);
}

test "operations: process_array with valid handle" {
    const handle = contractiles.contractiles_init() orelse return error.InitFailed;
    defer contractiles.contractiles_free(handle);

    const buf = [_]u8{ 1, 2, 3, 4 };
    const result = contractiles.contractiles_process_array(handle, &buf, buf.len);
    try std.testing.expectEqual(contractiles.Result.ok, result);
}

test "operations: process_array rejects a null buffer" {
    const handle = contractiles.contractiles_init() orelse return error.InitFailed;
    defer contractiles.contractiles_free(handle);

    const result = contractiles.contractiles_process_array(handle, null, 0);
    try std.testing.expectEqual(contractiles.Result.null_pointer, result);
}

test "strings: get_string result from handle" {
    const handle = contractiles.contractiles_init() orelse return error.InitFailed;
    defer contractiles.contractiles_free(handle);

    const str = contractiles.contractiles_get_string(handle);
    defer if (str) |s| contractiles.contractiles_free_string(s);

    try std.testing.expect(str != null);
}

test "version: returns non-empty version string" {
    const ver = contractiles.contractiles_version();
    const ver_str = std.mem.span(ver);
    try std.testing.expect(ver_str.len > 0);
}

test "build_info: reports the Zig version used to build" {
    const info = contractiles.contractiles_build_info();
    const info_str = std.mem.span(info);
    try std.testing.expect(info_str.len > 0);
}

test "error handling: operating on a null handle sets last_error" {
    const result = contractiles.contractiles_process(null, 0);
    try std.testing.expectEqual(contractiles.Result.null_pointer, result);

    const err = contractiles.contractiles_last_error();
    try std.testing.expect(err != null);
}
