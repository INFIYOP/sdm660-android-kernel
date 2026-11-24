#!/usr/bin/env bash
# Install Neutron Clang with its own manager (antman) and check it can build this kernel.
# usage: scripts/setup-neutron-clang.sh [kernel_dir_for_min_version_check]
# env:   NEUTRON_DIR (default $HOME/toolchains/neutron-clang)   NEUTRON_TAG (optional release tag; default latest)
# Needs: curl, tar, zstd; bsdtar (libarchive-tools) only if the glibc patch step is needed.
set -euo pipefail
DIR="${NEUTRON_DIR:-$HOME/toolchains/neutron-clang}"
KDIR="${1:-}"
mkdir -p "$DIR"; cd "$DIR"
if [ ! -x bin/clang ]; then
  curl -fsSL -o antman https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman
  chmod +x antman
  if [ -n "${NEUTRON_TAG:-}" ]; then ./antman -S="$NEUTRON_TAG"; else ./antman -S; fi
fi
if ! bin/clang --version >/dev/null 2>&1; then
  # Neutron binaries can need a newer glibc than the host; antman can patch them.
  echo "clang does not run as downloaded; trying antman --patch=glibc"
  command -v bsdtar >/dev/null || { echo "ERROR: install libarchive-tools (bsdtar), then rerun"; exit 1; }
  ./antman --patch=glibc
fi
bin/clang --version | head -1
if [ -n "$KDIR" ] && [ -f "$KDIR/scripts/min-tool-version.sh" ]; then
  need="$(sh "$KDIR/scripts/min-tool-version.sh" llvm)"
  have="$(bin/clang --version | sed -n 's/.*clang version \([0-9][0-9]*\).*/\1/p' | head -1)"
  echo "kernel needs LLVM >= $need, Neutron provides $have"
  if [ "${have:-0}" -lt "${need%%.*}" ]; then echo "ERROR: toolchain too old for this kernel"; exit 1; fi
fi
echo "NEUTRON_DIR=$DIR"
