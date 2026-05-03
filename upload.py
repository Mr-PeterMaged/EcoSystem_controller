from __future__ import annotations

import argparse
import csv
from datetime import datetime
from pathlib import Path
import sys
from uuid import uuid4

from git_utils import (
    DEFAULT_BRANCH,
    DEFAULT_REMOTE,
    REMOTE_FILE,
    GitFileChange,
    GitError,
    GitRunner,
    changed_paths,
    collect_staged_changes,
    commit_staged_if_needed,
    current_branch,
    ensure_git_available,
    ensure_remote,
    is_git_repository,
    pull_branch,
    push_branch,
    remote_branch_exists,
    stage_all,
    stage_path,
)


DEFAULT_UPLOAD_LOG = Path("upload_history.csv")
LOG_FIELDS = [
    "upload_id",
    "timestamp",
    "date",
    "time",
    "timezone",
    "utc_offset",
    "branch",
    "remote",
    "commit_message",
    "pull_first",
    "total_files",
    "total_additions",
    "total_deletions",
    "file_path",
    "old_path",
    "change_type",
    "git_status",
    "additions",
    "deletions",
    "is_binary",
    "script",
]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Commit local changes and push them to the configured Git remote."
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
        help=f"Branch to push. Default: current branch, then {DEFAULT_BRANCH}.",
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
        help="File used to read the saved repository URL if no remote exists.",
    )
    parser.add_argument(
        "--pull-first",
        action="store_true",
        help="Pull the remote branch before pushing.",
    )
    parser.add_argument(
        "--log-file",
        default=str(DEFAULT_UPLOAD_LOG),
        help=f"CSV file used to record upload details. Default: {DEFAULT_UPLOAD_LOG}.",
    )
    parser.add_argument(
        "--no-log",
        action="store_true",
        help="Commit and push without writing to the CSV upload log.",
    )
    return parser


def _safe_int(value: int | None) -> int:
    return value if value is not None else 0


def append_upload_log(
    log_file: Path,
    *,
    changes: list[GitFileChange],
    branch: str,
    remote: str,
    message: str,
    pull_first: bool,
) -> None:
    now = datetime.now().astimezone()
    upload_id = f"{now:%Y%m%d%H%M%S}-{uuid4().hex[:8]}"
    total_additions = sum(_safe_int(change.additions) for change in changes)
    total_deletions = sum(_safe_int(change.deletions) for change in changes)
    has_header = log_file.exists() and log_file.stat().st_size > 0

    log_file.parent.mkdir(parents=True, exist_ok=True)

    with log_file.open("a", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=LOG_FIELDS)
        if not has_header:
            writer.writeheader()

        for change in changes:
            writer.writerow(
                {
                    "upload_id": upload_id,
                    "timestamp": now.isoformat(timespec="seconds"),
                    "date": now.date().isoformat(),
                    "time": now.strftime("%H:%M:%S"),
                    "timezone": now.tzname() or "",
                    "utc_offset": now.strftime("%z"),
                    "branch": branch,
                    "remote": remote,
                    "commit_message": message,
                    "pull_first": str(pull_first).lower(),
                    "total_files": len(changes),
                    "total_additions": total_additions,
                    "total_deletions": total_deletions,
                    "file_path": change.path,
                    "old_path": change.old_path,
                    "change_type": change.change_type,
                    "git_status": change.status,
                    "additions": "" if change.additions is None else change.additions,
                    "deletions": "" if change.deletions is None else change.deletions,
                    "is_binary": str(change.is_binary).lower(),
                    "script": "upload.py",
                }
            )

    print(f"Recorded {len(changes)} file change(s) in {log_file}.")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    runner = GitRunner()

    try:
        ensure_git_available()
        if not is_git_repository(runner):
            raise GitError("This folder is not a Git repository. Run github.py first.")

        branch = args.branch or current_branch(runner) or DEFAULT_BRANCH
        ensure_remote(runner, remote=args.remote, repo_file=Path(args.repo_file))

        log_file = Path(args.log_file)
        excluded_paths = {log_file.as_posix()}
        pending_paths = changed_paths(runner) - excluded_paths

        if not pending_paths:
            print("No project file changes to commit.")
            push_branch(runner, remote=args.remote, branch=branch)
            return 0

        stage_all(runner)
        changes = collect_staged_changes(runner, exclude_paths=excluded_paths)

        if not changes:
            print("No project file changes to commit.")
            push_branch(runner, remote=args.remote, branch=branch)
            return 0

        if not args.no_log:
            append_upload_log(
                log_file,
                changes=changes,
                branch=branch,
                remote=args.remote,
                message=args.message,
                pull_first=args.pull_first,
            )
            stage_path(runner, log_file)

        commit_staged_if_needed(runner, args.message)

        if args.pull_first and remote_branch_exists(
            runner,
            remote=args.remote,
            branch=branch,
        ):
            pull_branch(runner, remote=args.remote, branch=branch)

        push_branch(runner, remote=args.remote, branch=branch)
    except GitError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
