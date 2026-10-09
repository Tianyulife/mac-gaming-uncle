#!/usr/bin/env python3
"""Apply only the ordered, hash-locked MGU Wine patch set to a clean source tree."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    lock = json.loads((root / 'runtime/indie-wine11/source.lock.json').read_text())
    names = lock['indiePatches']
    hashes = lock['indiePatchSHA256']
    patch_root = root / 'patches/wine11'
    if not names or len(names) != len(set(names)):
        raise ValueError('Patch manifest is empty or contains duplicates')
    if any(Path(name).name != name or not name.endswith('.patch') for name in names):
        raise ValueError('Patch manifest must contain plain .patch filenames')
    if set(names) != {p.name for p in patch_root.glob('*.patch')} or set(hashes) != set(names):
        raise ValueError('Patch directory/hash list does not match source.lock.json')
    if not (args.source / 'configure').is_file():
        raise ValueError('Expected a freshly extracted Wine source directory')
    # Validate all inputs before the first mutation; fail before an unreviewed
    # patch can enter a build through a directory glob.
    for name in names:
        actual = hashlib.sha256((patch_root / name).read_bytes()).hexdigest()
        if actual != hashes[name]:
            raise ValueError(f'Patch SHA-256 mismatch: {name}')
    for name in names:
        print(f'Applying {name}', flush=True)
        with (patch_root / name).open('rb') as patch:
            subprocess.run(['patch', '--batch', '--forward', '--fuzz=0',
                            '-d', str(args.source), '-p1'], stdin=patch, check=True)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f'Wine patch application failed: {error}', file=sys.stderr)
        sys.exit(1)
