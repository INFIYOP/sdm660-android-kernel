#!/usr/bin/env bash
# Known-good mainline bring-up via postmarketOS. Review before running.
# WARNING: flashing the rootfs to userdata wipes the phone. Run 00-backup-partitions.sh first.
set -e
command -v pmbootstrap >/dev/null || { echo "Install pmbootstrap first (see postmarketOS wiki)."; exit 1; }
echo "1) pmbootstrap init   -> choose device 'xiaomi-tulip', UI 'console' or 'none' for bring-up"
pmbootstrap init
echo "2) Build image"
pmbootstrap install
echo "3) Flash (phone in fastboot). This overwrites userdata."
read -r -p "Continue? [y/N] " a; [ "$a" = y ] || exit 0
pmbootstrap flasher flash_rootfs
echo "4) Test kernel without overwriting boot:"
pmbootstrap flasher boot
echo "Then: ssh user@172.16.42.1 (USB networking) and fill FEATURE_MATRIX.md"
