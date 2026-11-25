#!/usr/bin/env bash
# Pack kernel + appended DTB (+ optional ramdisk) into a legacy A-only boot.img for `fastboot boot` testing.
# usage: scripts/make-bootimg.sh --kernel Image.gz --dtb sdm636-xiaomi-tulip.dtb [--ramdisk initramfs.gz] [--out boot.img]
# Defaults follow LineageOS android_device_xiaomi_sdm660-common (base 0, page 4096, tags 0x100, ramdisk 0x01000000).
# Confirmed against the stock boot.img uploaded 2026-11-23 (docs/STOCK_BOOT_PARAMS.md): base 0, page 4096, kernel 0x8000, ramdisk 0x1000000, tags 0x100, header v0.
# Needs: mkbootimg (android-tools-mkbootimg or AOSP mkbootimg.py). Does not compile anything.
set -euo pipefail
KERNEL=""; DTB=""; RAMDISK=""; OUT="boot.img"
while [ $# -gt 0 ]; do case "$1" in
  --kernel) KERNEL="$2"; shift 2;; --dtb) DTB="$2"; shift 2;;
  --ramdisk) RAMDISK="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  *) echo "unknown arg $1"; exit 2;; esac; done
[ -f "$KERNEL" ] && [ -f "$DTB" ] || { echo "need --kernel and --dtb files"; exit 2; }
BASE="${BASE:-0x00000000}"; PAGESIZE="${PAGESIZE:-4096}"; KERNEL_OFFSET="${KERNEL_OFFSET:-0x00008000}"
RAMDISK_OFFSET="${RAMDISK_OFFSET:-0x01000000}"; TAGS_OFFSET="${TAGS_OFFSET:-0x00000100}"
CMDLINE="${CMDLINE:-console=tty0 no_console_suspend printk.devkmsg=on ignore_loglevel panic=5 deferred_probe_timeout=30}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat "$KERNEL" "$DTB" > "$TMP/kernel-dtb"
args=(--kernel "$TMP/kernel-dtb" --base "$BASE" --pagesize "$PAGESIZE" --kernel_offset "$KERNEL_OFFSET"
      --ramdisk_offset "$RAMDISK_OFFSET" --tags_offset "$TAGS_OFFSET" --cmdline "$CMDLINE" --header_version 0 -o "$OUT")
[ -n "$RAMDISK" ] && args+=(--ramdisk "$RAMDISK")
if mkbootimg --help >/dev/null 2>&1; then
  mkbootimg "${args[@]}"
else
  # Ubuntu's mkbootimg is a Python wrapper that imports a `gki` module it does not
  # ship, so it dies on import. pack-bootimg.py produces byte-identical output.
  echo "mkbootimg unusable here; falling back to scripts/pack-bootimg.py"
  python3 "$(dirname "$0")/pack-bootimg.py" "${args[@]}"
fi
echo "wrote $OUT. Test with: fastboot boot $OUT   (does not touch your boot partition)"
echo "NOTE: use a DTB built WITH patch 0004 (bootloader ids). Check: python3 scripts/extract-lk-ids.py <dtb> shows non-empty msm-id/board-id."
