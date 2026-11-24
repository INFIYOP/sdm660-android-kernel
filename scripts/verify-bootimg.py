#!/usr/bin/env python3
"""Verify a test boot image before flashing it.

usage: verify-bootimg.py boot.img [--image Image.gz] [--expect-msm-id 0x159]
                                  [--expect-board-id 0x40008] [--expect-page 4096]

Checks the ANDROID! header (v0), that the kernel area really starts with the given
Image.gz, that an appended DTB is present, and that its qcom,msm-id / qcom,board-id
start with the expected cells. Exits non-zero on any mismatch.
"""
import argparse
import struct
import sys

FDT_MAGIC = b"\xd0\x0d\xfe\xed"
FDT_BEGIN_NODE, FDT_END_NODE, FDT_PROP, FDT_NOP, FDT_END = 1, 2, 3, 4, 9


def parse_header(data):
    if data[:8] != b"ANDROID!":
        sys.exit("not a boot image: missing ANDROID! magic")
    (ksize, kaddr, rsize, raddr, ssize, saddr, tags, page) = struct.unpack("<8I", data[8:40])
    dt_size, unused = struct.unpack("<2I", data[40:48])
    cmdline = data[64:64 + 512].split(b"\0")[0].decode(errors="replace")
    if page not in (2048, 4096, 8192, 16384):
        sys.exit(f"implausible page size {page}")
    if page + ksize > len(data):
        sys.exit(f"kernel area runs past end of file ({ksize} B at page {page})")
    return dict(kernel_size=ksize, kernel_addr=kaddr, ramdisk_size=rsize,
                ramdisk_addr=raddr, second_size=ssize, tags=tags, page=page,
                header_version=dt_size, cmdline=cmdline)


def find_dtb(blob):
    i = 0
    while True:
        i = blob.find(FDT_MAGIC, i)
        if i < 0:
            return None
        if len(blob) - i >= 40:
            total, off_struct, off_str, _, ver, last = struct.unpack(">6I", blob[i + 4:i + 28])
            if 40 <= total <= len(blob) - i and ver >= 16 and last <= ver \
                    and off_struct < total and off_str < total:
                return i, blob[i:i + total]
        i += 4


def root_props(dtb):
    total, off_struct, off_str = struct.unpack(">3I", dtb[4:16])
    strings = dtb[off_str:off_str + struct.unpack(">I", dtb[32:36])[0]]
    pos, depth, props = off_struct, 0, {}
    while pos + 4 <= len(dtb):
        tok = struct.unpack(">I", dtb[pos:pos + 4])[0]
        pos += 4
        if tok == FDT_BEGIN_NODE:
            end = dtb.index(b"\0", pos)
            pos = (end + 4) & ~3
            depth += 1
        elif tok == FDT_END_NODE:
            depth -= 1
            if depth <= 0:
                break
        elif tok == FDT_PROP:
            length, nameoff = struct.unpack(">2I", dtb[pos:pos + 8])
            pos += 8
            name = strings[nameoff:strings.index(b"\0", nameoff)].decode()
            value = dtb[pos:pos + length]
            pos = (pos + length + 3) & ~3
            if depth == 1:
                props[name] = value
        elif tok in (FDT_NOP,):
            continue
        elif tok == FDT_END:
            break
        else:
            break
    return props


def cells(value):
    return list(struct.unpack(f">{len(value) // 4}I", value[:len(value) // 4 * 4]))


def parse_expect(text):
    out = []
    for tok in text.replace(",", " ").split():
        out.append(int(tok, 0))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("bootimg")
    ap.add_argument("--image")
    ap.add_argument("--expect-msm-id")
    ap.add_argument("--expect-board-id")
    ap.add_argument("--expect-page", type=int)
    a = ap.parse_args()

    data = open(a.bootimg, "rb").read()
    h = parse_header(data)
    print(f"{a.bootimg}: {len(data)} B, page {h['page']}, kernel {h['kernel_size']} B "
          f"@ {h['kernel_addr']:#x}, ramdisk {h['ramdisk_size']} B @ {h['ramdisk_addr']:#x}, "
          f"tags {h['tags']:#x}, header v{h['header_version']}")
    print(f"  cmdline: {h['cmdline']}")

    errors = []
    if a.expect_page and h["page"] != a.expect_page:
        errors.append(f"page size {h['page']} != expected {a.expect_page}")

    kernel = data[h["page"]:h["page"] + h["kernel_size"]]

    if a.image:
        image = open(a.image, "rb").read()
        if len(kernel) < len(image) or kernel[:len(image)] != image:
            errors.append(f"kernel area does not start with {a.image}")
        else:
            print(f"  kernel area starts with {a.image} ({len(image)} B) - ok")

    found = find_dtb(kernel)
    if not found:
        errors.append("no appended DTB found in the kernel area")
        props = {}
    else:
        off, dtb = found
        props = root_props(dtb)
        print(f"  appended DTB at {h['page'] + off:#x}, {len(dtb)} B")

    model = props.get("model", b"").rstrip(b"\0").decode(errors="replace")
    compat = props.get("compatible", b"")
    if model:
        print(f"  model: {model}")
    if compat:
        names = [s.decode() for s in compat.split(b"\0") if s]
        print(f"  compatible: {', '.join(names)}")

    for key, expect in (("qcom,msm-id", a.expect_msm_id), ("qcom,board-id", a.expect_board_id)):
        if key not in props:
            if expect:
                errors.append(f"{key} missing from the appended DTB")
            continue
        actual = cells(props[key])
        shown = " ".join(f"{v:#x}" for v in actual)
        if expect:
            want = parse_expect(expect)
            if actual[:len(want)] != want:
                errors.append(f"{key} = <{shown}> does not start with "
                              f"<{' '.join(f'{v:#x}' for v in want)}>")
            else:
                print(f"  {key} = <{shown}> - matches")
        else:
            print(f"  {key} = <{shown}>")

    if errors:
        for e in errors:
            print(f"FAIL: {e}", file=sys.stderr)
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
