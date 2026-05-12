from __future__ import annotations

import argparse
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from github_repos import (
    APK_REPO_DIR,
    CODE_REPO_URL,
    DEFAULT_BRANCH,
    DEFAULT_REMOTE,
)


DEFAULT_MESSAGE = "Upload source code files"
GITHUB_REGULAR_FILE_LIMIT = 100 * 1024 * 1024


class UploadAllError(RuntimeError):
    pass


def run(
    args: list[str],
    *,
    cwd: Path,
    check: bool = True,
    capture_output: bool = False,
) -> subprocess.CompletedProcess[str]:
    print(f"[{cwd}] $ {subprocess.list2cmdline(args)}")
    try:
        return subprocess.run(
            args,
            cwd=cwd,
            check=check,
            text=True,
            capture_output=capture_output,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as exc:
        raise UploadAllError("Git is not installed or is not available in PATH.") from exc
    except subprocess.CalledProcessError as exc:
        details = (exc.stderr or exc.stdout or "").strip()
        if details:
            details = f"\n{details}"
        raise UploadAllError(
            f"Command failed: {subprocess.list2cmdline(args)}{details}"
        ) from exc


def is_git_repo(path: Path) -> bool:
    result = run(
        ["git", "rev-parse", "--is-inside-work-tree"],
        cwd=path,
        check=False,
        capture_output=True,
    )
    return result.returncode == 0 and result.stdout.strip() == "true"


def discover_git_repos(root: Path) -> list[Path]:
    repos = {root.resolve()}
    skipped_repos = {APK_REPO_DIR.resolve()}

    for git_path in root.rglob(".git"):
        if not git_path.exists():
            continue
        repo_dir = git_path.parent.resolve()
        if repo_dir == root.resolve() or repo_dir in skipped_repos:
            continue
        repos.add(repo_dir)

    return sorted(repos, key=lambda path: len(path.relative_to(root).parts), reverse=True)


def path_is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def current_branch(repo: Path, fallback: str) -> str:
    result = run(
        ["git", "branch", "--show-current"],
        cwd=repo,
        check=False,
        capture_output=True,
    )
    branch = result.stdout.strip()
    if branch:
        return branch

    run(["git", "checkout", "-B", fallback], cwd=repo)
    return fallback


def get_remote_url(repo: Path, remote: str) -> str | None:
    result = run(
        ["git", "remote", "get-url", remote],
        cwd=repo,
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def read_repo_url(repo: Path) -> str | None:
    repo_url_file = repo / "repo_url.txt"
    if not repo_url_file.exists():
        return None
    return repo_url_file.read_text(encoding="utf-8", errors="replace").strip() or None


def ensure_remote(repo: Path, remote: str, repo_url: str | None = None) -> None:
    current_url = get_remote_url(repo, remote)
    if current_url:
        if repo_url and current_url != repo_url:
            run(["git", "remote", "set-url", remote, repo_url], cwd=repo)
        return

    if repo_url:
        run(["git", "remote", "add", remote, repo_url], cwd=repo)
        return

    saved_repo_url = read_repo_url(repo)
    if not saved_repo_url:
        raise UploadAllError(
            f"No '{remote}' remote is configured for {repo}, and repo_url.txt was not found."
        )

    run(["git", "remote", "add", remote, saved_repo_url], cwd=repo)


def has_staged_changes(repo: Path) -> bool:
    result = run(["git", "diff", "--cached", "--quiet"], cwd=repo, check=False)
    if result.returncode == 0:
        return False
    if result.returncode == 1:
        return True
    raise UploadAllError(f"Could not inspect staged changes in {repo}.")


def git_lfs_available(repo: Path) -> bool:
    result = run(["git", "lfs", "version"], cwd=repo, check=False, capture_output=True)
    return result.returncode == 0


def iter_repo_files(repo: Path, child_repos: list[Path]) -> list[Path]:
    skip_dirs = {repo / ".git", *child_repos}
    files: list[Path] = []

    for dirpath_text, dirnames, filenames in os.walk(repo):
        dirpath = Path(dirpath_text).resolve()
        kept_dirnames: list[str] = []

        for dirname in dirnames:
            child = (dirpath / dirname).resolve()
            if child in skip_dirs:
                continue
            kept_dirnames.append(dirname)

        dirnames[:] = kept_dirnames

        for filename in filenames:
            files.append(dirpath / filename)

    return files


def large_files(repo: Path, child_repos: list[Path]) -> list[Path]:
    oversized: list[Path] = []
    for path in iter_repo_files(repo, child_repos):
        try:
            if path.stat().st_size >= GITHUB_REGULAR_FILE_LIMIT:
                oversized.append(path)
        except OSError:
            continue
    return oversized


def track_large_files_with_lfs(repo: Path, child_repos: list[Path]) -> None:
    oversized = large_files(repo, child_repos)
    if not oversized:
        return

    if not git_lfs_available(repo):
        examples = "\n".join(f"- {path}" for path in oversized[:10])
        raise UploadAllError(
            "GitHub rejects regular Git files around 100 MB or larger, and Git LFS "
            f"is not available for {repo}.\nInstall Git LFS, or rerun with --no-lfs "
            f"if you still want regular Git to try.\n{examples}"
        )

    print(f"Found {len(oversized)} large file(s). Tracking them with Git LFS.")
    run(["git", "lfs", "install"], cwd=repo)
    for path in oversized:
        relative_path = path.relative_to(repo).as_posix()
        run(["git", "lfs", "track", "--filename", relative_path], cwd=repo)


def stage_everything(repo: Path, *, force_ignored: bool = False) -> None:
    # -A stages additions, modifications, and deletions.
    # -f additionally overrides .gitignore — only used when explicitly requested.
    cmd = ["git", "add", "-A"]
    if force_ignored:
        cmd.append("-f")
    cmd += ["--", "."]
    run(cmd, cwd=repo)


def commit_if_needed(repo: Path, message: str) -> bool:
    if not has_staged_changes(repo):
        print(f"No changes to commit in {repo}.")
        return False

    run(["git", "commit", "-m", message], cwd=repo)
    return True


def push_repo(
    repo: Path,
    *,
    remote: str,
    branch: str,
    message: str,
    child_repos: list[Path],
    use_lfs: bool,
    repo_url: str | None = None,
    force_ignored: bool = False,
) -> None:
    ensure_remote(repo, remote, repo_url=repo_url)
    active_branch = current_branch(repo, branch)

    print("\n" + "=" * 72)
    print(f"Uploading every Git-trackable file in: {repo}")
    print("=" * 72)

    if use_lfs:
        track_large_files_with_lfs(repo, child_repos)

    stage_everything(repo, force_ignored=force_ignored)
    committed = commit_if_needed(repo, message)
    if not committed:
        print(f"Pushing anyway to make sure {remote}/{active_branch} is up to date.")

    run(["git", "push", "-u", remote, active_branch], cwd=repo)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Commit and push Git-trackable source files in this folder. "
            "Ignored files stay ignored unless --force-ignored is passed."
        )
    )
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parent),
        help="Folder to upload. Default: the folder containing this script.",
    )
    parser.add_argument(
        "--message",
        default=f"{DEFAULT_MESSAGE} - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        help="Commit message to use when changes exist.",
    )
    parser.add_argument(
        "--remote",
        default=DEFAULT_REMOTE,
        help=f"Git remote name. Default: {DEFAULT_REMOTE}.",
    )
    parser.add_argument(
        "--branch",
        default=DEFAULT_BRANCH,
        help=f"Fallback branch name if the repo has no active branch. Default: {DEFAULT_BRANCH}.",
    )
    parser.add_argument(
        "--repo-url",
        default=CODE_REPO_URL,
        help=f"Source-code repository URL for the root repo. Default: {CODE_REPO_URL}.",
    )
    parser.add_argument(
        "--no-recursive-repos",
        action="store_true",
        help="Only upload the root repo and skip nested Git repositories.",
    )
    parser.add_argument(
        "--no-lfs",
        action="store_true",
        help="Do not auto-track files >= 100 MB with Git LFS.",
    )
    parser.add_argument(
        "--force-ignored",
        action="store_true",
        help=(
            "Pass -f to git add, forcing .gitignore rules to be bypassed. "
            "DANGER: this will stage secrets, credentials, and build caches. "
            "Only use this when you explicitly want to commit ignored files."
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = Path(args.root).expanduser().resolve()

    if not root.exists():
        print(f"Error: folder does not exist: {root}", file=sys.stderr)
        return 1
    if not root.is_dir():
        print(f"Error: root is not a folder: {root}", file=sys.stderr)
        return 1
    if not is_git_repo(root):
        print(f"Error: folder is not a Git repository: {root}", file=sys.stderr)
        return 1

    if args.force_ignored:
        print("WARNING: --force-ignored is set. .gitignore rules will be bypassed.")
        print("This can commit secrets, credentials, caches, and build outputs.")
        print("Git's own .git directories cannot be committed as normal files by design.\n")
    else:
        print("Staging all tracked and untracked files (respecting .gitignore).")
        print("Pass --force-ignored to also stage gitignored files.\n")

    repos = [root] if args.no_recursive_repos else discover_git_repos(root)
    for repo in repos:
        child_repos = [
            child
            for child in repos
            if child != repo and path_is_relative_to(child, repo)
        ]
        push_repo(
            repo,
            remote=args.remote,
            branch=args.branch,
            message=args.message,
            child_repos=child_repos,
            use_lfs=not args.no_lfs,
            repo_url=args.repo_url if repo == root else None,
            force_ignored=args.force_ignored,
        )

    print("\nDone. Every discovered Git repository was pushed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
