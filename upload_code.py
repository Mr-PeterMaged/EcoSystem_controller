from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from github_repos import (
    CODE_REPO_URL,
    DEFAULT_BRANCH,
    DEFAULT_REMOTE,
    PROJECT_ROOT,
)


class SourceUploadError(RuntimeError):
    pass


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
        raise SourceUploadError(
            "Git is not installed or is not available in PATH."
        ) from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        if detail:
            detail = f"\n{detail}"
        raise SourceUploadError(
            f"Git command failed: {subprocess.list2cmdline(command)}{detail}"
        ) from exc


def is_git_repo(root: Path) -> bool:
    result = run_git(
        ["rev-parse", "--is-inside-work-tree"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    return result.returncode == 0 and result.stdout.strip() == "true"


def current_branch(root: Path, fallback: str) -> str:
    result = run_git(
        ["branch", "--show-current"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    branch = result.stdout.strip()
    if branch:
        return branch

    run_git(["checkout", "-B", fallback], cwd=root)
    return fallback


def ensure_source_remote(
    root: Path,
    *,
    remote: str,
    repo_url: str,
) -> None:
    result = run_git(
        ["remote", "get-url", remote],
        cwd=root,
        check=False,
        capture_output=True,
    )
    current_url = result.stdout.strip()
    if result.returncode != 0:
        run_git(["remote", "add", remote, repo_url], cwd=root)
        return

    if current_url != repo_url:
        run_git(["remote", "set-url", remote, repo_url], cwd=root)


def has_staged_changes(root: Path) -> bool:
    result = run_git(["diff", "--cached", "--quiet"], cwd=root, check=False)
    if result.returncode == 0:
        return False
    if result.returncode == 1:
        return True
    raise SourceUploadError("Could not inspect staged source-code changes.")


def remote_branch_exists(root: Path, *, remote: str, branch: str) -> bool:
    result = run_git(
        ["ls-remote", "--exit-code", "--heads", remote, branch],
        cwd=root,
        check=False,
        capture_output=True,
    )
    if result.returncode == 0:
        return True
    if result.returncode == 2:
        return False
    raise SourceUploadError(f"Could not check remote branch {remote}/{branch}.")


def fetch_remote_branch(root: Path, *, remote: str, branch: str) -> None:
    run_git(["fetch", remote, branch], cwd=root)


def has_shared_history(root: Path, *, remote: str, branch: str) -> bool:
    result = run_git(
        ["merge-base", "HEAD", f"{remote}/{branch}"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    return result.returncode == 0


def sync_remote_branch(root: Path, *, remote: str, branch: str) -> None:
    if not remote_branch_exists(root, remote=remote, branch=branch):
        print(f"Remote branch {remote}/{branch} does not exist yet.")
        return

    fetch_remote_branch(root, remote=remote, branch=branch)
    if not has_shared_history(root, remote=remote, branch=branch):
        print(
            f"Local history is separate from {remote}/{branch}; "
            "rebasing the current file tree onto the GitHub branch."
        )
        run_git(["reset", "--soft", f"{remote}/{branch}"], cwd=root)
        return

    result = run_git(
        ["pull", "--rebase", "--autostash", remote, branch],
        cwd=root,
        check=False,
    )
    if result.returncode == 0:
        return

    raise SourceUploadError(
        f"Could not sync with {remote}/{branch}. Resolve the Git conflict, "
        "then run upload_code.py again."
    )


def upload_source_code(
    *,
    root: Path = PROJECT_ROOT,
    repo_url: str = CODE_REPO_URL,
    remote: str = DEFAULT_REMOTE,
    branch: str = DEFAULT_BRANCH,
    message: str | None = None,
) -> None:
    root = root.resolve()
    if not root.exists() or not root.is_dir():
        raise SourceUploadError(f"Project folder not found: {root}")

    if not is_git_repo(root):
        run_git(["init"], cwd=root)

    ensure_source_remote(root, remote=remote, repo_url=repo_url)
    active_branch = current_branch(root, branch)
    sync_remote_branch(root, remote=remote, branch=active_branch)
    commit_message = (
        message or f"Update source code - {datetime.now():%Y-%m-%d %H:%M:%S}"
    )

    run_git(["add", "--all", "--", "."], cwd=root)
    if has_staged_changes(root):
        run_git(["commit", "-m", commit_message], cwd=root)
    else:
        print("No source-code changes to commit.")

    run_git(["push", "-u", remote, active_branch], cwd=root)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Commit and push the project source code to GitHub."
    )
    parser.add_argument(
        "--root",
        default=str(PROJECT_ROOT),
        help=f"Project folder. Default: {PROJECT_ROOT}",
    )
    parser.add_argument(
        "--repo-url",
        default=CODE_REPO_URL,
        help=f"Source-code repository URL. Default: {CODE_REPO_URL}",
    )
    parser.add_argument(
        "--remote",
        default=DEFAULT_REMOTE,
        help=f"Git remote name. Default: {DEFAULT_REMOTE}",
    )
    parser.add_argument(
        "--branch",
        default=DEFAULT_BRANCH,
        help=f"Fallback branch name. Default: {DEFAULT_BRANCH}",
    )
    parser.add_argument(
        "--message",
        help="Commit message. Default: timestamped source-code update.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        upload_source_code(
            root=Path(args.root),
            repo_url=args.repo_url,
            remote=args.remote,
            branch=args.branch,
            message=args.message,
        )
    except SourceUploadError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(f"Source code repository: {args.repo_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
