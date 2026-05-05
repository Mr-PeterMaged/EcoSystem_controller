from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from git_utils import GitError, ensure_git_available


PROJECT_ROOT = Path(__file__).resolve().parent
APK_REPO_URL = "https://github.com/Mr-PeterMaged/EcoSystem_controller_APK.git"
APK_REPO_DIR = PROJECT_ROOT / ".apk_release_repo"
DEFAULT_BRANCH = "main"


# Alias so callers (upload.py) can catch the same name regardless of source.
GitHubSetupError = GitError


def run_git(
    args: list[str],
    *,
    cwd: Path = PROJECT_ROOT,
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
        raise GitHubSetupError("Git is not installed or is not available in PATH.") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        if detail:
            detail = f"\n{detail}"
        raise GitHubSetupError(
            f"Git command failed: {subprocess.list2cmdline(command)}{detail}"
        ) from exc



def remote_branch_exists(repo_dir: Path, branch: str) -> bool:
    result = run_git(
        ["ls-remote", "--exit-code", "--heads", "origin", branch],
        cwd=repo_dir,
        check=False,
        capture_output=True,
    )
    if result.returncode == 0:
        return True
    if result.returncode == 2:
        return False
    raise GitHubSetupError("Could not check the APK repository remote branch.")


def ensure_branch(repo_dir: Path, branch: str) -> None:
    if remote_branch_exists(repo_dir, branch):
        run_git(["fetch", "origin", branch], cwd=repo_dir)
        run_git(["checkout", "-B", branch, f"origin/{branch}"], cwd=repo_dir)
    else:
        run_git(["checkout", "-B", branch], cwd=repo_dir)


def ensure_apk_repo(
    *,
    repo_url: str = APK_REPO_URL,
    repo_dir: Path = APK_REPO_DIR,
    branch: str = DEFAULT_BRANCH,
) -> Path:
    ensure_git_available()

    if repo_dir.exists() and not (repo_dir / ".git").exists():
        if any(repo_dir.iterdir()):
            raise GitHubSetupError(
                f"{repo_dir} exists but is not a Git repository. "
                "Move it or delete it, then run github.py again."
            )
        repo_dir.rmdir()

    if not repo_dir.exists():
        run_git(["clone", repo_url, str(repo_dir)], cwd=PROJECT_ROOT)
    else:
        current = run_git(
            ["remote", "get-url", "origin"],
            cwd=repo_dir,
            check=False,
            capture_output=True,
        )
        if current.returncode != 0:
            run_git(["remote", "add", "origin", repo_url], cwd=repo_dir)
        elif current.stdout.strip() != repo_url:
            run_git(["remote", "set-url", "origin", repo_url], cwd=repo_dir)

    ensure_branch(repo_dir, branch)
    return repo_dir


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Prepare the public APK-only GitHub repository."
    )
    parser.add_argument(
        "--repo-url",
        default=APK_REPO_URL,
        help=f"APK-only repository URL. Default: {APK_REPO_URL}",
    )
    parser.add_argument(
        "--repo-dir",
        default=str(APK_REPO_DIR),
        help=f"Local APK repository folder. Default: {APK_REPO_DIR}",
    )
    parser.add_argument(
        "--branch",
        default=DEFAULT_BRANCH,
        help=f"APK repository branch. Default: {DEFAULT_BRANCH}",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    repo_dir = Path(args.repo_dir)
    if not repo_dir.is_absolute():
        repo_dir = PROJECT_ROOT / repo_dir
    try:
        repo_dir = ensure_apk_repo(
            repo_url=args.repo_url,
            repo_dir=repo_dir,
            branch=args.branch,
        )
    except GitHubSetupError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(f"APK repository is ready: {repo_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
