from __future__ import annotations

import argparse
import io
import socket
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET
from collections import deque
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
APK_BUILDS_DIR = PROJECT_ROOT / "apk_builds"
MOCKUP_DIR = PROJECT_ROOT / "mockup"
DEFAULT_INPUT_DIR = MOCKUP_DIR / "input"
DEFAULT_OUTPUT_DIR = MOCKUP_DIR / "output"
MOCKUP_SCRIPT = PROJECT_ROOT / "make_phone_mockups.py"
DEFAULT_PACKAGE = "com.example.app1"
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
        candidates.append(Path(local_app_data) / "Android" / "Sdk" / "platform-tools" / "adb.exe")

    for candidate in candidates:
        if candidate.exists():
            return str(candidate)

    raise CaptureError(
        "ADB was not found. Install Android platform-tools or add adb to PATH."
    )


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
            "No Android device/emulator is connected. Start an emulator or connect a phone with USB debugging."
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


def start_flutter_web_server(
    *,
    host: str,
    port: int,
    skip_pub_get: bool,
    skip_web_build: bool,
    web_build_mode: str,
    startup_timeout: int,
) -> tuple[subprocess.Popen, str]:
    flutter = find_flutter()
    if not skip_pub_get:
        print("Running flutter pub get...")
        subprocess.run(
            tool_command(flutter, ["pub", "get"]),
            cwd=PROJECT_ROOT,
            check=True,
        )

    web_dir = PROJECT_ROOT / "build" / "web"
    if not skip_web_build:
        print(f"Building Flutter web ({web_build_mode})...")
        subprocess.run(
            tool_command(flutter, ["build", "web", f"--{web_build_mode}"]),
            cwd=PROJECT_ROOT,
            check=True,
        )

    if not (web_dir / "index.html").exists():
        raise CaptureError(
            f"Flutter web output was not found at {web_dir}. Run flutter build web first."
        )

    url = f"http://{host}:{port}"
    command = [
        sys.executable,
        "-m",
        "http.server",
        str(port),
        "--bind",
        host,
        "--directory",
        str(web_dir),
    ]
    print(f"Starting local Chrome preview server: {url}")
    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    process = subprocess.Popen(
        command,
        cwd=PROJECT_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
        bufsize=1,
        creationflags=creationflags,
    )
    recent_lines, _ = start_log_reader(process)

    started_at = time.monotonic()
    while time.monotonic() - started_at < startup_timeout:
        if process.poll() is not None:
            details = "\n".join(recent_lines)
            raise CaptureError(f"Local web server stopped early.\n{details}")
        if port_is_open(host, port):
            time.sleep(0.8)
            return process, url
        time.sleep(1.0)

    details = "\n".join(recent_lines)
    raise CaptureError(
        f"Local web server did not start within {startup_timeout} seconds.\n{details}"
    )


def import_playwright():
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise CaptureError(
            "Playwright is required for Chrome capture.\n"
            "Install it with:\n"
            f"{sys.executable} -m pip install --target {LOCAL_PYTHON_DEPS} playwright==1.44.0"
        ) from exc
    return sync_playwright


def browser_tap(page, target: BrowserTarget, x_ratio: float, y_ratio: float, label: str = "") -> None:
    x = round(target.width * x_ratio)
    y = round(target.height * y_ratio)
    if label:
        print(f"Browser tap {label}: {x},{y}")
    page.mouse.click(x, y)
    page.wait_for_timeout(350)


def browser_type(
    page,
    target: BrowserTarget,
    x_ratio: float,
    y_ratio: float,
    value: str,
    label: str = "",
) -> None:
    browser_tap(page, target, x_ratio, y_ratio, label or "field")
    page.keyboard.press("Control+A")
    page.keyboard.press("Backspace")
    page.keyboard.type(value, delay=10)
    page.wait_for_timeout(250)


def browser_scroll(page, pixels: int) -> None:
    page.mouse.wheel(0, pixels)
    page.wait_for_timeout(550)


def browser_back(page) -> None:
    page.keyboard.press("Alt+ArrowLeft")
    page.wait_for_timeout(900)


def browser_app_back(page, target: BrowserTarget) -> None:
    browser_tap(page, target, 0.072, 0.055, "app back")
    page.wait_for_timeout(900)


def browser_capture(page, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(destination), full_page=False)
    print(f"Saved screenshot: {destination}")


def wait_for_non_blank_page(page, timeout_seconds: int) -> None:
    try:
        from PIL import Image, ImageStat
    except ImportError:
        page.wait_for_timeout(5000)
        return

    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        data = page.screenshot(full_page=False)
        with Image.open(io.BytesIO(data)).convert("RGB") as image:
            sample = image.resize((24, 24))
            stat = ImageStat.Stat(sample)
            avg = sum(stat.mean) / 3
            variance = sum(stat.var) / 3
        if not (avg > 248 and variance < 2):
            return
        page.wait_for_timeout(500)
    print("Warning: page still looks blank; continuing anyway.")


def browser_signup(page, target: BrowserTarget, input_dir: Path, username: str, password: str, full_name: str) -> None:
    browser_capture(page, input_dir / "01_signup.png")
    browser_type(page, target, 0.50, 0.242, full_name, "full name")
    browser_type(page, target, 0.50, 0.356, username, "username")
    browser_type(page, target, 0.50, 0.470, password, "password")
    browser_type(page, target, 0.50, 0.583, password, "confirm password")
    page.keyboard.press("Escape")
    browser_tap(page, target, 0.50, 0.681, "create account")
    page.wait_for_timeout(1500)


def browser_login(page, target: BrowserTarget, input_dir: Path, username: str, password: str) -> None:
    browser_capture(page, input_dir / "02_login.png")
    browser_type(page, target, 0.50, 0.265, username, "login username")
    browser_type(page, target, 0.50, 0.383, password, "login password")
    page.keyboard.press("Escape")
    browser_tap(page, target, 0.50, 0.491, "login")
    page.wait_for_timeout(4800)


def browser_authenticate(
    page,
    target: BrowserTarget,
    input_dir: Path,
    *,
    auth_flow: str,
    username: str,
    password: str,
    full_name: str,
) -> None:
    flow = "signup" if auth_flow == "auto" else auth_flow
    print(f"Browser auth flow: {flow}")
    if flow == "skip":
        return
    if flow == "signup":
        browser_signup(page, target, input_dir, username, password, full_name)
        browser_login(page, target, input_dir, username, password)
        return
    if flow == "login":
        browser_login(page, target, input_dir, username, password)
        return
    raise CaptureError(f"Unsupported auth flow: {flow}")


def browser_capture_main_screens(page, target: BrowserTarget, input_dir: Path) -> None:
    browser_capture(page, input_dir / "03_home.png")

    browser_scroll(page, 700)
    browser_tap(page, target, 0.50, 0.759, "show full control")
    page.wait_for_timeout(1000)
    browser_capture(page, input_dir / "04_control.png")
    browser_app_back(page, target)

    browser_scroll(page, 700)
    browser_tap(page, target, 0.50, 0.845, "show stats")
    page.wait_for_timeout(1000)
    browser_capture(page, input_dir / "05_stats.png")
    browser_app_back(page, target)

    browser_tap(page, target, 0.708, 0.034, "notifications")
    page.wait_for_timeout(1000)
    browser_capture(page, input_dir / "06_notifications.png")
    browser_app_back(page, target)

    browser_tap(page, target, 0.826, 0.034, "about us")
    page.wait_for_timeout(1000)
    browser_capture(page, input_dir / "07_about_us.png")
    browser_app_back(page, target)

    browser_tap(page, target, 0.928, 0.034, "menu")
    page.wait_for_timeout(700)
    browser_tap(page, target, 0.70, 0.215, "settings")
    page.wait_for_timeout(1000)
    browser_capture(page, input_dir / "08_settings.png")
    browser_app_back(page, target)

    browser_tap(page, target, 0.928, 0.034, "menu")
    page.wait_for_timeout(700)
    browser_tap(page, target, 0.70, 0.290, "automation")
    page.wait_for_timeout(1000)
    browser_capture(page, input_dir / "09_automation.png")
    browser_app_back(page, target)


def launch_browser(sync_playwright, args: argparse.Namespace):
    playwright = sync_playwright().start()
    browser_type_name = args.browser_channel.strip().lower()
    channel = None if browser_type_name in {"", "bundled", "chromium"} else args.browser_channel
    try:
        browser = playwright.chromium.launch(channel=channel, headless=args.headless)
    except Exception:
        if channel is None:
            playwright.stop()
            raise
        print(f"Chrome channel '{args.browser_channel}' was not available. Falling back to bundled Chromium.")
        browser = playwright.chromium.launch(headless=args.headless)
    return playwright, browser


def capture_with_chrome(args: argparse.Namespace, input_dir: Path, output_dir: Path) -> None:
    configure_local_runtime_temp()
    host = args.web_host
    port = find_free_port(host, args.web_port)
    process: subprocess.Popen | None = None
    playwright = None
    browser = None
    try:
        process, url = start_flutter_web_server(
            host=host,
            port=port,
            skip_pub_get=args.skip_pub_get,
            skip_web_build=args.skip_web_build,
            web_build_mode=args.web_build_mode,
            startup_timeout=args.web_timeout,
        )
        sync_playwright = import_playwright()
        playwright, browser = launch_browser(sync_playwright, args)
        target = BrowserTarget(width=args.web_width, height=args.web_height)
        context = browser.new_context(
            viewport={"width": target.width, "height": target.height},
            device_scale_factor=args.device_scale_factor,
            is_mobile=True,
            has_touch=True,
        )
        page = context.new_page()
        page.goto(url, wait_until="domcontentloaded", timeout=args.web_timeout * 1000)
        wait_for_non_blank_page(page, args.web_timeout)
        page.wait_for_timeout(800)
        browser_capture(page, input_dir / "00_loading.png")
        print("Waiting for the 5 second loading screen...")
        page.wait_for_timeout(5500)
        browser_authenticate(
            page,
            target,
            input_dir,
            auth_flow=args.auth_flow,
            username=args.username,
            password=args.password,
            full_name=args.full_name,
        )
        browser_capture_main_screens(page, target, input_dir)
        run_mockup_script(args, input_dir, output_dir)
    finally:
        if browser is not None:
            browser.close()
        if playwright is not None:
            playwright.stop()
        stop_process_tree(process)


def tap(device: Device, x_ratio: float, y_ratio: float, label: str = "") -> None:
    x = round(device.width * x_ratio)
    y = round(device.height * y_ratio)
    if label:
        print(f"Tap {label}: {x},{y}")
    run(device.adb, ["shell", "input", "tap", str(x), str(y)], serial=device.serial, timeout=20)
    time.sleep(0.35)


def swipe(
    device: Device,
    start: tuple[float, float],
    end: tuple[float, float],
    *,
    duration_ms: int = 350,
) -> None:
    x1 = round(device.width * start[0])
    y1 = round(device.height * start[1])
    x2 = round(device.width * end[0])
    y2 = round(device.height * end[1])
    run(
        device.adb,
        ["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(duration_ms)],
        serial=device.serial,
        timeout=20,
    )
    time.sleep(0.45)


def keyevent(device: Device, *keys: str) -> None:
    if not keys:
        return
    run(device.adb, ["shell", "input", "keyevent", *keys], serial=device.serial, timeout=20)
    time.sleep(0.2)


def input_text(device: Device, value: str) -> None:
    safe = value.replace(" ", "%s")
    run(device.adb, ["shell", "input", "text", safe], serial=device.serial, timeout=20)
    time.sleep(0.25)


def clear_focused_text(device: Device, count: int = 40) -> None:
    keyevent(device, "KEYCODE_MOVE_END")
    run(
        device.adb,
        ["shell", "input", "keyevent", *("KEYCODE_DEL" for _ in range(count))],
        serial=device.serial,
        timeout=20,
    )
    time.sleep(0.2)


def tap_type(
    device: Device,
    x_ratio: float,
    y_ratio: float,
    value: str,
    *,
    clear: bool = True,
    label: str = "",
) -> None:
    tap(device, x_ratio, y_ratio, label or "field")
    if clear:
        clear_focused_text(device)
    input_text(device, value)


def capture(device: Device, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as handle:
        run(
            device.adb,
            ["exec-out", "screencap", "-p"],
            serial=device.serial,
            capture_output=False,
            text=False,
            stdout_file=handle,
            timeout=30,
        )
    print(f"Saved screenshot: {destination}")


def dump_ui(device: Device) -> str:
    run(
        device.adb,
        ["shell", "uiautomator", "dump", "/sdcard/window.xml"],
        serial=device.serial,
        check=False,
        timeout=20,
    )
    result = run(
        device.adb,
        ["exec-out", "cat", "/sdcard/window.xml"],
        serial=device.serial,
        check=False,
        text=False,
        timeout=20,
    )
    data = result.stdout if isinstance(result.stdout, bytes) else b""
    return data.decode("utf-8", errors="replace")


def text_exists(device: Device, needles: list[str]) -> bool:
    xml_text = dump_ui(device).lower()
    return any(needle.lower() in xml_text for needle in needles)


def parse_bounds(value: str) -> tuple[int, int] | None:
    match = re.search(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", value)
    if not match:
        return None
    x1, y1, x2, y2 = (int(match.group(i)) for i in range(1, 5))
    return (x1 + x2) // 2, (y1 + y2) // 2


def tap_text(device: Device, needles: list[str]) -> bool:
    xml_text = dump_ui(device)
    if not xml_text.strip():
        return False
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return False

    lowered = [needle.lower() for needle in needles]
    for node in root.iter():
        text_value = (node.attrib.get("text") or node.attrib.get("content-desc") or "").strip()
        if not text_value:
            continue
        if not any(needle in text_value.lower() for needle in lowered):
            continue
        center = parse_bounds(node.attrib.get("bounds", ""))
        if not center:
            continue
        run(
            device.adb,
            ["shell", "input", "tap", str(center[0]), str(center[1])],
            serial=device.serial,
            timeout=20,
        )
        print(f"Tap text '{text_value}': {center[0]},{center[1]}")
        time.sleep(0.45)
        return True
    return False


def tap_text_or_fallback(
    device: Device,
    needles: list[str],
    fallback: tuple[float, float],
    label: str,
) -> None:
    if tap_text(device, needles):
        return
    tap(device, fallback[0], fallback[1], label)


def open_drawer(device: Device) -> None:
    tap(device, 0.95, 0.055, "menu")
    time.sleep(0.7)


def go_back(device: Device, delay: float = 0.9) -> None:
    keyevent(device, "KEYCODE_BACK")
    time.sleep(delay)


def launch_app(device: Device, package_name: str) -> None:
    run(
        device.adb,
        ["shell", "monkey", "-p", package_name, "-c", "android.intent.category.LAUNCHER", "1"],
        serial=device.serial,
        timeout=30,
    )
    time.sleep(1.0)


def install_apk(device: Device, apk_path: Path) -> None:
    print(f"Installing APK: {apk_path}")
    run(device.adb, ["install", "-r", str(apk_path)], serial=device.serial, timeout=180)


def prepare_device(device: Device, package_name: str, *, force_portrait: bool) -> None:
    keyevent(device, "KEYCODE_WAKEUP")
    run(device.adb, ["shell", "wm", "dismiss-keyguard"], serial=device.serial, check=False, timeout=20)
    if force_portrait:
        run(device.adb, ["shell", "settings", "put", "system", "accelerometer_rotation", "0"], serial=device.serial, check=False, timeout=20)
        run(device.adb, ["shell", "settings", "put", "system", "user_rotation", "0"], serial=device.serial, check=False, timeout=20)
    run(device.adb, ["shell", "pm", "grant", package_name, "android.permission.POST_NOTIFICATIONS"], serial=device.serial, check=False, timeout=20)


def detect_auth_flow(device: Device, preferred: str) -> str:
    if preferred != "auto":
        return preferred
    if text_exists(device, ["Create Admin Account", "Set up the first user", "Full Name"]):
        return "signup"
    if text_exists(device, ["Login to continue", "Welcome", "Username:"]):
        return "login"
    if text_exists(device, ["Connected to ESP32", "No Connection", "Show Stats"]):
        return "skip"
    return "skip"


def perform_signup(device: Device, input_dir: Path, username: str, password: str, full_name: str) -> None:
    capture(device, input_dir / "01_signup.png")
    tap_type(device, 0.50, 0.285, full_name, label="full name")
    tap_type(device, 0.50, 0.395, username, label="username")
    tap_type(device, 0.50, 0.505, password, label="password")
    tap_type(device, 0.50, 0.615, password, label="confirm password")
    keyevent(device, "KEYCODE_BACK")
    tap_text_or_fallback(device, ["Create Account"], (0.50, 0.735), "create account")
    time.sleep(1.5)


def perform_login(device: Device, input_dir: Path, username: str, password: str) -> None:
    capture(device, input_dir / "02_login.png")
    tap_type(device, 0.50, 0.355, username, label="login username")
    tap_type(device, 0.50, 0.475, password, label="login password")
    keyevent(device, "KEYCODE_BACK")
    tap_text_or_fallback(device, ["Login"], (0.50, 0.625), "login")
    time.sleep(4.6)


def authenticate(
    device: Device,
    input_dir: Path,
    *,
    auth_flow: str,
    username: str,
    password: str,
    full_name: str,
) -> None:
    flow = detect_auth_flow(device, auth_flow)
    print(f"Auth flow: {flow}")
    if flow == "skip":
        return
    if flow == "signup":
        perform_signup(device, input_dir, username, password, full_name)
        perform_login(device, input_dir, username, password)
        return
    if flow == "login":
        perform_login(device, input_dir, username, password)
        return
    raise CaptureError(f"Unsupported auth flow: {flow}")


def capture_main_screens(device: Device, input_dir: Path) -> None:
    capture(device, input_dir / "03_home.png")

    swipe(device, (0.50, 0.83), (0.50, 0.38))
    tap_text_or_fallback(device, ["Show full control", "Full Control"], (0.50, 0.66), "show full control")
    time.sleep(1.0)
    capture(device, input_dir / "04_control.png")
    go_back(device)

    swipe(device, (0.50, 0.83), (0.50, 0.38))
    tap_text_or_fallback(device, ["Show Stats", "System Stats"], (0.50, 0.74), "show stats")
    time.sleep(1.0)
    capture(device, input_dir / "05_stats.png")
    go_back(device)

    tap(device, 0.78, 0.055, "notifications")
    time.sleep(1.0)
    capture(device, input_dir / "06_notifications.png")
    go_back(device)

    tap_text_or_fallback(device, ["About Us"], (0.88, 0.055), "about us")
    time.sleep(1.0)
    capture(device, input_dir / "07_about_us.png")
    go_back(device)

    open_drawer(device)
    tap_text_or_fallback(device, ["Settings"], (0.70, 0.215), "settings")
    time.sleep(1.0)
    capture(device, input_dir / "08_settings.png")
    go_back(device)

    open_drawer(device)
    tap_text_or_fallback(device, ["Automation"], (0.70, 0.290), "automation")
    time.sleep(1.0)
    capture(device, input_dir / "09_automation.png")
    go_back(device)


def run_mockup_script(args: argparse.Namespace, input_dir: Path, output_dir: Path) -> None:
    if args.no_mockup:
        print("Skipping mockup generation because --no-mockup was used.")
        return
    if not MOCKUP_SCRIPT.exists():
        raise CaptureError(f"Mockup script not found: {MOCKUP_SCRIPT}")
    command = [
        sys.executable,
        str(MOCKUP_SCRIPT),
        "--input",
        str(input_dir),
        "--output",
        str(output_dir),
        "--fit",
        args.fit,
        "--background",
        args.background,
        "--phone",
        args.phone,
    ]
    print("Running mockup generator...", flush=True)
    subprocess.run(command, cwd=PROJECT_ROOT, check=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Capture EcoSystem Controller app screens with Chrome or ADB, save them to mockup/input, "
            "then generate phone mockups in mockup/output."
        )
    )
    parser.add_argument(
        "--mode",
        choices=["web", "adb"],
        default="web",
        help="Capture mode. Default: web, which runs the Flutter app in Chrome.",
    )
    parser.add_argument("--apk", help="APK path. Default: latest APK inside apk_builds.")
    parser.add_argument("--package", default=read_application_id(), help="Android application id.")
    parser.add_argument("--device", help="ADB device serial. Required only when multiple devices are connected.")
    parser.add_argument("--no-install", action="store_true", help="Do not install the APK before capture.")
    parser.add_argument(
        "--fresh-data",
        action="store_true",
        help="Clear this app's local data before capture. This makes first-time signup automatic.",
    )
    parser.add_argument(
        "--auth-flow",
        choices=["auto", "signup", "login", "skip"],
        default="auto",
        help="How to pass authentication. Use skip if the app is already on the home screen.",
    )
    parser.add_argument("--username", default="ecoDemo", help="Demo username used for signup/login.")
    parser.add_argument("--password", default="ecoDemo1234", help="Demo password used for signup/login.")
    parser.add_argument("--full-name", default="EcoSmartDemo", help="Demo display name used for signup.")
    parser.add_argument("--input", default=str(DEFAULT_INPUT_DIR), help="Screenshot output folder.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT_DIR), help="Mockup output folder.")
    parser.add_argument("--clear", action="store_true", help="Delete old image files from input/output first.")
    parser.add_argument("--no-force-portrait", action="store_true", help="Do not force portrait orientation.")
    parser.add_argument("--no-mockup", action="store_true", help="Only capture screenshots; do not create mockups.")
    parser.add_argument("--fit", choices=["cover", "contain"], default="cover", help="Mockup image fit mode.")
    parser.add_argument("--background", choices=["dark", "green", "light"], default="dark", help="Mockup background style.")
    parser.add_argument("--phone", choices=["black", "green", "silver"], default="black", help="Phone frame color.")
    parser.add_argument("--web-host", default="127.0.0.1", help="Flutter web server host.")
    parser.add_argument("--web-port", type=int, default=0, help="Flutter web server port. Default: a free port.")
    parser.add_argument("--web-width", type=int, default=390, help="Chrome viewport width for mobile screenshots.")
    parser.add_argument("--web-height", type=int, default=844, help="Chrome viewport height for mobile screenshots.")
    parser.add_argument("--device-scale-factor", type=float, default=3.0, help="Chrome device scale factor.")
    parser.add_argument("--browser-channel", default="chrome", help="Browser channel: chrome, msedge, or bundled.")
    parser.add_argument("--headless", action="store_true", help="Run Chrome without a visible window.")
    parser.add_argument("--skip-pub-get", action="store_true", help="Do not run flutter pub get before starting web.")
    parser.add_argument("--skip-web-build", action="store_true", help="Reuse the existing build/web folder.")
    parser.add_argument(
        "--web-build-mode",
        choices=["debug", "profile", "release"],
        default="release",
        help="Flutter web build mode used before Chrome capture.",
    )
    parser.add_argument("--web-timeout", type=int, default=240, help="Seconds to wait for Flutter web startup.")
    parser.add_argument("--dry-run", action="store_true", help="Print the plan without starting Chrome or ADB.")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    input_dir = resolve_project_path(args.input)
    output_dir = resolve_project_path(args.output)
    apk_path = resolve_project_path(args.apk) if args.apk else None
    if args.mode == "adb" and apk_path is None:
        apk_path = latest_apk()

    if args.dry_run:
        print(f"Project: {PROJECT_ROOT}")
        print(f"Mode: {args.mode}")
        if args.mode == "adb":
            print(f"APK: {apk_path}")
        else:
            print(f"Flutter web: http://{args.web_host}:{args.web_port or '<free-port>'}")
            print(f"Chrome viewport: {args.web_width}x{args.web_height}")
            print(f"Web build mode: {args.web_build_mode}")
        print(f"Package: {args.package}")
        print(f"Screenshots: {input_dir}")
        print(f"Mockups: {output_dir}")
        if args.clear:
            print("Would clear old image files from input/output before capture.")
        print("Screens: loading, signup/login, home, control, stats, notifications, about, settings, automation")
        return 0

    if args.clear:
        clean_image_folder(input_dir)
        clean_image_folder(output_dir)
    else:
        input_dir.mkdir(parents=True, exist_ok=True)
        output_dir.mkdir(parents=True, exist_ok=True)

    if args.mode == "web":
        capture_with_chrome(args, input_dir, output_dir)
        print("Done.")
        return 0

    if apk_path is None:
        apk_path = latest_apk()

    adb = find_adb()
    serial = choose_device(adb, args.device)
    width, height = get_screen_size(adb, serial)
    device = Device(adb=adb, serial=serial, width=width, height=height)

    print(f"ADB: {adb}")
    print(f"Device: {serial or 'default'}")
    print(f"Screen size: {width}x{height}")
    print(f"Screenshots: {input_dir}")
    print(f"Mockups: {output_dir}")

    prepare_device(device, args.package, force_portrait=not args.no_force_portrait)

    if not args.no_install:
        install_apk(device, apk_path)

    if args.fresh_data:
        print(f"Clearing local app data for {args.package}...")
        run(device.adb, ["shell", "pm", "clear", args.package], serial=device.serial, timeout=30)

    launch_app(device, args.package)
    capture(device, input_dir / "00_loading.png")
    print("Waiting for the 5 second loading screen...")
    time.sleep(5.5)

    effective_auth_flow = args.auth_flow
    if args.fresh_data and effective_auth_flow == "auto":
        effective_auth_flow = "signup"

    authenticate(
        device,
        input_dir,
        auth_flow=effective_auth_flow,
        username=args.username,
        password=args.password,
        full_name=args.full_name,
    )

    if not text_exists(device, ["Show Stats", "Connected to ESP32", "No Connection"]):
        print("Warning: home screen was not detected. Continuing with the capture flow.")

    capture_main_screens(device, input_dir)
    run_mockup_script(args, input_dir, output_dir)
    print("Done.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        command = " ".join(str(part) for part in exc.cmd)
        print(f"Command failed: {command}", file=sys.stderr)
        if exc.stdout:
            print(exc.stdout, file=sys.stderr)
        if exc.stderr:
            print(exc.stderr, file=sys.stderr)
        raise SystemExit(1)
    except CaptureError as exc:
        print(f"Capture failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
