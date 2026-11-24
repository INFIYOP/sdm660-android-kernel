#!/usr/bin/env bash
# Build the mainline Android kernel for SDM636 (tulip/whyred) with Neutron Clang (LLVM=1).
# usage: scripts/build-kernel-clang.sh
# env:   KDIR (default linux)  OUT (default out-neutron)  NEUTRON_DIR  JOBS (default nproc)  BRANCH (default qcom-sdm660-7.2.y)
# Layout expected: patches/000*.patch, configs/sdm660_android_defconfig (same as the GCC workflow).
set -euo pipefail
ROOT="$(pwd)"
KDIR="${KDIR:-linux}"; OUT="${OUT:-out-neutron}"; BRANCH="${BRANCH:-qcom-sdm660-7.2.y}"
NEUTRON_DIR="${NEUTRON_DIR:-$HOME/toolchains/neutron-clang}"
JOBS="${JOBS:-$(nproc)}"
export PATH="$NEUTRON_DIR/bin:$PATH"
export ARCH=arm64 LLVM=1
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-sdm660-port}" KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github-actions}"
command -v clang >/dev/null || { echo "ERROR: clang not found; run scripts/setup-neutron-clang.sh"; exit 1; }

[ -d "$KDIR" ] || git clone --depth 1 --branch "$BRANCH" https://github.com/sdm660-mainline/linux.git "$KDIR"
# apply the Android feature patches once
if ! grep -q "NETFILTER_XT_MATCH_QUOTA2" "$KDIR/net/netfilter/Kconfig"; then
  for p in "$ROOT"/patches/000*.patch; do ( cd "$KDIR" && git apply "$p" ); done
fi
mkdir -p "$ROOT/$OUT"
cp "$ROOT/configs/sdm660_android_defconfig" "$KDIR/arch/arm64/configs/"
cd "$KDIR"
make sdm660_android_defconfig
# The point of this build: the compiler must really be clang.
grep -q '^CONFIG_CC_IS_CLANG=y' .config || { echo "ERROR: .config says the compiler is not clang"; exit 1; }
grep -E '^CONFIG_(CC_IS_CLANG|LD_IS_LLD|AS_IS_LLVM|LTO_NONE|SHADOW_CALL_STACK)=' .config | tee "$ROOT/$OUT/toolchain-config.txt"

log="$ROOT/$OUT/build-clang.log"
{
  clang --version | head -2
  make -j"$JOBS" Image.gz modules
  make -j"$JOBS" qcom/sdm636-xiaomi-tulip.dtb qcom/sdm636-xiaomi-whyred-tianma.dtb qcom/sdm636-xiaomi-whyred-shenchao.dtb
} 2>&1 | tee "$log"

# Warnings are findings: summarise them so the source can be fixed (do not silence them).
grep -E 'warning:' "$log" | sed 's/^[^ ]* //' | sort | uniq -c | sort -rn | head -200 > "$ROOT/$OUT/clang-warnings.txt" || true
echo "distinct warning kinds: $(wc -l < "$ROOT/$OUT/clang-warnings.txt")"

cp arch/arm64/boot/Image.gz "$ROOT/$OUT/"
cp arch/arm64/boot/dts/qcom/sdm636-xiaomi-*.dtb "$ROOT/$OUT/"
cp .config "$ROOT/$OUT/sdm660_android_defconfig.built"
mods="$(mktemp -d)"
make INSTALL_MOD_PATH="$mods" modules_install
depmod -b "$mods" "$(make -s kernelrelease)"
rm -f "$mods"/lib/modules/*/build "$mods"/lib/modules/*/source
tar -C "$(dirname "$mods")" -cf "$ROOT/$OUT/modules.tar" "$(basename "$mods")"
cat arch/arm64/boot/Image.gz arch/arm64/boot/dts/qcom/sdm636-xiaomi-tulip.dtb > "$ROOT/$OUT/Image.gz-dtb-tulip"
echo "done: $ROOT/$OUT"
