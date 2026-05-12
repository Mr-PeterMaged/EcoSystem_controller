"""Build only the Flutter APK.

Saves the APK to:
    <project_root>\\apk_builds\\EcoSystem_Controller_release_apk-N.apk

Each run auto-increments N (1, 2, 3, ...) based on existing files in that folder.

Usage:
    python build_only.py           # release APK
    python build_only.py --debug   # debug APK
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


# Always resolves to the project folder regardless of where the script is run from.
PROJECT_ROOT = Path(__file__).resolve().parent
OUTPUT_DIR   = PROJECT_ROOT / "apk_builds"

APK_PREFIX = "EcoSystem_Controller"


class BuildError(RuntimeError):
    pass


def resolve_flutter_command() -> list[str]:
    flutter_path = shutil.which("flutter")
    if flutter_path is None:
        raise BuildError(
            "Flutter was not found in PATH. Open a terminal where `flutter doctor` "
            "works, then run this script again."
        )
    if os.name == "nt" and flutter_path.lower().endswith((".bat", ".cmd")):
        return ["cmd", "/c", flutter_path]
    return [flutter_path]


def run(command: list[str]) -> None:
    print(f"\n> {' '.join(command)}")
    subprocess.run(command, cwd=PROJECT_ROOT, check=True)


def next_apk_number(mode: str) -> int:
    """Return the next sequential number for the APK filename."""
    if not OUTPUT_DIR.exists():
        return 1

    pattern = re.compile(
        rf"^{re.escape(APK_PREFIX)}_{re.escape(mode)}_apk-(\d+)\.apk$"
    )
    numbers = [
        int(m.group(1))
        for f in OUTPUT_DIR.glob(f"{APK_PREFIX}_{mode}_apk-*.apk")
        if (m := pattern.match(f.name))
    ]
    return max(numbers, default=0) + 1


def build_apk(debug: bool = False) -> Path:
    flutter = resolve_flutter_command()
    mode = "debug" if debug else "release"

    run([*flutter, "pub", "get"])
    run([*flutter, "build", "apk", f"--{mode}"])

    source_apk = (
        PROJECT_ROOT / "build" / "app" / "outputs" / "flutter-apk" / f"app-{mode}.apk"
    )
    if not source_apk.exists():
        raise BuildError(f"APK was not created: {source_apk}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    number = next_apk_number(mode)
    dest = OUTPUT_DIR / f"{APK_PREFIX}_{mode}_apk-{number}.apk"
    shutil.copy2(source_apk, dest)
    return dest


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build the Flutter APK and save it to apk_builds/ with an auto-incremented number."
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Build a debug APK instead of a release APK.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    print(f"Save folder : {OUTPUT_DIR}")
    try:
        apk_path = build_apk(debug=args.debug)
    except (BuildError, subprocess.CalledProcessError) as exc:
        print(f"\nBuild failed: {exc}", file=sys.stderr)
        return 1

    size_mb = apk_path.stat().st_size / (1024 * 1024)
    print(f"\nAPK ready  : {apk_path}")
    print(f"Size       : {size_mb:.2f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
