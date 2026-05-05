"""Capture EcoSystem Controller app screens and generate phone mockups.

Run modes:
  --mode web   Build and open the Flutter app in Chrome, capture with Playwright
  --mode adb   Install the APK on a connected Android device, capture via ADB

Example:
    python capture_app_screens.py --mode web
    python capture_app_screens.py --mode adb --device emulator-5554
    python capture_app_screens.py --dry-run
"""
from __future__ import annotations

import argparse
import subprocess
import sys

from capture_common import (
    DEFAULT_INPUT_DIR,
    DEFAULT_OUTPUT_DIR,
    CaptureError,
    clean_image_folder,
    choose_device,
    find_adb,
    get_screen_size,
    latest_apk,
    read_application_id,
    resolve_project_path,
    run_mockup_script,
    Device,
)
from capture_adb import (
    authenticate,
    capture,
    capture_main_screens,
    install_apk,
    launch_app,
    prepare_device,
    text_exists,
)
from capture_web import capture_with_chrome


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Capture EcoSystem Controller app screens with Chrome or ADB, "
            "save them to mockup/input, then generate phone mockups in mockup/output."
        )
    )
    parser.add_argument("--mode", choices=["web", "adb"], default="web",
                        help="Capture mode. Default: web (Flutter app in Chrome).")
    parser.add_argument("--apk", help="APK path. Default: latest APK inside apk_builds.")
    parser.add_argument("--package", default=read_application_id(), help="Android application id.")
    parser.add_argument("--device", help="ADB device serial (required when multiple devices are connected).")
    parser.add_argument("--no-install", action="store_true", help="Do not install the APK before capture.")
    parser.add_argument("--fresh-data", action="store_true",
                        help="Clear app local data before capture (makes first-time signup automatic).")
    parser.add_argument("--auth-flow", choices=["auto", "signup", "login", "skip"], default="auto",
                        help="Authentication mode. Use skip if app is already on the home screen.")
    parser.add_argument("--username", default="ecoDemo", help="Demo username for signup/login.")
    parser.add_argument("--password", default="ecoDemo1234", help="Demo password for signup/login.")
    parser.add_argument("--full-name", default="EcoSmartDemo", help="Demo display name for signup.")
    parser.add_argument("--input", default=str(DEFAULT_INPUT_DIR), help="Screenshot output folder.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT_DIR), help="Mockup output folder.")
    parser.add_argument("--clear", action="store_true", help="Delete old images from input/output first.")
    parser.add_argument("--no-force-portrait", action="store_true", help="Do not force portrait orientation.")
    parser.add_argument("--no-mockup", action="store_true", help="Only capture screenshots; skip mockup generation.")
    parser.add_argument("--fit", choices=["cover", "contain"], default="cover", help="Mockup image fit mode.")
    parser.add_argument("--background", choices=["dark", "green", "light"], default="dark", help="Mockup background.")
    parser.add_argument("--phone", choices=["black", "green", "silver"], default="black", help="Phone frame color.")
    # Web-only options
    parser.add_argument("--web-host", default="127.0.0.1", help="Flutter web server host.")
    parser.add_argument("--web-port", type=int, default=0, help="Flutter web server port (0 = find free).")
    parser.add_argument("--web-width", type=int, default=390, help="Chrome viewport width.")
    parser.add_argument("--web-height", type=int, default=844, help="Chrome viewport height.")
    parser.add_argument("--device-scale-factor", type=float, default=3.0, help="Chrome device scale factor.")
    parser.add_argument("--browser-channel", default="chrome", help="Browser channel: chrome, msedge, or bundled.")
    parser.add_argument("--headless", action="store_true", help="Run Chrome without a visible window.")
    parser.add_argument("--skip-pub-get", action="store_true", help="Skip flutter pub get before web start.")
    parser.add_argument("--skip-web-build", action="store_true", help="Reuse the existing build/web folder.")
    parser.add_argument("--web-build-mode", choices=["debug", "profile", "release"], default="release",
                        help="Flutter web build mode.")
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
        from capture_common import PROJECT_ROOT
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

    # ADB mode
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
        from capture_common import run
        print(f"Clearing local app data for {args.package}...")
        run(device.adb, ["shell", "pm", "clear", args.package], serial=device.serial, timeout=30)

    launch_app(device, args.package)
    capture(device, input_dir / "00_loading.png")
    print("Waiting for the 5 second loading screen...")
    import time
    time.sleep(5.5)

    effective_auth_flow = args.auth_flow
    if args.fresh_data and effective_auth_flow == "auto":
        effective_auth_flow = "signup"

    authenticate(device, input_dir,
                 auth_flow=effective_auth_flow,
                 username=args.username,
                 password=args.password,
                 full_name=args.full_name)

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
