#!/usr/bin/env bash
# Download a kernel release from GitHub and install it into the Android device tree.
# usage: scripts/fetch-prebuilt-kernel.sh [tag] [aosp_device_dir]
#   tag              default v7.2.3-sdm660-r1
#   aosp_device_dir  default ./android/device/generic/sdm660   (or $AOSP/device/generic/sdm660)
# Needs: curl, tar, zstd, sha256sum. Does not compile anything.
set -euo pipefail
TAG="${1:-v7.2.3-sdm660-r1}"
DEV="${2:-android/device/generic/sdm660}"
REPO="${REPO:-INFIYOP/sdm660-android-kernel}"
BASE="https://github.com/$REPO/releases/download/$TAG"
OUT="$DEV/shared/prebuilt-kernel/android-mainline"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT/modules"

for f in SHA256SUMS Image.gz sdm636-xiaomi-tulip.dtb sdm636-xiaomi-whyred-tianma.dtb sdm636-xiaomi-whyred-shenchao.dtb modules.tar; do
  echo "fetch $f"; curl -fsSL -o "$WORK/$f" "$BASE/$f"
done
( cd "$WORK" && grep -E ' (Image\.gz|sdm636-.*\.dtb|modules\.tar)$' SHA256SUMS | sha256sum -c - )

cp "$WORK"/Image.gz "$WORK"/sdm636-*.dtb "$OUT/"
mkdir -p "$WORK/m" && tar -xf "$WORK/modules.tar" -C "$WORK/m"
MODROOT="$(dirname "$(find "$WORK/m" -name modules.dep | head -1)")"

# decompress only the modules the devices need
for dev in tulip whyred; do
  while read -r name; do
    [ -n "$name" ] || continue
    src="$(find "$MODROOT/kernel" \( -name "$name.ko.zst" -o -name "$name.ko" \) | head -1)"
    [ -n "$src" ] || { echo "MISSING module $name (needed by $dev)"; exit 1; }
    case "$src" in *.zst) zstd -dqf "$src" -o "$OUT/modules/$name.ko" ;; *) cp "$src" "$OUT/modules/$name.ko" ;; esac
  done < "$DEV/$dev/modules.all"
done
echo "installed: $(ls "$OUT/modules" | wc -l) modules, kernel + dtbs in $OUT"
echo "kernel release in the modules: $(basename "$MODROOT")"
