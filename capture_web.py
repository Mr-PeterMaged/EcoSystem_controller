"""Chrome/Playwright capture helpers for capture_app_screens.py."""
from __future__ import annotations

import io
import subprocess
import sys
import time
from pathlib import Path

from capture_common import (
    BrowserTarget,
    CaptureError,
    LOCAL_PYTHON_DEPS,
    PROJECT_ROOT,
    configure_local_runtime_temp,
    find_flutter,
    find_free_port,
    port_is_open,
    start_log_reader,
    stop_process_tree,
    tool_command,
)


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
        sys.executable, "-m", "http.server", str(port),
        "--bind", host, "--directory", str(web_dir),
    ]
    print(f"Starting local Chrome preview server: {url}")
    import os
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


def launch_browser(sync_playwright, args):
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


# ── Page interaction helpers ──────────────────────────────────────────────────

def browser_tap(page, target: BrowserTarget, x_ratio: float, y_ratio: float, label: str = "") -> None:
    x = round(target.width * x_ratio)
    y = round(target.height * y_ratio)
    if label:
        print(f"Browser tap {label}: {x},{y}")
    page.mouse.click(x, y)
    page.wait_for_timeout(350)


def browser_type(page, target: BrowserTarget, x_ratio: float, y_ratio: float, value: str, label: str = "") -> None:
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


# ── Auth + screen flows ───────────────────────────────────────────────────────

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


def browser_authenticate(page, target: BrowserTarget, input_dir: Path, *, auth_flow: str, username: str, password: str, full_name: str) -> None:
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


# ── Main Chrome capture flow ──────────────────────────────────────────────────

def capture_with_chrome(args, input_dir: Path, output_dir: Path) -> None:
    from capture_common import run_mockup_script
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
            page, target, input_dir,
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
