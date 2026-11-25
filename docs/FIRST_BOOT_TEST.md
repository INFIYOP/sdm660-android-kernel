# First boot test (tulip) - procedure and how to read the result

Nothing in this repo has booted on hardware. This is the procedure for the first attempt and what each outcome would mean.
Needs the v10 changes: patch 0005 (ramoops layout), the rewritten test init, and the new default kernel command line.

## Before
- Battery above 50%, bootloader unlocked, USB cable to a PC with fastboot.
- Keep your original stock boot.img safe (the one you uploaded). Know the fastboot key combo (Volume Down + Power).
- Confirm the model: `getprop ro.product.model` should end in E7T (tulip). The tulip<->E7T mapping is inferred from model numbers.
- Ideally the partition backup (scripts/00-backup-partitions.sh) is done first, although `fastboot boot` writes nothing.

## Run
`fastboot boot boot-tulip-test.img`

## Reading the outcome
| What you see | Most likely meaning |
|---|---|
| fastboot prints FAILED / unknown command | this bootloader may not support `fastboot boot`. Fallback: `fastboot flash boot boot-tulip-test.img`, test, then restore with `fastboot flash boot <your stock boot.img>`. The phone can still reach fastboot with the key combo, because that does not depend on the boot partition |
| Returns to fastboot or reboots within a few seconds | the bootloader probably rejected the image or its DTB (ids / format). Note exactly what happened |
| Stays on the logo or a black screen | the kernel may be running without display. Go to the pstore step |
| Kernel text on screen, then "MAINLINE BOOT OK - restarting in N s" for 60 s, then it restarts | bootloader accepted the DTB, kernel reached userspace. This is the Phase 1 gate |
| Kernel text then a panic | read the message, photograph it, and use the pstore step |

These are expectations, not observations.

## Reading the kernel log with no serial cable (pstore)
The mainline tulip dts now uses the same ramoops region and layout as your stock DTBs (0xa0000000, 4 MB, console 2 MB, pmsg 2 MB), and
the test image sets `panic=5` and `ignore_loglevel` and restarts instead of powering off. After the phone restarts into your normal OS:
```
adb shell su -c 'ls -l /sys/fs/pstore'
adb shell su -c 'cat /sys/fs/pstore/console-ramoops-0' > mainline-console.log
```
Copy it immediately. The file only exists for that boot.
Limits: it needs a warm restart (a long-press power-off or battery pull loses RAM), and your normal kernel must have pstore/ramoops enabled.
Whether the bootloader preserves that RAM across the restart is not verified.

## Send back
A photo of the screen, the fastboot output, and mainline-console.log if you get one.
