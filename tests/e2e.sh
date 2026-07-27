#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Contractiles End-to-End Tests
#
# End-to-end tests validate the full pipeline: build → run → verify output.
# For this repository that pipeline is: the Idris2 ABI package typechecks,
# and the Zig FFI that implements it builds and passes its own tests.
#
# Usage:
#   bash tests/e2e.sh
#   just e2e
#
# Merge requirements (STANDING): All 6 test categories must pass before merge:
#   P2P, E2E (this file), aspect, execution, lifecycle, benchmarks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
SKIP=0

# ─── Colour helpers ──────────────────────────────────────────────────
green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

# ─── Assertion helpers ───────────────────────────────────────────────

# check <label> <expected-substring> <actual>
check() {
    local name="$1" expected="$2" actual="$3"
    if echo "$actual" | grep -q "$expected"; then
        green "  PASS: $name"
        PASS=$((PASS + 1))
    else
        red "  FAIL: $name (expected '$expected', got '${actual:0:120}')"
        FAIL=$((FAIL + 1))
    fi
}

# check_status <label> <expected-http-status> <actual-http-status>
check_status() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        green "  PASS: $name (HTTP $actual)"
        PASS=$((PASS + 1))
    else
        red "  FAIL: $name (expected HTTP $expected, got HTTP $actual)"
        FAIL=$((FAIL + 1))
    fi
}

# skip <label> <reason>
skip_test() {
    yellow "  SKIP: $1 ($2)"
    SKIP=$((SKIP + 1))
}

echo "═══════════════════════════════════════════════════════════════"
echo "  CONTRACTILES — End-to-End Tests"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ─── Preflight ───────────────────────────────────────────────────────
bold "Preflight checks"

HAVE_IDRIS2=1
HAVE_ZIG=1
command -v idris2 >/dev/null 2>&1 || HAVE_IDRIS2=0
command -v zig >/dev/null 2>&1 || HAVE_ZIG=0

echo ""

# ─── Section 1: Idris2 ABI typechecks ────────────────────────────────
bold "Section 1: Idris2 ABI (abi.ipkg)"
if [ "$HAVE_IDRIS2" -eq 1 ]; then
    OUTPUT=$(cd "$PROJECT_DIR" && idris2 --build abi.ipkg 2>&1) && ABI_OK=1 || ABI_OK=0
    if [ "$ABI_OK" -eq 1 ]; then
        green "  PASS: idris2 --build abi.ipkg"
        PASS=$((PASS + 1))
    else
        red "  FAIL: idris2 --build abi.ipkg"
        echo "$OUTPUT" | sed 's/^/    /'
        FAIL=$((FAIL + 1))
    fi
else
    skip_test "Idris2 ABI build" "idris2 not on PATH"
fi

# ─── Section 2: Zig FFI builds and passes its tests ──────────────────
bold "Section 2: Zig FFI (src/interface/ffi)"
if [ "$HAVE_ZIG" -eq 1 ]; then
    if (cd "$PROJECT_DIR/src/interface/ffi" && zig build test --summary none) >/tmp/contractiles-e2e-zig.log 2>&1; then
        green "  PASS: zig build test"
        PASS=$((PASS + 1))
    else
        red "  FAIL: zig build test"
        sed 's/^/    /' /tmp/contractiles-e2e-zig.log
        FAIL=$((FAIL + 1))
    fi
    rm -f /tmp/contractiles-e2e-zig.log
else
    skip_test "Zig FFI build+test" "zig not on PATH"
fi

# ═══════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════════"
printf "  Results: "
green "PASS=$PASS" | tr -d '\n'
echo -n "  "
if [ "$FAIL" -gt 0 ]; then red "FAIL=$FAIL" | tr -d '\n'; else echo -n "FAIL=0"; fi
echo -n "  "
if [ "$SKIP" -gt 0 ]; then yellow "SKIP=$SKIP"; else echo "SKIP=0"; fi
echo "═══════════════════════════════════════════════════════════════"

exit "$FAIL"
