from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from github import GitHubSetupError, ensure_apk_repo
from github_repos import (
    APK_REPO_DIR,
    APP_DISPLAY_NAME,
    DEFAULT_BRANCH,
    PROJECT_ROOT,
)


APK_BUILDS_DIR = PROJECT_ROOT / "apk_builds"


class UploadError(RuntimeError):
    pass


def run_git(
    args: list[str],
    *,
    cwd: Path,
    check: bool = True,
    capture_output: bool = False,
) -> subprocess.CompletedProcess[str]:
    command = ["git", *args]
    print(f"$ {subprocess.list2cmdline(command)}")
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            check=check,
            text=True,
            capture_output=capture_output,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as exc:
        raise UploadError("Git is not installed or is not available in PATH.") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        if detail:
            detail = f"\n{detail}"
        raise UploadError(
            f"Git command failed: {subprocess.list2cmdline(command)}{detail}"
        ) from exc


def _apk_number(apk_path: Path) -> int:
    """Extract the trailing number from EcoSystem_Controller_*_apk-N.apk, or -1."""
    import re
    match = re.search(r"-(\d+)\.apk$", apk_path.name)
    return int(match.group(1)) if match else -1


def resolve_apk(apk_arg: str | None) -> Path:
    if apk_arg:
        apk_path = Path(apk_arg)
        if not apk_path.is_absolute():
            apk_path = PROJECT_ROOT / apk_path
        apk_path = apk_path.resolve()
        if not apk_path.exists():
            raise UploadError(f"APK file not found: {apk_path}")
        return apk_path

    apk_files = list(APK_BUILDS_DIR.glob("*.apk"))
    if not apk_files:
        raise UploadError(f"No APK files found in {APK_BUILDS_DIR}")

    latest = max(apk_files, key=_apk_number)
    print(f"Latest APK : {latest.name}  (number {_apk_number(latest)})")
    return latest.resolve()


def remove_old_public_apks(repo_dir: Path) -> None:
    for apk_path in repo_dir.rglob("*.apk"):
        if ".git" in apk_path.parts:
            continue
        apk_path.unlink()


def write_release_readme(repo_dir: Path, public_apk_name: str, version: str) -> None:
    version_text = version or "latest"
    readme = repo_dir / "README.md"
    readme.write_text(
        "\n".join(
            [
                f"# {APP_DISPLAY_NAME}",
                "",
                "Public APK download repository.",
                "",
                f"- Latest APK: `{public_apk_name}`",
                f"- Version: `{version_text}`",
                f"- Updated: `{datetime.now().astimezone().isoformat(timespec='seconds')}`",
                "",
                "This repository contains only the latest public APK build.",
                "",
            ]
        ),
        encoding="utf-8",
    )
    (repo_dir / "VERSION.txt").write_text(f"{version_text}\n", encoding="utf-8")


def has_staged_changes(repo_dir: Path) -> bool:
    result = run_git(["diff", "--cached", "--quiet"], cwd=repo_dir, check=False)
    if result.returncode == 0:
        return False
    if result.returncode == 1:
        return True
    raise UploadError("Could not inspect staged APK repository changes.")


def upload_latest_apk(
    *,
    apk_path: Path,
    version: str,
    branch: str,
) -> Path:
    repo_dir = ensure_apk_repo(branch=branch)

    # Keep the original filename (e.g. EcoSystem_Controller_release_apk-5.apk)
    # so the version number is visible in the GitHub repository.
    destination = repo_dir / apk_path.name

    remove_old_public_apks(repo_dir)
    shutil.copy2(apk_path, destination)
    write_release_readme(repo_dir, apk_path.name, version)

    run_git(["add", "--all"], cwd=repo_dir)
    if has_staged_changes(repo_dir):
        message_version = version or "latest"
        run_git(
            ["commit", "-m", f"Release {APP_DISPLAY_NAME} {message_version}"],
            cwd=repo_dir,
        )
    else:
        print("No APK repository changes to commit.")

    run_git(["push", "-u", "origin", branch], cwd=repo_dir)
    return destination


def run_release_publish(apk_path: Path, version: str) -> None:
    apk_git_py = PROJECT_ROOT / "APK_GIT.py"
    if not apk_git_py.exists():
        print("APK_GIT.py not found - skipping GitHub Release step.")
        return

    command = [sys.executable, str(apk_git_py), "--apk", str(apk_path)]
    if version:
        command.extend(["--version", version])

    print("\n" + "-" * 50)
    print("Publishing to GitHub Releases ...")
    print("-" * 50)
    result = subprocess.run(command, cwd=PROJECT_ROOT, check=False)
    if result.returncode != 0:
        raise UploadError(f"APK_GIT.py failed with exit code {result.returncode}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Upload the highest-numbered APK from apk_builds/ to the public GitHub repository."
    )
    parser.add_argument(
        "--apk",
        help="APK file to upload. Default: highest-numbered .apk in apk_builds/.",
    )
    parser.add_argument(
        "--version",
        default="",
        help="Version text written to VERSION.txt and the release commit.",
    )
    parser.add_argument(
        "--branch",
        default=DEFAULT_BRANCH,
        help=f"APK repository branch. Default: {DEFAULT_BRANCH}",
    )
    parser.add_argument(
        "--with-release",
        action="store_true",
        help="Also publish the APK to GitHub Releases and generate a QR code.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        apk_path = resolve_apk(args.apk)
        uploaded_path = upload_latest_apk(
            apk_path=apk_path,
            version=args.version,
            branch=args.branch,
        )
        print(f"Uploaded : {uploaded_path.name}")
        print(f"Repo dir : {APK_REPO_DIR}")

        if args.with_release:
            run_release_publish(apk_path, args.version)
    except (UploadError, GitHubSetupError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
