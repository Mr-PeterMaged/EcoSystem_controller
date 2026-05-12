from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import shutil
import subprocess
from typing import Sequence

from github_repos import DEFAULT_BRANCH, DEFAULT_REMOTE


REMOTE_FILE = Path("repo_url.txt")


CHANGE_TYPE_LABELS = {
    "A": "added",
    "C": "copied",
    "D": "deleted",
    "M": "modified",
    "R": "renamed",
    "T": "type_changed",
    "U": "unmerged",
    "X": "unknown",
}


class GitError(RuntimeError):
    """Raised when a Git workflow cannot be completed."""


@dataclass(frozen=True)
class GitFileChange:
    path: str
    status: str
    change_type: str
    additions: int | None
    deletions: int | None
    old_path: str = ""
    is_binary: bool = False


class GitRunner:
    def __init__(self, *, verbose: bool = True) -> None:
        self.verbose = verbose

    def run(
        self,
        args: Sequence[str],
        *,
        check: bool = True,
        capture_output: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        if self.verbose:
            print(f"$ {subprocess.list2cmdline(list(args))}")

        try:
            return subprocess.run(
                list(args),
                check=check,
                text=True,
                capture_output=capture_output,
            )
        except FileNotFoundError as exc:
            raise GitError("Git is not installed or is not available in PATH.") from exc
        except subprocess.CalledProcessError as exc:
            error = (exc.stderr or "").strip()
            detail = f"\n{error}" if error else ""
            raise GitError(
                f"Command failed: {subprocess.list2cmdline(list(args))}{detail}"
            ) from exc


def ensure_git_available() -> None:
    if shutil.which("git") is None:
        raise GitError("Git is not installed or is not available in PATH.")


def is_git_repository(runner: GitRunner) -> bool:
    result = runner.run(
        ["git", "rev-parse", "--is-inside-work-tree"],
        check=False,
        capture_output=True,
    )
    return result.returncode == 0 and result.stdout.strip() == "true"


def init_repository(runner: GitRunner) -> None:
    if is_git_repository(runner):
        print("Git repository already exists.")
        return

    runner.run(["git", "init"])


def rename_current_branch(runner: GitRunner, branch: str) -> None:
    runner.run(["git", "branch", "-M", branch])


def current_branch(runner: GitRunner) -> str | None:
    result = runner.run(
        ["git", "branch", "--show-current"],
        check=False,
        capture_output=True,
    )
    branch = result.stdout.strip()
    return branch or None


def has_changes(runner: GitRunner) -> bool:
    result = runner.run(["git", "status", "--porcelain"], capture_output=True)
    return bool(result.stdout.strip())


def stage_all(runner: GitRunner) -> None:
    runner.run(["git", "add", "--all"])


def stage_path(runner: GitRunner, path: Path) -> None:
    runner.run(["git", "add", "--", path.as_posix()])


def has_staged_changes(runner: GitRunner) -> bool:
    result = runner.run(["git", "diff", "--cached", "--quiet"], check=False)
    if result.returncode == 0:
        return False
    if result.returncode == 1:
        return True
    raise GitError("Could not inspect staged Git changes.")


def commit_staged_if_needed(runner: GitRunner, message: str) -> bool:
    if not has_staged_changes(runner):
        print("No staged changes to commit.")
        return False

    runner.run(["git", "commit", "-m", message])
    return True


def commit_if_needed(runner: GitRunner, message: str) -> bool:
    stage_all(runner)

    if not has_changes(runner):
        print("No changes to commit.")
        return False

    runner.run(["git", "commit", "-m", message])
    return True


def _split_nul_output(output: str) -> list[str]:
    return [item for item in output.split("\0") if item]


def changed_paths(runner: GitRunner) -> set[str]:
    paths: set[str] = set()
    commands = [
        ["git", "diff", "--cached", "--name-only", "-z"],
        ["git", "diff", "--name-only", "-z"],
        ["git", "ls-files", "--others", "--exclude-standard", "-z"],
    ]

    for command in commands:
        result = runner.run(command, capture_output=True)
        paths.update(_split_nul_output(result.stdout))

    return paths


def _numstat_for_path(
    runner: GitRunner,
    path: str,
) -> tuple[int | None, int | None, bool]:
    result = runner.run(
        ["git", "diff", "--cached", "--numstat", "--", path],
        capture_output=True,
    )
    line = result.stdout.splitlines()[0] if result.stdout.strip() else ""
    if not line:
        return 0, 0, False

    additions_text, deletions_text, *_ = line.split("\t", 2)
    if additions_text == "-" or deletions_text == "-":
        return None, None, True

    return int(additions_text), int(deletions_text), False


def collect_staged_changes(
    runner: GitRunner,
    *,
    exclude_paths: set[str] | None = None,
) -> list[GitFileChange]:
    excluded = exclude_paths or set()
    result = runner.run(
        ["git", "diff", "--cached", "--name-status", "-z"],
        capture_output=True,
    )
    parts = _split_nul_output(result.stdout)
    changes: list[GitFileChange] = []
    index = 0

    while index < len(parts):
        status = parts[index]
        index += 1
        status_code = status[:1] or "X"

        if status_code in {"R", "C"}:
            old_path = parts[index]
            path = parts[index + 1]
            index += 2
        else:
            old_path = ""
            path = parts[index]
            index += 1

        if path in excluded or old_path in excluded:
            continue

        additions, deletions, is_binary = _numstat_for_path(runner, path)
        changes.append(
            GitFileChange(
                path=path,
                old_path=old_path,
                status=status,
                change_type=CHANGE_TYPE_LABELS.get(status_code, "unknown"),
                additions=additions,
                deletions=deletions,
                is_binary=is_binary,
            )
        )

    return changes


def read_saved_repo_url(path: Path = REMOTE_FILE) -> str | None:
    if not path.exists():
        return None

    url = path.read_text(encoding="utf-8").strip()
    return url or None


def save_repo_url(url: str, path: Path = REMOTE_FILE) -> None:
    path.write_text(f"{url}\n", encoding="utf-8")


def resolve_repo_url(provided_url: str | None, path: Path = REMOTE_FILE) -> str:
    if provided_url:
        return provided_url.strip()

    saved_url = read_saved_repo_url(path)
    if saved_url:
        return saved_url

    url = input("Enter your GitHub repository URL: ").strip()
    if not url:
        raise GitError("Repository URL is required.")
    return url


def get_remote_url(runner: GitRunner, remote: str = DEFAULT_REMOTE) -> str | None:
    result = runner.run(
        ["git", "remote", "get-url", remote],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def configure_remote(
    runner: GitRunner,
    repo_url: str,
    *,
    remote: str = DEFAULT_REMOTE,
) -> None:
    current_url = get_remote_url(runner, remote)
    if current_url is None:
        runner.run(["git", "remote", "add", remote, repo_url])
        return

    if current_url != repo_url:
        runner.run(["git", "remote", "set-url", remote, repo_url])
        return

    print(f"Remote '{remote}' already points to the requested URL.")


def ensure_remote(
    runner: GitRunner,
    *,
    remote: str = DEFAULT_REMOTE,
    repo_file: Path = REMOTE_FILE,
) -> None:
    if get_remote_url(runner, remote):
        return

    repo_url = read_saved_repo_url(repo_file)
    if not repo_url:
        raise GitError(
            f"Remote '{remote}' is not configured. Run github.py with a repository URL first."
        )

    configure_remote(runner, repo_url, remote=remote)


def remote_branch_exists(
    runner: GitRunner,
    *,
    remote: str = DEFAULT_REMOTE,
    branch: str = DEFAULT_BRANCH,
) -> bool:
    result = runner.run(
        ["git", "ls-remote", "--exit-code", "--heads", remote, branch],
        check=False,
        capture_output=True,
    )
    if result.returncode == 0:
        return True
    if result.returncode == 2:
        return False

    error = (result.stderr or "").strip()
    detail = f": {error}" if error else "."
    raise GitError(f"Could not check remote branch '{remote}/{branch}'{detail}")


def pull_branch(
    runner: GitRunner,
    *,
    remote: str = DEFAULT_REMOTE,
    branch: str = DEFAULT_BRANCH,
) -> None:
    runner.run(
        ["git", "pull", "--no-rebase", "--allow-unrelated-histories", remote, branch]
    )


def push_branch(
    runner: GitRunner,
    *,
    remote: str = DEFAULT_REMOTE,
    branch: str = DEFAULT_BRANCH,
) -> None:
    runner.run(["git", "push", "-u", remote, branch])
