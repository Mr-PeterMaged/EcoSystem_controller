"""
mockup_gen.py — Flutter App Screenshot Mockup Generator

Two ways to get screenshots:
  A) Manual : Save PNG/JPG files into  mockup/input/  then run the script
  B) Auto   : Run with --capture to pull a live screenshot from the
              connected Android device or emulator via ADB

Usage:
    python mockup_gen.py                  # process mockup/input/ folder
    python mockup_gen.py --capture        # grab screenshot from device then process
    python mockup_gen.py --bg dark        # dark background
    python mockup_gen.py --bg white       # white background
    python mockup_gen.py --phone silver   # silver phone frame
    python mockup_gen.py --scale 0.75     # shrink output to 75%

Background choices : light (default) | dark | white | black | blue | purple
Phone frame colors : black (default) | silver | blue | gold
Requires: Pillow  ->  pip install Pillow
Optional: ADB in PATH for --capture mode
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

# ── Folder layout ─────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent
MOCKUP_DIR   = PROJECT_ROOT / "mockup"
INPUT_DIR    = MOCKUP_DIR / "input"
OUTPUT_DIR   = MOCKUP_DIR / "output"
SUPPORTED    = {".png", ".jpg", ".jpeg", ".webp"}
# ─────────────────────────────────────────────────────────────────────────────


# ── Phone frame dimensions ────────────────────────────────────────────────────
PHONE_W    = 460           # phone body width  (px)
PHONE_H    = 940           # phone body height (px)
CORNER_R   = 54            # rounded corner radius
BEZEL_X    = 16            # left/right bezel  (thin modern bezels)
BEZEL_TOP  = 58            # top bezel height
BEZEL_BOT  = 60            # bottom bezel height
FRAME_T    = 5             # metallic outer frame thickness
SHADOW_P   = 60            # canvas padding for drop-shadow
SCREEN_W   = PHONE_W - 2 * BEZEL_X          # 428
SCREEN_H   = PHONE_H - BEZEL_TOP - BEZEL_BOT  # 822
SCREEN_R   = 14            # screen corner radius
# ─────────────────────────────────────────────────────────────────────────────


# ── Color palettes ────────────────────────────────────────────────────────────
PHONE_COLORS = {
    "black":  dict(body=(20, 20, 23),   frame=(55, 55, 62),   btn=(48, 48, 54)),
    "silver": dict(body=(195, 198, 205), frame=(210, 213, 220), btn=(175, 178, 185)),
    "blue":   dict(body=(28, 42, 75),   frame=(55, 75, 130),  btn=(42, 60, 100)),
    "gold":   dict(body=(120, 90, 45),  frame=(185, 150, 80), btn=(100, 75, 38)),
}

BG_STYLES = {
    "light":  ((228, 238, 255), (195, 215, 245)),
    "dark":   ((15, 20, 35),    (8,  12, 24)),
    "white":  ((255, 255, 255), (240, 240, 245)),
    "black":  ((10, 10, 12),    (5,  5,  8)),
    "blue":   ((30, 50, 120),   (10, 20, 70)),
    "purple": ((60, 20, 90),    (25, 8,  45)),
}


def _gradient(w: int, h: int, top: tuple, bottom: tuple) -> Image.Image:
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        px[0, y] = (
            round(top[0] + t * (bottom[0] - top[0])),
            round(top[1] + t * (bottom[1] - top[1])),
            round(top[2] + t * (bottom[2] - top[2])),
        )
    return strip.resize((w, h), Image.NEAREST).convert("RGBA")
# ─────────────────────────────────────────────────────────────────────────────


# ── ADB screenshot capture ────────────────────────────────────────────────────
def _adb_available() -> bool:
    try:
        r = subprocess.run(["adb", "version"], capture_output=True, timeout=5)
        return r.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _adb_device_connected() -> bool:
    try:
        r = subprocess.run(["adb", "devices"], capture_output=True, text=True, timeout=8)
        lines = [l.strip() for l in r.stdout.splitlines() if l.strip()]
        # Any line after "List of devices attached" that ends with "device" means connected
        return any(l.endswith("device") for l in lines[1:])
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def capture_from_device(out_path: Path) -> bool:
    """
    Pull a screenshot from the connected Android device or emulator via ADB.
    Returns True on success.
    """
    if not _adb_available():
        print("  ADB not found. Install Android SDK Platform-Tools and add to PATH.")
        return False
    if not _adb_device_connected():
        print("  No Android device / emulator connected.")
        print("  Connect your phone with USB debugging enabled, or start an emulator.")
        return False

    print("  Capturing screenshot via ADB ...")
    try:
        result = subprocess.run(
            ["adb", "exec-out", "screencap", "-p"],
            capture_output=True,
            timeout=20,
        )
        if result.returncode == 0 and result.stdout:
            out_path.write_bytes(result.stdout)
            size_kb = len(result.stdout) // 1024
            print(f"  Captured: {out_path.name}  ({size_kb} KB)")
            return True
        print(f"  ADB screencap failed (exit {result.returncode}).")
        return False
    except subprocess.TimeoutExpired:
        print("  ADB capture timed out.")
        return False
# ─────────────────────────────────────────────────────────────────────────────


# ── Phone frame builder ───────────────────────────────────────────────────────
def _build_frame(phone_key: str = "black") -> tuple[Image.Image, tuple[int, int]]:
    """
    Draw the full phone shell onto a transparent canvas.

    Returns:
        frame       – RGBA canvas (screen area is transparent)
        screen_xy   – (x, y) top-left of the screen on this canvas
    """
    pal = PHONE_COLORS[phone_key]
    body_c   = (*pal["body"],  255)
    frame_c  = (*pal["frame"], 255)
    btn_c    = (*pal["btn"],   255)

    W = PHONE_W + 2 * SHADOW_P
    H = PHONE_H + 2 * SHADOW_P
    PX, PY = SHADOW_P, SHADOW_P

    # ── 1. Drop shadow (multi-layer for softness)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for offset, alpha in ((10, 60), (6, 45), (3, 30)):
        sd.rounded_rectangle(
            [PX + offset, PY + offset * 2,
             PX + PHONE_W - offset, PY + PHONE_H - offset // 2],
            radius=CORNER_R,
            fill=(0, 0, 0, alpha),
        )
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))

    # ── 2. Metallic outer frame
    outer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(outer)
    od.rounded_rectangle(
        [PX, PY, PX + PHONE_W, PY + PHONE_H],
        radius=CORNER_R,
        fill=frame_c,
    )

    # ── 3. Phone body (slightly inset from the metallic frame)
    body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle(
        [PX + FRAME_T, PY + FRAME_T,
         PX + PHONE_W - FRAME_T, PY + PHONE_H - FRAME_T],
        radius=max(CORNER_R - FRAME_T, 2),
        fill=body_c,
    )

    # Top-edge highlight (simulates glass shine)
    bd.rounded_rectangle(
        [PX + FRAME_T + 2, PY + FRAME_T + 2,
         PX + PHONE_W - FRAME_T - 2, PY + FRAME_T + 8],
        radius=max(CORNER_R - FRAME_T, 2),
        fill=(255, 255, 255, 28),
    )

    # ── 4. Punch-hole camera
    cx, cy = PX + PHONE_W // 2, PY + 30
    for r, col in [(11, (5, 5, 5, 255)), (7, (18, 18, 22, 255)), (3, (35, 35, 40, 255))]:
        bd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

    # ── 5. Home indicator
    iw, ih = 140, 5
    ix = PX + (PHONE_W - iw) // 2
    iy = PY + PHONE_H - 20
    bd.rounded_rectangle([ix, iy, ix + iw, iy + ih], radius=3,
                          fill=(255, 255, 255, 140))

    # ── 6. Side buttons
    # Left — mute switch + volume up + volume down
    for by, bh in ((PY + 160, 30), (PY + 210, 70), (PY + 300, 70)):
        bd.rounded_rectangle([PX - 9, by, PX - 2, by + bh], radius=4, fill=btn_c)
    # Right — power button
    bd.rounded_rectangle(
        [PX + PHONE_W + 2, PY + 230, PX + PHONE_W + 9, PY + 330],
        radius=4, fill=btn_c,
    )

    # Composite: shadow -> metallic frame -> body
    canvas = Image.alpha_composite(shadow, outer)
    canvas = Image.alpha_composite(canvas, body)

    # ── 7. Cut a transparent hole for the screen
    mask = Image.new("L", (W, H), 255)
    md = ImageDraw.Draw(mask)
    sx, sy = PX + BEZEL_X, PY + BEZEL_TOP
    md.rounded_rectangle([sx, sy, sx + SCREEN_W, sy + SCREEN_H],
                          radius=SCREEN_R, fill=0)
    canvas.putalpha(mask)

    return canvas, (sx, sy)
# ─────────────────────────────────────────────────────────────────────────────


# ── Main compositor ───────────────────────────────────────────────────────────
def apply_mockup(
    screenshot: Image.Image,
    bg_style: str = "light",
    phone_key: str = "black",
) -> Image.Image:
    frame, (sx, sy) = _build_frame(phone_key)
    W, H = frame.size

    # Scale screenshot to fill the screen area exactly
    shot = screenshot.convert("RGBA").resize((SCREEN_W, SCREEN_H), Image.LANCZOS)

    # Clip screenshot corners to match screen curve
    scr_mask = Image.new("L", (SCREEN_W, SCREEN_H), 0)
    ImageDraw.Draw(scr_mask).rounded_rectangle(
        [0, 0, SCREEN_W, SCREEN_H], radius=SCREEN_R, fill=255
    )
    shot.putalpha(scr_mask)

    # Background
    top, bottom = BG_STYLES.get(bg_style, BG_STYLES["light"])
    canvas = _gradient(W, H, top, bottom)

    # Layer 1 — background gradient
    # Layer 2 — screenshot (behind the frame)
    canvas.paste(shot, (sx, sy), shot)

    # Layer 3 — phone frame (screen hole lets screenshot show through)
    canvas = Image.alpha_composite(canvas, frame)

    # Layer 4 — subtle screen glare
    glare = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glare).polygon(
        [
            (sx + 20, sy + 20),
            (sx + SCREEN_W // 4, sy + 20),
            (sx + 20, sy + SCREEN_H // 6),
        ],
        fill=(255, 255, 255, 14),
    )
    canvas = Image.alpha_composite(canvas, glare)

    return canvas.convert("RGB")
# ─────────────────────────────────────────────────────────────────────────────


# ── Batch processor ───────────────────────────────────────────────────────────
def process_all(
    bg_style: str = "light",
    phone_key: str = "black",
    scale: float = 1.0,
    capture: bool = False,
) -> None:
    INPUT_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # --capture: grab a live screenshot from connected device
    if capture:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        cap_path = INPUT_DIR / f"capture_{ts}.png"
        print("Capturing from device ...")
        if not capture_from_device(cap_path):
            print("Capture failed. Falling back to manual input folder.")

    # Collect all images from input folder
    images = sorted(p for p in INPUT_DIR.iterdir() if p.suffix.lower() in SUPPORTED)

    if not images:
        print(f"\nNo images found in: {INPUT_DIR}")
        print("-> Place your screenshots there, then run again.")
        print("-> Or run with --capture to grab directly from a connected device.")
        return

    phone_label = phone_key.capitalize()
    print(
        f"\nFound {len(images)} screenshot(s) | "
        f"bg: {bg_style} | phone: {phone_label} | scale: {scale}"
    )
    print(f"Output -> {OUTPUT_DIR}\n")

    ok = fail = 0
    for idx, img_path in enumerate(images, 1):
        label = f"[{idx}/{len(images)}]"
        try:
            screenshot = Image.open(img_path)
            result = apply_mockup(screenshot, bg_style, phone_key)

            if scale != 1.0:
                nw = round(result.width * scale)
                nh = round(result.height * scale)
                result = result.resize((nw, nh), Image.LANCZOS)

            out_name = f"{img_path.stem}_mockup.png"
            out_path = OUTPUT_DIR / out_name
            result.save(str(out_path), "PNG", optimize=True)

            size_kb = out_path.stat().st_size // 1024
            name_padded = img_path.name[:40].ljust(40)
            print(f"  {label}  {name_padded}  ->  {out_name}  ({size_kb} KB)")
            ok += 1

        except Exception as exc:
            print(f"  {label}  FAILED  {img_path.name}:  {exc}")
            fail += 1

    print()
    if ok:
        print(f"Done — {ok} saved{f', {fail} failed' if fail else ''}.")
        print(f"Output folder: {OUTPUT_DIR}")
    else:
        print(f"All {fail} image(s) failed.")
# ─────────────────────────────────────────────────────────────────────────────


# ── CLI ───────────────────────────────────────────────────────────────────────
def _parse() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=(
            "Wrap Flutter app screenshots in a phone mockup frame.\n\n"
            "Place screenshots in  mockup/input/  then run this script,\n"
            "or use --capture to pull directly from a connected device."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--capture",
        action="store_true",
        help="Take a live screenshot from the connected Android device via ADB.",
    )
    p.add_argument(
        "--bg",
        choices=list(BG_STYLES),
        default="light",
        metavar="STYLE",
        help=f"Background: {' | '.join(BG_STYLES)}  (default: light)",
    )
    p.add_argument(
        "--phone",
        choices=list(PHONE_COLORS),
        default="black",
        metavar="COLOR",
        help=f"Phone frame color: {' | '.join(PHONE_COLORS)}  (default: black)",
    )
    p.add_argument(
        "--scale",
        type=float,
        default=1.0,
        metavar="FACTOR",
        help="Output scale factor, e.g. 0.5 halves the size  (default: 1.0)",
    )
    return p.parse_args()


if __name__ == "__main__":
    try:
        args = _parse()
        if not 0.1 <= args.scale <= 4.0:
            print("Error: --scale must be between 0.1 and 4.0", file=sys.stderr)
            sys.exit(1)
        process_all(
            bg_style=args.bg,
            phone_key=args.phone,
            scale=args.scale,
            capture=args.capture,
        )
    except KeyboardInterrupt:
        print("\nCancelled.")
        sys.exit(130)
