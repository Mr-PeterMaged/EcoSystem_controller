"""Shared constants, helpers, and device/browser dataclasses for capture scripts."""
from __future__ import annotations

import os
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
from collections import deque
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
APK_BUILDS_DIR = PROJECT_ROOT / "apk_builds"
MOCKUP_DIR = PROJECT_ROOT / "mockup"
DEFAULT_INPUT_DIR = MOCKUP_DIR / "input"
DEFAULT_OUTPUT_DIR = MOCKUP_DIR / "output"
MOCKUP_SCRIPT = PROJECT_ROOT / "make_phone_mockups.py"
DEFAULT_PACKAGE = "com.example.ecosystem_controller"
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
LOCAL_PYTHON_DEPS = PROJECT_ROOT / ".python_deps"
LOCAL_RUNTIME_TMP = PROJECT_ROOT / ".runtime_tmp"

if LOCAL_PYTHON_DEPS.exists():
    sys.path.insert(0, str(LOCAL_PYTHON_DEPS))


@dataclass(frozen=True)
class Device:
    adb: str
    serial: str | None
    width: int
    height: int


@dataclass(frozen=True)
class BrowserTarget:
    width: int
    height: int


class CaptureError(RuntimeError):
    pass


# ── Path helpers ──────────────────────────────────────────────────────────────

def resolve_project_path(value: str | Path) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    return path


def read_application_id() -> str:
    build_files = [
        PROJECT_ROOT / "android" / "app" / "build.gradle.kts",
        PROJECT_ROOT / "android" / "app" / "build.gradle",
    ]
    for build_file in build_files:
        if not build_file.exists():
            continue
        text = build_file.read_text(encoding="utf-8", errors="replace")
        match = re.search(r'applicationId\s*=\s*["\']([^"\']+)["\']', text)
        if match:
            return match.group(1)
        match = re.search(r'applicationId\s+["\']([^"\']+)["\']', text)
        if match:
            return match.group(1)
    return DEFAULT_PACKAGE


def latest_apk() -> Path:
    apks = sorted(
        APK_BUILDS_DIR.glob("*.apk"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    if not apks:
        raise CaptureError(
            f"No APK files found in {APK_BUILDS_DIR}. Build the app first."
        )
    return apks[0]


def clean_image_folder(folder: Path) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    for item in folder.iterdir():
        if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS:
            item.unlink()


# ── Tool finders ──────────────────────────────────────────────────────────────

def find_flutter() -> str:
    found = shutil.which("flutter")
    if found:
        return found

    candidates = [
        Path("C:/src/flutter/bin/flutter.bat"),
        Path("C:/flutter/bin/flutter.bat"),
    ]
    for env_name in ("FLUTTER_HOME", "FLUTTER_ROOT"):
        env_value = os.environ.get(env_name)
        if env_value:
            candidates.append(Path(env_value) / "bin" / "flutter.bat")
            candidates.append(Path(env_value) / "bin" / "flutter")
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)

    raise CaptureError(
        "Flutter was not found. Add flutter to PATH or install it at C:/src/flutter."
    )


def tool_command(executable: str, args: list[str]) -> list[str]:
    if os.name == "nt" and executable.lower().endswith((".bat", ".cmd")):
        return ["cmd", "/c", executable, *args]
    return [executable, *args]


def find_adb() -> str:
    found = shutil.which("adb")
    if found:
        return found

    candidates: list[Path] = []
    for env_name in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        env_value = os.environ.get(env_name)
        if env_value:
            candidates.append(Path(env_value) / "platform-tools" / "adb.exe")
            candidates.append(Path(env_value) / "platform-tools" / "adb")
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        candidates.append(
            Path(local_app_data) / "Android" / "Sdk" / "platform-tools" / "adb.exe"
        )
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)

    raise CaptureError(
        "ADB was not found. Install Android platform-tools or add adb to PATH."
    )


# ── ADB runner ────────────────────────────────────────────────────────────────

def run(
    adb: str,
    args: list[str],
    *,
    serial: str | None = None,
    check: bool = True,
    capture_output: bool = True,
    text: bool = True,
    timeout: int = 60,
    stdout_file=None,
) -> subprocess.CompletedProcess:
    command = [adb]
    if serial:
        command.extend(["-s", serial])
    command.extend(args)
    return subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        check=check,
        capture_output=capture_output and stdout_file is None,
        stdout=stdout_file,
        stderr=subprocess.PIPE if stdout_file is not None else None,
        text=text,
        timeout=timeout,
    )


def connected_devices(adb: str) -> list[str]:
    result = run(adb, ["devices"], timeout=20)
    devices: list[str] = []
    for line in result.stdout.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            devices.append(parts[0])
    return devices


def choose_device(adb: str, requested_serial: str | None) -> str | None:
    devices = connected_devices(adb)
    if requested_serial:
        if requested_serial not in devices:
            raise CaptureError(
                f"Device '{requested_serial}' is not connected. Connected: {devices or 'none'}"
            )
        return requested_serial
    if not devices:
        raise CaptureError(
            "No Android device/emulator is connected. "
            "Start an emulator or connect a phone with USB debugging."
        )
    if len(devices) > 1:
        print(f"Multiple devices found. Using: {devices[0]}")
        print("Use --device SERIAL if you want a specific one.")
    return devices[0]


def get_screen_size(adb: str, serial: str | None) -> tuple[int, int]:
    result = run(adb, ["shell", "wm", "size"], serial=serial, check=False, timeout=20)
    match = re.search(r"(\d+)x(\d+)", result.stdout or "")
    if match:
        return int(match.group(1)), int(match.group(2))
    return 1080, 1920


# ── Process helpers ───────────────────────────────────────────────────────────

def configure_local_runtime_temp() -> None:
    LOCAL_RUNTIME_TMP.mkdir(parents=True, exist_ok=True)
    os.environ["TEMP"] = str(LOCAL_RUNTIME_TMP)
    os.environ["TMP"] = str(LOCAL_RUNTIME_TMP)


def find_free_port(host: str, preferred_port: int) -> int:
    if preferred_port:
        return preferred_port
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind((host, 0))
        return int(sock.getsockname()[1])


def port_is_open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=1):
            return True
    except OSError:
        return False


def start_log_reader(process: subprocess.Popen) -> tuple[deque[str], threading.Thread]:
    lines: deque[str] = deque(maxlen=40)

    def read_output() -> None:
        if process.stdout is None:
            return
        for line in process.stdout:
            clean = line.rstrip()
            if clean:
                lines.append(clean)
                print(f"[flutter] {clean}")

    thread = threading.Thread(target=read_output, daemon=True)
    thread.start()
    return lines, thread


def stop_process_tree(process: subprocess.Popen | None) -> None:
    if process is None or process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(process.pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return
    process.terminate()
    try:
        process.wait(timeout=8)
    except subprocess.TimeoutExpired:
        process.kill()


# ── Mockup runner ─────────────────────────────────────────────────────────────

def run_mockup_script(args, input_dir: Path, output_dir: Path) -> None:
    if args.no_mockup:
        print("Skipping mockup generation because --no-mockup was used.")
        return
    if not MOCKUP_SCRIPT.exists():
        raise CaptureError(f"Mockup script not found: {MOCKUP_SCRIPT}")
    command = [
        sys.executable,
        str(MOCKUP_SCRIPT),
        "--input", str(input_dir),
        "--output", str(output_dir),
        "--fit", args.fit,
        "--background", args.background,
        "--phone", args.phone,
    ]
    print("Running mockup generator...", flush=True)
    subprocess.run(command, cwd=PROJECT_ROOT, check=True)
