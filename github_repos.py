from __future__ import annotations

from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent

GITHUB_OWNER = "Mr-PeterMaged"
CODE_REPO_NAME = "EcoSystem_controller"
APK_REPO_NAME = "EcoSystem_controller_APK"

CODE_REPO_URL = f"https://github.com/{GITHUB_OWNER}/{CODE_REPO_NAME}.git"
APK_REPO_URL = f"https://github.com/{GITHUB_OWNER}/{APK_REPO_NAME}.git"

APK_REPO_DIR = PROJECT_ROOT / ".apk_release_repo"

DEFAULT_REMOTE = "origin"
DEFAULT_BRANCH = "main"

APP_DISPLAY_NAME = "EcoSystem Controller"
PUBLIC_APK_NAME = "EcoSystem_Controller.apk"
