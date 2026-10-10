#!/usr/bin/env python3
"""Record the actual host/toolchain independently of the reference source lock."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True).strip()


root = Path(__file__).resolve().parent.parent
payload = Path(sys.argv[1])
info = {
    "schemaVersion": 1,
    "repositoryRevision": run("git", "-C", str(root), "rev-parse", "HEAD"),
    "trackedDiffSHA256": hashlib.sha256(subprocess.check_output(
        ["git", "-C", str(root), "diff", "HEAD", "--", "."])).hexdigest(),
    "buildScriptSHA256": {name: hashlib.sha256((root / "scripts" / name).read_bytes()).hexdigest()
                          for name in ("build-indie-wine11.sh", "apply-wine11-patches.py",
                                       "record-wine-build.py", "verify-wine-runtime.py")},
    "sourceLockSHA256": hashlib.sha256((payload / "source.lock.json").read_bytes()).hexdigest(),
    "macOS": run("sw_vers", "-productVersion"),
    "macOSBuild": run("sw_vers", "-buildVersion"),
    "xcode": run("xcodebuild", "-version"),
    "sdk": run("xcrun", "--show-sdk-version"),
    "hostCompiler": run("/usr/bin/clang", "--version"),
    "peCompilers": {arch: run(f"{arch}-w64-mingw32-gcc", "--version")
                    for arch in ("i686", "x86_64")},
    "cmake": run("cmake", "--version"),
    "deploymentTarget": os.environ.get("MACOSX_DEPLOYMENT_TARGET", "15.0"),
    "sourceDateEpoch": os.environ.get("SOURCE_DATE_EPOCH", "1768262400"),
    "hostArchitecture": "x86_64",
    "peArchitectures": ["i386", "x86_64"],
    "configureOverrides": {"ac_cv_func_pipe2": "no"},
    "referenceToolchainReproduction": False,
}
(payload / "build-info.json").write_text(json.dumps(info, indent=2) + "\n")
