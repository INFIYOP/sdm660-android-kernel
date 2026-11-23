#!/usr/bin/env python3
"""Pack a legacy A-only (header v0) boot image.

Fallback for scripts/make-bootimg.sh when the distro's mkbootimg is unusable --
Ubuntu's is a Python wrapper that imports a `gki` module it does not ship.
Accepts the same flags make-bootimg.sh passes to mkbootimg.
"""
import argparse
import hashlib
import struct
import sys

MAGIC = b"ANDROID!"
HEADER_SIZE = 1632


def align(n, page):
    return (n + page - 1) // page * page


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--kernel", required=True)
    p.add_argument("--ramdisk")
    p.add_argument("--second")
    p.add_argument("--base", default="0x00000000")
    p.add_argument("--kernel_offset", default="0x00008000")
    p.add_argument("--ramdisk_offset", default="0x01000000")
    p.add_argument("--second_offset", default="0x00f00000")
    p.add_argument("--tags_offset", default="0x00000100")
    p.add_argument("--pagesize", type=int, default=4096)
    p.add_argument("--cmdline", default="")
    p.add_argument("--header_version", type=int, default=0)
    p.add_argument("-o", "--output", default="boot.img")
    a = p.parse_args()

    if a.header_version != 0:
        sys.exit("only header v0 is implemented")

    kernel = open(a.kernel, "rb").read()
    ramdisk = open(a.ramdisk, "rb").read() if a.ramdisk else b""
    second = open(a.second, "rb").read() if a.second else b""

    base = int(a.base, 0)
    cmdline = a.cmdline.encode()
    if len(cmdline) > 511:
        sys.exit("cmdline too long")

    digest = hashlib.sha1()
    for blob in (kernel, ramdisk, second):
        digest.update(blob)
        digest.update(struct.pack("<I", len(blob)))
    image_id = digest.digest()

    header = MAGIC
    # mkbootimg leaves second_addr at 0 when there is no second stage; match it
    # so the fallback and the real tool produce identical images.
    second_addr = base + int(a.second_offset, 0) if second else 0
    header += struct.pack("<8I", len(kernel), base + int(a.kernel_offset, 0),
                          len(ramdisk), base + int(a.ramdisk_offset, 0),
                          len(second), second_addr,
                          base + int(a.tags_offset, 0), a.pagesize)
    header += struct.pack("<2I", 0, 0)          # dt_size, unused (v0)
    header += b"\0" * 16                        # name
    header += cmdline.ljust(512, b"\0")
    header += image_id.ljust(32, b"\0")
    header += b"\0" * 1024                      # extra_cmdline
    assert len(header) == HEADER_SIZE, len(header)
    header = header.ljust(align(HEADER_SIZE, a.pagesize), b"\0")

    out = header
    for blob in (kernel, ramdisk, second):
        out += blob.ljust(align(len(blob), a.pagesize), b"\0")

    with open(a.output, "wb") as f:
        f.write(out)
    print(f"wrote {a.output}: kernel {len(kernel)} B, ramdisk {len(ramdisk)} B, page {a.pagesize}")


if __name__ == "__main__":
    main()
