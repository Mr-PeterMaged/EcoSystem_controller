"""Build the Flutter project as an APK and copy it into the project folder.

Run from the project root:

    python build_apk.py

The script:
- includes the selected logo in Android resources,
- points the APK launcher icon to that logo,
- cleans stale Flutter build cache,
- runs `flutter pub get`,
- runs `flutter build apk --release`,
- copies the APK to `apk_builds/`,
- shows a progress bar with elapsed time and estimated remaining time.
"""

from __future__ import annotations

import argparse
import os
import re
import stat
import shutil
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
DEFAULT_LOGO = PROJECT_ROOT / "Logo" / "dark_mode.png"
ANDROID_MANIFEST = (
    PROJECT_ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
)
ANDROID_DRAWABLE_DIR = PROJECT_ROOT / "android" / "app" / "src" / "main" / "res" / "drawable"
ANDROID_LOGO_RESOURCE = ANDROID_DRAWABLE_DIR / "app_logo.png"
ANDROID_GRADLE_WRAPPER = PROJECT_ROOT / "android" / "gradlew.bat"
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "apk_builds"
LOCAL_BUILD_CACHE = PROJECT_ROOT / ".build_cache"
MAX_GRADLE_REPAIR_ATTEMPTS = 8


class BuildError(RuntimeError):
    """Raised when a build step fails."""


class ProgressBar:
    def __init__(self, total_weight: int) -> None:
        self.total_weight = total_weight
        self.done_weight = 0.0
        self.step_weight = 0.0
        self.step_estimate = 1.0
        self.step_name = "Starting"
        self.step_start = time.time()
        self.start_time = time.time()
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        self._thread = threading.Thread(target=self._render_loop, daemon=True)
        self._thread.start()

    def stop(self, success: bool = True) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=1)
        self._render(final=success)
        print()

    def begin_step(self, name: str, weight: int, estimate_seconds: int) -> None:
        with self._lock:
            self.step_name = name
            self.step_weight = float(weight)
            self.step_estimate = max(1.0, float(estimate_seconds))
            self.step_start = time.time()

    def complete_step(self) -> None:
        with self._lock:
            self.done_weight += self.step_weight
            self.step_weight = 0.0
            self.step_estimate = 1.0
            self.step_start = time.time()

    def _current_progress(self) -> tuple[float, float, str]:
        with self._lock:
            elapsed_step = time.time() - self.step_start
            step_ratio = min(0.95, elapsed_step / self.step_estimate)
            current = self.done_weight + (self.step_weight * step_ratio)
            percent = min(99.0, (current / self.total_weight) * 100)
            remaining_weight = max(0.0, self.total_weight - current)
            speed = current / max(1.0, time.time() - self.start_time)
            eta = remaining_weight / speed if speed > 0 else 0.0
            return percent, eta, self.step_name

    def _render_loop(self) -> None:
        while not self._stop.is_set():
            self._render()
            time.sleep(0.5)

    def _render(self, final: bool = False) -> None:
        if final:
            percent = 100.0
            eta = 0.0
            step_name = "Done"
        else:
            percent, eta, step_name = self._current_progress()

        elapsed = time.time() - self.start_time
        width = 30
        filled = int(width * percent / 100)
        bar = "#" * filled + "-" * (width - filled)
        message = (
            f"\r[{bar}] {percent:5.1f}% | "
            f"elapsed {format_time(elapsed)} | "
            f"eta {format_time(eta)} | {step_name[:34]:34}"
        )
        print(message, end="", flush=True)


def format_time(seconds: float) -> str:
    seconds = max(0, int(seconds))
    minutes, sec = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    if hours:
        return f"{hours:d}:{minutes:02d}:{sec:02d}"
    return f"{minutes:02d}:{sec:02d}"


def resolve_flutter_command(flutter_arg: str | None = None) -> list[str]:
    flutter_path = flutter_arg or shutil.which("flutter")
    if flutter_path is None:
        raise BuildError(
            "Flutter was not found in PATH. Install Flutter or open a terminal "
            "where the `flutter` command works. You can also pass it manually, "
            "for example: python build_apk.py --flutter C:\\src\\flutter\\bin\\flutter.bat"
        )

    flutter_path = str(Path(flutter_path).resolve())
    if not Path(flutter_path).exists():
        raise BuildError(f"Flutter executable was not found: {flutter_path}")

    if os.name == "nt" and flutter_path.lower().endswith((".bat", ".cmd")):
        return ["cmd", "/c", flutter_path]
    return [flutter_path]


def ensure_logo_in_apk(logo_path: Path) -> None:
    if not logo_path.exists():
        raise BuildError(f"Logo file not found: {logo_path}")
    if not ANDROID_MANIFEST.exists():
        raise BuildError(f"AndroidManifest.xml not found: {ANDROID_MANIFEST}")

    ANDROID_DRAWABLE_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(logo_path, ANDROID_LOGO_RESOURCE)

    manifest = ANDROID_MANIFEST.read_text(encoding="utf-8")
    updated, replacements = re.subn(
        r'android:icon="@[^"]+"',
        'android:icon="@drawable/app_logo"',
        manifest,
        count=1,
    )
    if replacements == 0:
        updated, replacements = re.subn(
            r"(<application\b)",
            r'\1 android:icon="@drawable/app_logo"',
            manifest,
            count=1,
        )
    if replacements == 0:
        raise BuildError("Could not find <application> in AndroidManifest.xml")
    ANDROID_MANIFEST.write_text(updated, encoding="utf-8")


def run_command(
    command: list[str],
    log_file: Path,
    progress: ProgressBar,
    step_name: str,
    step_weight: int,
    estimate_seconds: int,
    env: dict[str, str],
) -> None:
    progress.begin_step(step_name, step_weight, estimate_seconds)

    with log_file.open("a", encoding="utf-8", errors="replace") as log:
        log.write(f"\n\n$ {' '.join(command)}\n")
        log.flush()
        try:
            process = subprocess.Popen(
                command,
                cwd=PROJECT_ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                env=env,
                bufsize=1,
            )
        except OSError as exc:
            raise BuildError(
                f"Could not start command: {' '.join(command)}\n{exc}"
            ) from exc

        assert process.stdout is not None
        for line in process.stdout:
            log.write(line)
            log.flush()

        return_code = process.wait()

    if return_code != 0:
        raise BuildError(
            f"Command failed: {' '.join(command)}\n"
            f"Open the build log for details: {log_file}"
        )

    progress.complete_step()


def copy_final_apk(build_mode: str, output_dir: Path, output_name: str) -> Path:
    source_name = "app-release.apk" if build_mode == "release" else "app-debug.apk"
    source = PROJECT_ROOT / "build" / "app" / "outputs" / "flutter-apk" / source_name
    if not source.exists():
        raise BuildError(f"Flutter build completed, but APK was not found: {source}")

    output_dir.mkdir(parents=True, exist_ok=True)
    destination = output_dir / output_name
    shutil.copy2(source, destination)
    return destination


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build this Flutter app into an APK.")
    parser.add_argument(
        "--mode",
        choices=["release", "debug"],
        default="release",
        help="APK build mode. Default: release",
    )
    parser.add_argument(
        "--logo",
        default=str(DEFAULT_LOGO),
        help="Logo PNG to include as the Android launcher icon.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help="Folder where the APK will be copied.",
    )
    parser.add_argument(
        "--name",
        default="smart_home_self_powered.apk",
        help="Final APK file name.",
    )
    parser.add_argument(
        "--skip-pub-get",
        action="store_true",
        help="Skip `flutter pub get` before building.",
    )
    parser.add_argument(
        "--no-clean",
        action="store_true",
        help="Skip `flutter clean` before building.",
    )
    parser.add_argument(
        "--flutter",
        help="Path to flutter or flutter.bat if it is not available in PATH.",
    )
    parser.add_argument(
        "--system-cache",
        action="store_true",
        help="Use the system Gradle/Pub/TEMP cache instead of project-local cache.",
    )
    parser.add_argument(
        "--target-platform",
        default="android-arm64",
        help=(
            "Android target platform. Default: android-arm64. "
            "Use android-arm,android-arm64,android-x64 for a universal APK."
        ),
    )
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Do not run upload.py after a successful build.",
    )
    return parser.parse_args()


def build_environment(use_system_cache: bool) -> dict[str, str]:
    env = os.environ.copy()
    gradle_opts = env.get("GRADLE_OPTS", "").strip()
    stability_opts = " ".join(
        [
            "-Dorg.gradle.daemon=false",
            "-Dorg.gradle.parallel=false",
            "-Dorg.gradle.caching=false",
            "-Dorg.gradle.workers.max=1",
            "-Dkotlin.incremental=false",
        ]
    )
    env["GRADLE_OPTS"] = " ".join(
        part for part in (gradle_opts, stability_opts) if part
    )
    if use_system_cache:
        return env

    gradle_cache = LOCAL_BUILD_CACHE / "gradle"
    pub_cache = LOCAL_BUILD_CACHE / "pub"
    temp_dir = LOCAL_BUILD_CACHE / "tmp"
    for path in (gradle_cache, pub_cache, temp_dir):
        path.mkdir(parents=True, exist_ok=True)

    env["GRADLE_USER_HOME"] = str(gradle_cache)
    env["PUB_CACHE"] = str(pub_cache)
    env["TEMP"] = str(temp_dir)
    env["TMP"] = str(temp_dir)
    write_local_gradle_properties(gradle_cache)
    return env


def write_local_gradle_properties(gradle_cache: Path) -> None:
    properties = gradle_cache / "gradle.properties"
    properties.write_text(
        "\n".join(
            [
                "org.gradle.daemon=false",
                "org.gradle.parallel=false",
                "org.gradle.caching=false",
                "org.gradle.workers.max=1",
                "kotlin.incremental=false",
                "",
            ]
        ),
        encoding="utf-8",
    )


def safe_rmtree(path: Path, allowed_root: Path) -> None:
    if not path.exists():
        return

    resolved_path = path.resolve()
    assert_path_inside(resolved_path, allowed_root, "delete")
    if resolved_path == allowed_root.resolve():
        raise BuildError(f"Refusing to delete unsafe path: {resolved_path}")

    def handle_remove_error(
        function: object, failed_path: str, _exc_info: object
    ) -> None:
        try:
            os.chmod(failed_path, stat.S_IWRITE)
            function(failed_path)
        except OSError:
            pass

    shutil.rmtree(resolved_path, onerror=handle_remove_error)


def assert_path_inside(path: Path, allowed_root: Path, action: str) -> None:
    resolved_path = path.resolve()
    resolved_root = allowed_root.resolve()
    if resolved_path != resolved_root and resolved_root in resolved_path.parents:
        return
    raise BuildError(f"Refusing to {action} unsafe path: {resolved_path}")


def stop_gradle_daemons(log_file: Path, env: dict[str, str]) -> None:
    if not ANDROID_GRADLE_WRAPPER.exists():
        return

    command = ["cmd", "/c", str(ANDROID_GRADLE_WRAPPER), "--stop"]
    with log_file.open("a", encoding="utf-8", errors="replace") as log:
        log.write(f"\n\n$ {' '.join(command)}\n")
        log.flush()
        try:
            subprocess.run(
                command,
                cwd=PROJECT_ROOT / "android",
                stdout=log,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                env=env,
                timeout=90,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            log.write(f"Could not stop Gradle daemons, continuing: {exc}\n")
        log.flush()


def reset_gradle_runtime_state(use_system_cache: bool) -> None:
    safe_rmtree(PROJECT_ROOT / ".gradle", PROJECT_ROOT)
    safe_rmtree(PROJECT_ROOT / "android" / ".gradle", PROJECT_ROOT)

    if use_system_cache:
        return

    gradle_cache = LOCAL_BUILD_CACHE / "gradle"
    caches_root = gradle_cache / "caches"
    if caches_root.exists():
        for path in caches_root.glob("*/transforms*"):
            safe_rmtree(path, gradle_cache)

    safe_rmtree(gradle_cache / "daemon", gradle_cache)
    safe_rmtree(gradle_cache / "workers", gradle_cache)


def repair_gradle_transform_moves(log_file: Path) -> int:
    if not log_file.exists():
        return 0

    pattern = re.compile(
        r"Could not move temporary workspace \(([^)]+)\) "
        r"to immutable location \(([^)]+)\)"
    )
    matches = pattern.findall(log_file.read_text(encoding="utf-8", errors="replace"))
    repaired = 0
    seen: set[tuple[str, str]] = set()
    gradle_cache = LOCAL_BUILD_CACHE / "gradle"

    with log_file.open("a", encoding="utf-8", errors="replace") as log:
        for temporary_raw, target_raw in matches:
            key = (temporary_raw, target_raw)
            if key in seen:
                continue
            seen.add(key)

            temporary = Path(temporary_raw)
            target = Path(target_raw)
            assert_path_inside(temporary, gradle_cache, "repair")
            assert_path_inside(target, gradle_cache, "repair")

            if not temporary.exists():
                continue

            if target.exists():
                safe_rmtree(temporary, gradle_cache)
                log.write(f"Removed duplicate Gradle workspace: {temporary}\n")
                repaired += 1
                continue

            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(temporary), str(target))
            log.write(f"Moved Gradle workspace: {temporary} -> {target}\n")
            repaired += 1
        log.flush()

    return repaired


def run_build_with_gradle_repair(
    build_command: list[str],
    log_file: Path,
    progress: ProgressBar,
    step_name: str,
    step_weight: int,
    estimate_seconds: int,
    env: dict[str, str],
) -> None:
    last_error: BuildError | None = None

    for attempt in range(1, MAX_GRADLE_REPAIR_ATTEMPTS + 1):
        display_name = step_name if attempt == 1 else f"{step_name} retry {attempt}"
        try:
            run_command(
                build_command,
                log_file,
                progress,
                display_name,
                step_weight,
                estimate_seconds,
                env,
            )
            return
        except BuildError as exc:
            last_error = exc
            repaired = repair_gradle_transform_moves(log_file)
            if repaired == 0 or attempt == MAX_GRADLE_REPAIR_ATTEMPTS:
                raise

            with log_file.open("a", encoding="utf-8", errors="replace") as log:
                log.write(
                    f"Repaired {repaired} Gradle transform workspace(s); "
                    f"retrying build attempt {attempt + 1}.\n"
                )
                log.flush()
            stop_gradle_daemons(log_file, env)

    if last_error is not None:
        raise last_error


def describe_disk_space(path: Path) -> str:
    usage = shutil.disk_usage(path)
    free_gb = usage.free / (1024**3)
    total_gb = usage.total / (1024**3)
    return f"{free_gb:.1f} GB free / {total_gb:.1f} GB total"


def _run_upload() -> None:
    upload_py = PROJECT_ROOT / "upload.py"
    if not upload_py.exists():
        print("upload.py not found — skipping upload step.")
        return
    print(f"\n{'─' * 50}")
    print("Running upload.py ...")
    print(f"{'─' * 50}")
    subprocess.run(
        [sys.executable, str(upload_py)],
        cwd=PROJECT_ROOT,
        check=False,
    )


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output_dir)
    if not output_dir.is_absolute():
        output_dir = PROJECT_ROOT / output_dir

    log_dir = PROJECT_ROOT / "build_logs"
    log_dir.mkdir(exist_ok=True)
    log_file = log_dir / f"apk_build_{datetime.now():%Y%m%d_%H%M%S}.log"

    steps = [
        ("Preparing logo and Android resources", 10, 10),
        ("Cleaning stale Flutter build cache", 10, 30),
        ("Running flutter pub get", 15, 45),
        ("Preparing Gradle cache", 5, 10),
        (f"Building {args.mode} APK", 65, 240 if args.mode == "release" else 120),
        ("Copying APK to project folder", 5, 5),
    ]
    if args.no_clean:
        steps.pop(1)
    if args.skip_pub_get:
        steps = [step for step in steps if step[0] != "Running flutter pub get"]
    total_weight = sum(step[1] for step in steps)
    progress = ProgressBar(total_weight)

    try:
        flutter_command = resolve_flutter_command(args.flutter)
        command_env = build_environment(args.system_cache)

        print(f"Project: {PROJECT_ROOT}")
        print(f"Log file: {log_file}")
        print(f"Flutter: {' '.join(flutter_command)}")
        print(f"Target platform: {args.target_platform}")
        if args.system_cache:
            print("Cache: system default")
        else:
            print(f"Cache: {LOCAL_BUILD_CACHE}")
        print(f"Project drive space: {describe_disk_space(PROJECT_ROOT)}")
        progress.start()

        name, weight, estimate = steps[0]
        progress.begin_step(name, weight, estimate)
        ensure_logo_in_apk(Path(args.logo).resolve())
        progress.complete_step()

        if not args.no_clean:
            run_command(
                [*flutter_command, "clean"],
                log_file,
                progress,
                "Cleaning stale Flutter build cache",
                10,
                30,
                command_env,
            )

        if not args.skip_pub_get:
            run_command(
                [*flutter_command, "pub", "get"],
                log_file,
                progress,
                "Running flutter pub get",
                15,
                45,
                command_env,
            )

        progress.begin_step("Preparing Gradle cache", 5, 10)
        stop_gradle_daemons(log_file, command_env)
        reset_gradle_runtime_state(args.system_cache)
        progress.complete_step()

        build_command = [
            *flutter_command,
            "build",
            "apk",
            f"--{args.mode}",
            f"--target-platform={args.target_platform}",
        ]

        run_build_with_gradle_repair(
            build_command,
            log_file,
            progress,
            f"Building {args.mode} APK",
            65,
            240 if args.mode == "release" else 120,
            command_env,
        )

        progress.begin_step("Copying APK to project folder", 5, 5)
        apk_path = copy_final_apk(args.mode, output_dir, args.name)
        progress.complete_step()
        progress.stop(success=True)

        size_mb = apk_path.stat().st_size / (1024 * 1024)
        print(f"APK saved to: {apk_path}")
        print(f"APK size: {size_mb:.2f} MB")
        print(f"Build log: {log_file}")

        if not args.skip_upload:
            _run_upload()

        return 0
    except KeyboardInterrupt:
        progress.stop(success=False)
        print("Build cancelled.")
        return 130
    except BuildError as exc:
        progress.stop(success=False)
        print(f"Build failed: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
