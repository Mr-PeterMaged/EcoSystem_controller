"""Build only the Flutter APK.

Run from the project root:

    python build_only.py

Optional:

    python build_only.py --debug
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
OUTPUT_DIR = PROJECT_ROOT / "apk_builds"


class BuildError(RuntimeError):
    """Raised when the APK build cannot finish."""


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
    if not OUTPUT_DIR.exists():
        return 1

    pattern = re.compile(rf"^EcoSystem_Controller_{re.escape(mode)}_apk-(\d+)\.apk$")
    numbers: list[int] = []
    for apk_file in OUTPUT_DIR.glob(f"EcoSystem_Controller_{mode}_apk-*.apk"):
        match = pattern.match(apk_file.name)
        if match:
            numbers.append(int(match.group(1)))

    return max(numbers, default=0) + 1


def build_apk(debug: bool = False) -> Path:
    flutter = resolve_flutter_command()
    mode = "debug" if debug else "release"

    run([*flutter, "pub", "get"])
    run([*flutter, "build", "apk", f"--{mode}"])

    source_apk = (
        PROJECT_ROOT
        / "build"
        / "app"
        / "outputs"
        / "flutter-apk"
        / f"app-{mode}.apk"
    )
    if not source_apk.exists():
        raise BuildError(f"APK was not created: {source_apk}")

    OUTPUT_DIR.mkdir(exist_ok=True)
    apk_number = next_apk_number(mode)
    output_apk = OUTPUT_DIR / f"EcoSystem_Controller_{mode}_apk-{apk_number}.apk"
    shutil.copy2(source_apk, output_apk)

    return output_apk


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build only the Flutter APK.")
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Build a debug APK instead of a release APK.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        apk_path = build_apk(debug=args.debug)
    except (BuildError, subprocess.CalledProcessError) as exc:
        print(f"\nBuild failed: {exc}", file=sys.stderr)
        return 1

    print(f"\nAPK ready: {apk_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
