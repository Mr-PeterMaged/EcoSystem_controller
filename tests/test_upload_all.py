"""Tests for upload_all.py utility functions."""
import subprocess
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from upload_all import (
    discover_git_repos,
    path_is_relative_to,
    large_files,
    stage_everything,
)


class TestPathIsRelativeTo:
    def test_child_is_relative(self, tmp_path):
        child = tmp_path / "a" / "b"
        assert path_is_relative_to(child, tmp_path) is True

    def test_sibling_is_not_relative(self, tmp_path):
        sibling = tmp_path.parent / "other"
        assert path_is_relative_to(sibling, tmp_path) is False

    def test_same_path_is_relative(self, tmp_path):
        assert path_is_relative_to(tmp_path, tmp_path) is True


class TestLargeFiles:
    def test_no_large_files(self, tmp_path):
        (tmp_path / "small.txt").write_bytes(b"x" * 100)
        result = large_files(tmp_path, [])
        assert result == []

    def test_large_file_detected(self, tmp_path):
        big = tmp_path / "big.bin"
        big.write_bytes(b"x" * (100 * 1024 * 1024 + 1))
        result = large_files(tmp_path, [])
        assert big.resolve() in result

    def test_child_repo_files_excluded(self, tmp_path):
        child_repo = tmp_path / "sub"
        child_repo.mkdir()
        big = child_repo / "huge.bin"
        big.write_bytes(b"x" * (100 * 1024 * 1024 + 1))
        result = large_files(tmp_path, [child_repo.resolve()])
        assert big.resolve() not in result


class TestDiscoverGitRepos:
    def test_skips_apk_release_repo(self, tmp_path):
        root_git = tmp_path / ".git"
        apk_git = tmp_path / ".apk_release_repo" / ".git"
        child_git = tmp_path / "tools" / ".git"
        root_git.mkdir()
        apk_git.mkdir(parents=True)
        child_git.mkdir(parents=True)

        with patch("upload_all.APK_REPO_DIR", tmp_path / ".apk_release_repo"):
            result = discover_git_repos(tmp_path)

        assert tmp_path.resolve() in result
        assert (tmp_path / "tools").resolve() in result
        assert (tmp_path / ".apk_release_repo").resolve() not in result


class TestStageEverything:
    def test_no_force_flag_by_default(self):
        captured = []

        def fake_run(args, *, cwd, **kwargs):
            captured.append(args)
            return MagicMock(returncode=0)

        with patch("upload_all.run", side_effect=fake_run):
            stage_everything(Path("/fake"), force_ignored=False)

        assert captured, "run was not called"
        cmd = captured[0]
        assert "-f" not in cmd

    def test_force_flag_when_requested(self):
        captured = []

        def fake_run(args, *, cwd, **kwargs):
            captured.append(args)
            return MagicMock(returncode=0)

        with patch("upload_all.run", side_effect=fake_run):
            stage_everything(Path("/fake"), force_ignored=True)

        assert captured
        cmd = captured[0]
        assert "-f" in cmd
