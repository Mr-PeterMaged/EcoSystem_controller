from __future__ import annotations

import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent

SCRIPTS = [
    "build_only.py",
    "upload_code.py",
    "APK_GIT.py",
    "upload.py",
]


def run_script(script_name: str) -> int:
    script_path = PROJECT_ROOT / script_name
    if not script_path.exists():
        print(f"File not found: {script_path}", file=sys.stderr)
        return 1

    command = [sys.executable, str(script_path)]
    print("\n" + "=" * 60)
    print(f"Running: {subprocess.list2cmdline(command)}")
    print("=" * 60)

    completed = subprocess.run(command, cwd=PROJECT_ROOT, check=False)
    return completed.returncode


def main() -> int:
    for script_name in SCRIPTS:
        exit_code = run_script(script_name)
        if exit_code != 0:
            print(
                f"\nStopped because {script_name} failed with exit code {exit_code}.",
                file=sys.stderr,
            )
            return exit_code

    print("\nAll scripts finished successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
