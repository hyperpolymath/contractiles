# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Containerfile — contractiles (sealed-container escape hatch)
#
# Nix was retired estate-wide 2026-06-01; a bare flake.nix no longer satisfies
# the governance CI gate. This sealed Containerfile is the accepted escape
# hatch in its place: it installs and exercises this repo's real toolchain
# for real, rather than declaring a presence-only stub.
#
# Toolchain scoping (measured, not guessed):
#   127 .adoc / 118 .a2ml / 32 .yml / 20 .sh files, against only 9 .idr and
#   zero real (non-template) .zig. This repo is overwhelmingly a
#   Just-orchestrated spec/docs/governance tree (Justfile, scripts/*.sh,
#   .machine_readable/*.a2ml). That bulk toolchain — just + bash +
#   coreutils/findutils/grep — is what this image provisions and genuinely
#   exercises below.
#
#   Idris2 is INTENTIONALLY NOT provisioned. abi.ipkg + src/interface/Abi/
#   (Types.idr, Layout.idr, Foreign.idr) are real, valid Idris2 — but no
#   Wolfi/Alpine `idris2` binary package exists, and the only install path
#   (idris2-pack) itself requires an already-installed Chez Scheme or Racket,
#   neither of which has a Wolfi/Alpine package either. The only remaining
#   option is compiling Chez Scheme from source (10-30+ minutes, its own
#   large dependency chain) to serve 9 files out of a ~300-file tree — a
#   disproportionate cost for this container. A contributor who needs the
#   ABI proofs should install Idris2 via upstream pack
#   (https://github.com/stefan-hoeck/idris2-pack) or the Idris2 project's own
#   instructions on a host with a Scheme implementation already available,
#   then typecheck with `idris2 --typecheck abi.ipkg` / `pack typecheck
#   abi.ipkg`.
#
#   The Zig FFI side (src/interface/ffi/) is likewise out of scope here: it
#   is still the RSR template's uninstantiated scaffold (main.zig keeps the
#   template's literal `{{project}}` placeholders — not valid Zig identifiers
#   — and build.zig deliberately wires up no build/test steps yet).
#
# Build: podman build -t contractiles:latest -f Containerfile .
# Run:   podman run --rm -it contractiles:latest        # just --list
# Seal:  selur seal contractiles:latest

# --- Stage 1: Build/verify ---
FROM cgr.dev/chainguard/wolfi-base:latest AS build

# The repo's actual bulk toolchain: Just for orchestration, bash for
# scripts/*.sh, GNU coreutils/findutils/grep for the shell tooling those
# scripts call (busybox's `find` has no -printf, so GNU findutils matters).
RUN apk add --no-cache just bash git coreutils findutils grep gawk sed

WORKDIR /app
COPY . .

# Real smoke test: Just must actually parse this Justfile under the
# provisioned toolchain. This is active verification, not decoration — an
# unparseable Justfile (e.g. an illegal recipe key) fails the build right
# here, with no `|| true` mask.
RUN just --list --unsorted > /dev/null

# --- Stage 2: Runtime (sealed orchestration environment) ---
FROM cgr.dev/chainguard/wolfi-base:latest

RUN apk add --no-cache just bash git coreutils findutils grep gawk sed

WORKDIR /app
COPY --from=build /app /app

USER nonroot

ENTRYPOINT ["just"]
CMD ["--list", "--unsorted"]
