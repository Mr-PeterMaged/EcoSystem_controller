from __future__ import annotations

import argparse
from pathlib import Path
import sys

from git_utils import (
    DEFAULT_BRANCH,
    DEFAULT_REMOTE,
    REMOTE_FILE,
    GitError,
    GitRunner,
    commit_if_needed,
    configure_remote,
    ensure_git_available,
    init_repository,
    pull_branch,
    push_branch,
    remote_branch_exists,
    rename_current_branch,
    resolve_repo_url,
    save_repo_url,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Initialize this folder as a Git repository and push it to GitHub."
    )
    parser.add_argument(
        "repo_url",
        nargs="?",
        help="GitHub repository URL. If omitted, repo_url.txt is used or you are prompted.",
    )
    parser.add_argument(
        "-m",
        "--message",
        default="Update project files",
        help="Commit message for local changes.",
    )
    parser.add_argument(
        "-b",
        "--branch",
        default=DEFAULT_BRANCH,
        help=f"Branch to push. Default: {DEFAULT_BRANCH}.",
    )
    parser.add_argument(
        "-r",
        "--remote",
        default=DEFAULT_REMOTE,
        help=f"Remote name. Default: {DEFAULT_REMOTE}.",
    )
    parser.add_argument(
        "--repo-file",
        default=str(REMOTE_FILE),
        help="File used to remember the repository URL.",
    )
    parser.add_argument(
        "--skip-pull",
        action="store_true",
        help="Skip pulling the remote branch before pushing.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    runner = GitRunner()
    repo_file = Path(args.repo_file)

    try:
        ensure_git_available()
        repo_url = resolve_repo_url(args.repo_url, repo_file)
        save_repo_url(repo_url, repo_file)

        init_repository(runner)
        rename_current_branch(runner, args.branch)
        commit_if_needed(runner, args.message)
        configure_remote(runner, repo_url, remote=args.remote)

        if args.skip_pull:
            print("Skipping remote pull.")
        elif remote_branch_exists(runner, remote=args.remote, branch=args.branch):
            pull_branch(runner, remote=args.remote, branch=args.branch)
        else:
            print(f"Remote branch '{args.remote}/{args.branch}' does not exist yet.")

        commit_if_needed(runner, args.message)
        push_branch(runner, remote=args.remote, branch=args.branch)
    except GitError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
