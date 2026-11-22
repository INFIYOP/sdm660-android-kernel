#!/usr/bin/env python3
"""List the bootloader (LK) selection IDs found in the DTBs appended to a stock kernel/boot.img.

usage: extract-lk-ids.py <stock boot.img | stock kernel file> [--dump dir]
Xiaomi's LK picks an appended DTB by qcom,msm-id / qcom,board-id / qcom,pmic-id. The mainline tulip/whyred DTBs have none,
so an appended-DTB boot image may be rejected. Run this on YOUR stock boot.img, find the DTB for your phone, then add the
same properties to the mainline dts (docs/LK_IDS.md). Needs dtc. Nothing here is guessed.
"""
import struct, subprocess, sys, os, re, argparse
ap = argparse.ArgumentParser(); ap.add_argument('image'); ap.add_argument('--dump', default='')
a = ap.parse_args()
data = open(a.image, 'rb').read()
MAGIC = b'\xd0\x0d\xfe\xed'
i, n, found = 0, 0, []
while True:
    i = data.find(MAGIC, i)
    if i < 0: break
    if len(data) - i > 40:
        total, off_struct, off_str, off_rsv, ver, last = struct.unpack('>6I', data[i+4:i+28])
        if 40 <= total <= len(data) - i and ver >= 16 and last <= ver and off_struct < total and off_str < total:
            found.append((i, data[i:i+total])); i += total; continue
    i += 4
print(f'{len(found)} DTB(s) found in {a.image}')
if a.dump: os.makedirs(a.dump, exist_ok=True)
for k, (off, blob) in enumerate(found):
    p = subprocess.run(['dtc', '-I', 'dtb', '-O', 'dts'], input=blob, capture_output=True)
    txt = p.stdout.decode(errors='replace')
    def grab(key):
        m = re.search(rf'{re.escape(key)} = (<[^>]*>);', txt); return m.group(1) if m else '-'
    model = re.search(r'model = "([^"]*)"', txt)
    comp = re.search(r'compatible = ([^;]*);', txt)
    print(f'#{k} offset {off:#x} size {len(blob)}  model={model.group(1) if model else "-"}')
    print(f'    compatible={comp.group(1) if comp else "-"}')
    for key in ('qcom,msm-id', 'qcom,board-id', 'qcom,pmic-id'):
        print(f'    {key} = {grab(key)}')
    if a.dump:
        open(os.path.join(a.dump, f'stock-{k}.dtb'), 'wb').write(blob)
        open(os.path.join(a.dump, f'stock-{k}.dts'), 'w').write(txt)
