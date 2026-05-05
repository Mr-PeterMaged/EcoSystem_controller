"""ADB/Android device capture helpers for capture_app_screens.py."""
from __future__ import annotations

import time
import xml.etree.ElementTree as ET
import re
from pathlib import Path

from capture_common import (
    CaptureError,
    Device,
    run,
)


# ── Low-level input ───────────────────────────────────────────────────────────

def tap(device: Device, x_ratio: float, y_ratio: float, label: str = "") -> None:
    x = round(device.width * x_ratio)
    y = round(device.height * y_ratio)
    if label:
        print(f"Tap {label}: {x},{y}")
    run(device.adb, ["shell", "input", "tap", str(x), str(y)], serial=device.serial, timeout=20)
    time.sleep(0.35)


def swipe(device: Device, start: tuple[float, float], end: tuple[float, float], *, duration_ms: int = 350) -> None:
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


def tap_type(device: Device, x_ratio: float, y_ratio: float, value: str, *, clear: bool = True, label: str = "") -> None:
    tap(device, x_ratio, y_ratio, label or "field")
    if clear:
        clear_focused_text(device)
    input_text(device, value)


# ── Screenshot ────────────────────────────────────────────────────────────────

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


# ── UI hierarchy helpers ──────────────────────────────────────────────────────

def dump_ui(device: Device) -> str:
    run(device.adb, ["shell", "uiautomator", "dump", "/sdcard/window.xml"], serial=device.serial, check=False, timeout=20)
    result = run(device.adb, ["exec-out", "cat", "/sdcard/window.xml"], serial=device.serial, check=False, text=False, timeout=20)
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
        run(device.adb, ["shell", "input", "tap", str(center[0]), str(center[1])], serial=device.serial, timeout=20)
        print(f"Tap text '{text_value}': {center[0]},{center[1]}")
        time.sleep(0.45)
        return True
    return False


def tap_text_or_fallback(device: Device, needles: list[str], fallback: tuple[float, float], label: str) -> None:
    if tap_text(device, needles):
        return
    tap(device, fallback[0], fallback[1], label)


# ── Navigation helpers ────────────────────────────────────────────────────────

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


# ── Auth flow ─────────────────────────────────────────────────────────────────

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


def authenticate(device: Device, input_dir: Path, *, auth_flow: str, username: str, password: str, full_name: str) -> None:
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


# ── Main screen capture flow ──────────────────────────────────────────────────

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
