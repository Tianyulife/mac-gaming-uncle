#!/usr/bin/env python3
"""Audit a packaged macOS Wine runtime without touching a user's prefix.

Dependency resolution follows the application's DYLD_LIBRARY_PATH (runtime/lib)
and loader-relative paths. This is a packaging gate, not a game compatibility test.
"""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import struct
import sys


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def audit(root):
    errors = []
    required = [
        "bin/wine", "bin/wineserver", "runtime-version.txt", "source.lock.json",
        "lib/wine/x86_64-unix/ntdll.so", "lib/wine/x86_64-unix/winecoreaudio.so",
        "lib/wine/x86_64-unix/winebus.so", "lib/libfreetype.6.dylib",
        "lib/libgnutls.30.dylib", "lib/libgmp.10.dylib", "lib/libnettle.8.dylib",
        "lib/libhogweed.6.dylib", "lib/libinotify.0.dylib", "lib/libSDL2-2.0.0.dylib",
    ]
    for arch in ("i386", "x86_64"):
        required.extend(f"lib/wine/{arch}-windows/{name}" for name in
                        ("ntdll.dll", "mmdevapi.dll", "winecoreaudio.drv", "winebus.sys", "d3d11.dll", "d3d12.dll"))
    for name in required:
        if not (root / name).is_file():
            errors.append(f"Missing required file: {name}")
        elif "-windows/" in name:
            data = (root / name).read_bytes()
            offset = struct.unpack_from("<I", data, 60)[0] if len(data) >= 64 else len(data)
            expected = 0x014c if "/i386-windows/" in name else 0x8664
            if (data[:2] != b"MZ" or offset + 6 > len(data) or data[offset:offset + 4] != b"PE\0\0"
                    or struct.unpack_from("<H", data, offset + 4)[0] != expected):
                errors.append(f"Invalid PE format or architecture: {name}")
    for name in ("wine", "wineserver"):
        if not os.access(root / "bin" / name, os.X_OK):
            errors.append(f"Not executable: bin/{name}")
    lock_path = root / "source.lock.json"
    if lock_path.is_file():
        lock = json.loads(lock_path.read_text())
        for name in lock["indiePatches"]:
            patch = root / "source-patches/wine11" / name
            if not patch.is_file() or hashlib.sha256(patch.read_bytes()).hexdigest() != lock["indiePatchSHA256"][name]:
                errors.append(f"Missing or hash-mismatched source patch: {name}")
    binaries = []
    dependencies = set()
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            if not path.exists() or not path.resolve().is_relative_to(root):
                errors.append(f"Broken or external symlink: {path.relative_to(root)}")
            continue
        if not path.is_file() or path.suffix == ".a":
            continue
        with path.open("rb") as stream:
            magic = stream.read(4)
        if magic not in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"):
            continue
        relative = str(path.relative_to(root))
        binaries.append(relative)
        if output("lipo", "-archs", str(path)) != "x86_64":
            errors.append(f"Unexpected host architecture: {relative}")
        install_ids = output("otool", "-D", str(path)).splitlines()[1:]
        rpaths = re.findall(r"cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset", output("otool", "-l", str(path)))
        search_roots = [root / "lib"]
        for rpath in rpaths:
            if rpath.startswith("@loader_path"):
                search_roots.append(path.parent / rpath.removeprefix("@loader_path").lstrip("/"))
            elif rpath.startswith("@executable_path"):
                search_roots.append(root / "bin" / rpath.removeprefix("@executable_path").lstrip("/"))
            elif rpath.startswith("/"):
                errors.append(f"Absolute runtime search path in {relative}: {rpath}")
        for line in output("otool", "-L", str(path)).splitlines()[1:]:
            dependency = line.strip().split(" (compatibility version", 1)[0]
            # A dylib's install ID is also printed by otool -L.
            if dependency in install_ids:
                continue
            dependencies.add(dependency)
            if dependency.startswith(("/usr/lib/", "/System/Library/")):
                continue
            if dependency.startswith("@rpath/"):
                candidates = [directory / dependency.removeprefix("@rpath/") for directory in search_roots]
                candidate = next((item for item in candidates if item.is_file()), candidates[0])
            elif dependency.startswith("@loader_path/"):
                candidate = path.parent / dependency.removeprefix("@loader_path/")
            elif dependency.startswith("@executable_path/"):
                candidate = root / "bin" / dependency.removeprefix("@executable_path/")
            else:
                errors.append(f"External build dependency in {relative}: {dependency}")
                continue
            if not candidate.is_file() or not candidate.resolve().is_relative_to(root):
                errors.append(f"Unresolved dependency in {relative}: {dependency}")
    for name in required:
        if (name.startswith("bin/") or name.endswith((".so", ".dylib"))) and (root / name).is_file():
            resolved = (root / name).resolve()
            if resolved.is_relative_to(root) and str(resolved.relative_to(root)) not in binaries:
                errors.append(f"Required host file is not Mach-O: {name}")
    ntdll = root / "lib/wine/x86_64-unix/ntdll.so"
    if str(ntdll.relative_to(root)) in binaries and "_pipe2" in output("nm", "-u", str(ntdll)).split():
        errors.append("ntdll imports macOS 27-only pipe2 despite the macOS 15 deployment target")
    version = (root / "runtime-version.txt").read_text().strip() if (root / "runtime-version.txt").is_file() else None
    return {"runtimeVersion": version, "machOCount": len(binaries),
            "dependencies": sorted(dependencies), "errors": errors, "passed": not errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime", type=Path)
    args = parser.parse_args()
    root = args.runtime.resolve()
    if not root.is_dir():
        parser.error("runtime must be an extracted wine-runtime directory")
    report = audit(root)
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
