# -*- coding: utf-8 -*-
"""Build a flashable Magisk module zip from the repo root.

Usage:  python build_zip.py
Output: <module_id>_v<version>.zip   (e.g. xiaomi_usb_security_bypass_v1.0.zip)
"""
import os
import re
import zipfile

BASE = os.path.dirname(os.path.abspath(__file__))

# Files packaged into the flashable zip (executable scripts get 0755)
FILES = [
    ("module.prop", 0o644),
    ("system.prop", 0o644),
    ("service.sh", 0o755),
    ("customize.sh", 0o755),
    ("README.md", 0o644),
]


def read_prop(name):
    with open(os.path.join(BASE, "module.prop"), encoding="utf-8") as f:
        m = re.search(rf"^{name}=(.*)$", f.read(), re.M)
    return m.group(1).strip() if m else "unknown"


def build():
    mod_id = read_prop("id")
    version = read_prop("version").lstrip("v")  # "v1.0" -> "1.0"
    out = os.path.join(BASE, f"xiaomi_usb_security_bypass_v{version}.zip")

    if os.path.exists(out):
        os.remove(out)

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel, mode in FILES:
            full = os.path.join(BASE, rel)
            if not os.path.exists(full):
                print(f"!! skip missing: {rel}")
                continue
            with open(full, "rb") as f:
                data = f.read()
            info = zipfile.ZipInfo(rel)
            info.date_time = (2026, 1, 1, 0, 0, 0)
            info.external_attr = mode << 16  # Unix permission bits
            z.writestr(info, data)

    print(f"OK -> {out}")
    with zipfile.ZipFile(out) as z:
        for i in z.infolist():
            print("  %-16s mode=%o size=%d" % (
                i.filename, (i.external_attr >> 16) & 0xFFFF, i.file_size))
    return out


if __name__ == "__main__":
    build()
