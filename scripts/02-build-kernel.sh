#!/usr/bin/env bash
# Build the mainline Android kernel + DTBs for tulip/whyred and pack a test boot.img.
# Needs: gcc-aarch64-linux-gnu flex bison bc libssl-dev libelf-dev device-tree-compiler mkbootimg (or AOSP mkbootimg.py)
# NOTE: a full kernel build is slow on a small machine; use the GitHub Actions workflow (build-kernel.yml) instead.
set -euo pipefail
KDIR="${KDIR:-linux}"
BRANCH="${BRANCH:-qcom-sdm660-7.2.y}"
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
[ -d "$KDIR" ] || git clone --depth 1 --branch "$BRANCH" https://github.com/sdm660-mainline/linux.git "$KDIR"
cp sdm660_android_defconfig "$KDIR/arch/arm64/configs/sdm660_android_defconfig"
( cd "$KDIR" && for p in ../000*.patch; do git apply --check "$p" 2>/dev/null && git apply "$p"; done )
cd "$KDIR"
make sdm660_android_defconfig
make -j"$(nproc)" Image.gz qcom/sdm636-xiaomi-tulip.dtb qcom/sdm636-xiaomi-whyred-tianma.dtb qcom/sdm636-xiaomi-whyred-shenchao.dtb
cat arch/arm64/boot/Image.gz arch/arm64/boot/dts/qcom/sdm636-xiaomi-tulip.dtb > ../Image.gz-dtb-tulip
cd ..
# Boot image parameters (pagesize, base, offsets, cmdline) MUST come from the stock boot.img you backed up:
#   unpackbootimg -i backup-*/boot.img -o stock/    (prints the exact values)
# Then fill in below. Left as variables on purpose: do not guess.
: "${PAGESIZE:?set PAGESIZE from stock boot.img}" "${BASE:?set BASE}" "${KERNEL_OFFSET:?set KERNEL_OFFSET}" "${CMDLINE:?set CMDLINE}"
mkbootimg --kernel Image.gz-dtb-tulip --base "$BASE" --kernel_offset "$KERNEL_OFFSET" \
  --pagesize "$PAGESIZE" --cmdline "$CMDLINE" -o boot-tulip-test.img
echo "Test with: fastboot boot boot-tulip-test.img   (does not overwrite your boot partition)"
