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
    APK_REPO_NAME,
    APP_DISPLAY_NAME,
    DEFAULT_BRANCH,
    GITHUB_OWNER,
    PROJECT_ROOT,
)


APK_BUILDS_DIR = PROJECT_ROOT / "apk_builds"
QR_FILENAME    = "download_qr.png"


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


def raw_url(filename: str, branch: str) -> str:
    """Public raw download URL for a file in the APK repository."""
    return (
        f"https://raw.githubusercontent.com"
        f"/{GITHUB_OWNER}/{APK_REPO_NAME}/{branch}/{filename}"
    )


def generate_qr(download_url: str, output_path: Path) -> None:
    """Create a green QR code PNG pointing to download_url."""
    try:
        import qrcode
    except ImportError as exc:
        raise UploadError(
            "qrcode is required. Run: pip install qrcode[pil]"
        ) from exc

    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=12,
        border=4,
    )
    qr.add_data(download_url)
    qr.make(fit=True)
    image = qr.make_image(fill_color="#16A34A", back_color="white")
    image.save(str(output_path))
    print(f"QR code saved: {output_path.name}")


def remove_old_public_apks(repo_dir: Path) -> None:
    for apk_path in repo_dir.rglob("*.apk"):
        if ".git" in apk_path.parts:
            continue
        apk_path.unlink()


def write_release_readme(
    repo_dir: Path,
    apk_name: str,
    version: str,
    branch: str,
) -> None:
    version_text  = version or "latest"
    apk_url       = raw_url(apk_name, branch)
    qr_url        = raw_url(QR_FILENAME, branch)
    timestamp     = datetime.now().astimezone().isoformat(timespec="seconds")

    content = "\n".join([
        f"# {APP_DISPLAY_NAME}",
        "",
        "---",
        "",
        "## Scan and Download Now",
        "",
        f"<p align=\"center\">",
        f"  <img src=\"{qr_url}\" alt=\"Scan to Download\" width=\"260\"/>",
        f"</p>",
        "",
        f"<p align=\"center\">",
        f"  <a href=\"{apk_url}\"><b>Direct Download</b></a>",
        f"</p>",
        "",
        "---",
        "",
        f"- **Latest APK:** `{apk_name}`",
        f"- **Version:** `{version_text}`",
        f"- **Updated:** `{timestamp}`",
        "",
        "This repository contains only the latest public APK build.",
        "",
    ])

    (repo_dir / "README.md").write_text(content, encoding="utf-8")
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
    repo_dir    = ensure_apk_repo(branch=branch)
    destination = repo_dir / apk_path.name

    # Remove old APKs and stale QR code
    remove_old_public_apks(repo_dir)
    old_qr = repo_dir / QR_FILENAME
    if old_qr.exists():
        old_qr.unlink()

    # Copy new APK
    shutil.copy2(apk_path, destination)

    # Generate QR code pointing to the raw GitHub download URL
    apk_download_url = raw_url(apk_path.name, branch)
    generate_qr(apk_download_url, repo_dir / QR_FILENAME)

    # Write README with embedded QR image
    write_release_readme(repo_dir, apk_path.name, version, branch)

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
        description=(
            "Upload the highest-numbered APK from apk_builds/ to the public GitHub "
            "repository, generate a QR code, and embed it in README.md."
        )
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
        help="Also publish the APK to GitHub Releases via APK_GIT.py.",
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
        apk_url = raw_url(uploaded_path.name, args.branch)
        print(f"Uploaded : {uploaded_path.name}")
        print(f"QR code  : {raw_url(QR_FILENAME, args.branch)}")
        print(f"Download : {apk_url}")
        print(f"Repo dir : {APK_REPO_DIR}")

        if args.with_release:
            run_release_publish(apk_path, args.version)
    except (UploadError, GitHubSetupError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
