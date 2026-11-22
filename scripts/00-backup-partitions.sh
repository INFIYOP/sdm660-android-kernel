#!/usr/bin/env bash
# Back up critical partitions over adb. Run with the phone in TWRP/OrangeFox recovery (adb root).
# Output goes to ./backup-<date>/. Missing partitions are skipped.
set -u
OUT="backup-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$OUT"
BASE=/dev/block/bootdevice/by-name
PARTS="persist modemst1 modemst2 fsg modem dsp bluetooth boot recovery misc devinfo sec keystore oem cust splash"
adb get-state >/dev/null 2>&1 || { echo "No adb device"; exit 1; }
for p in $PARTS; do
  if adb shell "[ -e $BASE/$p ]" 2>/dev/null; then
    echo "Backing up $p"
    adb exec-out "dd if=$BASE/$p bs=1M 2>/dev/null" > "$OUT/$p.img"
  else
    echo "Skipping $p (not found)"
  fi
done
( cd "$OUT" && sha256sum *.img > SHA256SUMS )
echo "Done. Copy $OUT somewhere safe (not only this machine)."
