# Building with Neutron Clang

Goal (from the maintainer): the final kernel is built with Neutron Clang. The GCC workflow stays as the quick iteration build; both use the
same sources, patches and defconfig.

## How Neutron is used here
- Installed with its own manager: `antman -S` (latest) or `antman -S=<release tag>`; if the binaries do not run on the host,
  `antman --patch=glibc` (needs bsdtar from libarchive-tools). Source: github.com/Neutron-Toolchains/antman README.
- The kernel is built with `make LLVM=1 ARCH=arm64`. With LLVM=1 no CROSS_COMPILE prefix is needed; `LLVM=/path/to/llvm/` also works if the
  toolchain is not on PATH (kernel docs, Documentation/kbuild/llvm.rst).
- This kernel requires LLVM >= 17.0.1 (scripts/min-tool-version.sh in qcom-sdm660-7.2.y). `scripts/setup-neutron-clang.sh linux` checks it.
- Only the kernel is built with clang. The boot-test `init` is a userspace program and is still built with `aarch64-linux-gnu-gcc -static`.

## Files
- `scripts/setup-neutron-clang.sh`  install + version check (pin with NEUTRON_TAG for reproducible builds)
- `scripts/build-kernel-clang.sh`   clone, patch, defconfig, build Image.gz/modules/DTBs, summarise warnings, pack modules.tar
- `.github/workflows/build-kernel-neutron.yml`  manual workflow (workflow_dispatch) producing artifact `kernel-artifacts-neutron`
- `configs/neutron-lto-thin.fragment`  OPTIONAL ThinLTO, only after a plain clang build works

## What changes with clang (known from the configs, not yet observed)
- android-base wants `CONFIG_LD_IS_LLD=y` (and CC_IS_CLANG / AS_IS_LLVM, which kconfig sets automatically). These were "unmet" with GCC and should be satisfied now.
- The GCC build config shows `CONFIG_SHADOW_CALL_STACK=y`; clang is the intended compiler for it.
- LTO stays `LTO_NONE` until the optional fragment is merged.
- Expect NEW warnings from clang, including in the ported files (patches 0001-0003). They are findings: do not silence them with flags;
  send `clang-warnings.txt` back so the source can be fixed.

## What the compile agent must report
1. `toolchain-config.txt`: must show CC_IS_CLANG=y, LD_IS_LLD=y.
2. Whether the build passed, and the distinct warning list (`clang-warnings.txt`), with file names for warnings in xt_quota2.c, uid_sys_stats.c, fs/sync.c.
3. Image.gz size vs the GCC build (13.4 MB in v7-testing) and the number of modules; if the module set differs from
   `android/device/generic/sdm660/*/modules.all`, re-run scripts/select-modules.py.
4. The result of the boot-image verification step.

## Not verified
Nothing here has been run. I do not know Neutron's current LLVM version, whether the latest release still installs cleanly with antman on
ubuntu-24.04, or how this kernel behaves under clang. The workflow is the way to find out.
