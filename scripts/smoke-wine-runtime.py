#!/usr/bin/env python3
"""Run packaged Wine probes in a new disposable prefix and retain evidence."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--mmdevapi-tests", type=Path, help="directory with i386-windows and x86_64-windows mmdevapi_test.exe")
    args = parser.parse_args()
    runtime = args.runtime.resolve()
    evidence = args.output.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    fixtures = Path(__file__).resolve().parent.parent / ".build/windows-fixtures"
    results = []
    env = os.environ.copy()
    for key in tuple(env):
        if key.startswith(("WINE", "SWITCHYARD_SPATIAL_AUDIO_", "DYLD_")):
            env.pop(key)
    env.update(DYLD_LIBRARY_PATH=str(runtime / "lib"), WINEARCH="wow64", WINEDEBUG="-all",
               WINEDLLOVERRIDES="mscoree,mshtml,winemenubuilder.exe=d")

    def run(name, command, timeout=180, controller=False, wine_test=False):
        started = time.monotonic()
        try:
            process = subprocess.run(command, env=env, capture_output=True, timeout=timeout)
            log = (process.stdout + process.stderr).decode(errors="replace")
            code = process.returncode
        except subprocess.TimeoutExpired as error:
            log = ((error.stdout or b"") + (error.stderr or b"")).decode(errors="replace")
            code = "timeout"
        summaries = re.findall(r"[^\n]*tests executed[^\n]*", log)
        passed = code == 0
        if wine_test:
            passed = passed and bool(summaries) and not re.search(r"\b[1-9]\d* failures?\b", "\n".join(summaries))
            # A skipped spatial test cannot establish rendering support.
            if name.endswith("spatialaudio"):
                passed = passed and not re.search(r"\b[1-9]\d* skipped\b", "\n".join(summaries))
        state = "passed" if passed else "failed"
        if controller and code == 2:
            state = "no-controller-connected"
        (evidence / f"{name}.log").write_text(log)
        item = {"name": name, "exit": code, "status": state,
                "seconds": round(time.monotonic() - started, 2), "summaries": summaries}
        results.append(item)
        (evidence / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        print(json.dumps(item), flush=True)
        return passed

    with tempfile.TemporaryDirectory(prefix="mgu-packaged-smoke-") as prefix:
        env["WINEPREFIX"] = prefix
        wine = str(runtime / "bin/wine")
        server = str(runtime / "bin/wineserver")
        try:
            if not run("wineboot", [wine, "wineboot", "--init"]):
                return 1
            run("cmd-x64", [wine, "cmd", "/c", "echo MGU_PACKAGED_RUNTIME_OK"])
            run("cmd-x86", [wine, str(Path(prefix) / "drive_c/windows/syswow64/cmd.exe"), "/c", "echo MGU_PACKAGED_RUNTIME_OK"])
            for name in ("indie-smoke-x64", "indie-smoke-x86", "indie-d3d11-fixture"):
                run(name, [wine, str(fixtures / f"{name}.exe"), "--smoke"], timeout=60)
            run("xinput", [wine, str(fixtures / "indie-xinput-probe.exe")], timeout=30, controller=True)
            if args.mmdevapi_tests:
                for arch, tests in (("x86_64", ("spatialaudio", "render", "mmdevenum", "propstore")),
                                    ("i386", ("spatialaudio",))):
                    for test in tests:
                        run(f"{arch}-{test}", [wine, str(args.mmdevapi_tests.resolve() / f"{arch}-windows/mmdevapi_test.exe"), test], wine_test=True)
        finally:
            subprocess.run([server, "-k"], env=env, capture_output=True, timeout=15)
            subprocess.run([server, "-w"], env=env, capture_output=True, timeout=15)
    return 1 if any(item["status"] == "failed" for item in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
