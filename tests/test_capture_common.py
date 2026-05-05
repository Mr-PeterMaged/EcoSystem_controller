"""Tests for capture_common.py helpers."""
import os
from pathlib import Path
from unittest.mock import patch

import pytest

from capture_common import (
    CaptureError,
    clean_image_folder,
    IMAGE_EXTENSIONS,
    latest_apk,
    read_application_id,
    resolve_project_path,
)


class TestResolveProjectPath:
    def test_absolute_path_unchanged(self, tmp_path):
        result = resolve_project_path(tmp_path)
        assert result == tmp_path

    def test_relative_path_anchored_to_project_root(self):
        from capture_common import PROJECT_ROOT
        result = resolve_project_path("mockup/input")
        assert result == PROJECT_ROOT / "mockup" / "input"





class TestCleanImageFolder:
    def test_creates_folder_if_missing(self, tmp_path):
        folder = tmp_path / "new_folder"
        clean_image_folder(folder)
        assert folder.exists()

    def test_deletes_image_files(self, tmp_path):
        for ext in (".png", ".jpg", ".webp"):
            (tmp_path / f"img{ext}").write_bytes(b"\x89PNG")
        (tmp_path / "keep.txt").write_text("keep")
        clean_image_folder(tmp_path)
        remaining = list(tmp_path.iterdir())
        assert len(remaining) == 1
        assert remaining[0].name == "keep.txt"

    def test_leaves_non_image_files(self, tmp_path):
        (tmp_path / "data.json").write_text("{}")
        clean_image_folder(tmp_path)
        assert (tmp_path / "data.json").exists()


class TestLatestApk:
    def test_raises_when_no_apks(self, tmp_path):
        with patch("capture_common.APK_BUILDS_DIR", tmp_path):
            with pytest.raises(CaptureError, match="No APK files found"):
                latest_apk()

    def test_returns_newest_apk(self, tmp_path):
        older = tmp_path / "old.apk"
        newer = tmp_path / "new.apk"
        older.write_bytes(b"old")
        import time
        time.sleep(0.01)
        newer.write_bytes(b"new")
        with patch("capture_common.APK_BUILDS_DIR", tmp_path):
            result = latest_apk()
        assert result.name == "new.apk"


class TestReadApplicationId:
    def test_reads_from_gradle_kts(self, tmp_path):
        gradle = tmp_path / "build.gradle.kts"
        gradle.write_text('applicationId = "com.example.myapp"\n')
        with patch("capture_common.PROJECT_ROOT", tmp_path):
            # point build_files to our tmp file
            from capture_common import read_application_id
            with patch(
                "capture_common.PROJECT_ROOT",
                tmp_path,
            ):
                # Re-construct path as the function does
                import capture_common as cc
                orig = cc.PROJECT_ROOT
                cc.PROJECT_ROOT = tmp_path
                (tmp_path / "android" / "app").mkdir(parents=True)
                (tmp_path / "android" / "app" / "build.gradle.kts").write_text(
                    'applicationId = "com.example.myapp"\n'
                )
                result = read_application_id()
                cc.PROJECT_ROOT = orig
        assert result == "com.example.myapp"

    def test_returns_default_when_no_file(self, tmp_path):
        import capture_common as cc
        orig = cc.PROJECT_ROOT
        cc.PROJECT_ROOT = tmp_path
        result = read_application_id()
        cc.PROJECT_ROOT = orig
        assert result == "com.example.ecosystem_controller"
