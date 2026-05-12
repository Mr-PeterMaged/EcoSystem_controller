"""Generate Android launcher icons with a black background and a larger logo.

Run from the project root:
    python generate_app_icon.py

Requires: Pillow  ->  pip install Pillow
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image

# ── Configuration ─────────────────────────────────────────────────────────────
LOGO_PATH   = Path("Logo/dark_mode.png")
ANDROID_RES = Path("android/app/src/main/res")
BG_COLOR    = (0, 0, 0, 255)   # pure black

# How much of the icon the logo fills (legacy icons)
LOGO_FILL_LEGACY   = 0.82

# Adaptive foreground fill — logo is placed inside the 72dp safe-zone
# (72/108 ≈ 0.667) so using 0.78 keeps it big but safely inside.
LOGO_FILL_ADAPTIVE = 0.78

# Legacy ic_launcher.png sizes (dp → px at each density bucket)
LEGACY_SIZES: dict[str, int] = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive foreground sizes (108dp at each density)
ADAPTIVE_SIZES: dict[str, int] = {
    "mipmap-mdpi":    108,
    "mipmap-hdpi":    162,
    "mipmap-xhdpi":   216,
    "mipmap-xxhdpi":  324,
    "mipmap-xxxhdpi": 432,
}
# ─────────────────────────────────────────────────────────────────────────────


def make_icon(logo: Image.Image, size: int, fill: float) -> Image.Image:
    """Compose a square icon: black background + centered logo at `fill` ratio."""
    canvas = Image.new("RGBA", (size, size), BG_COLOR)
    logo_px = int(size * fill)
    scaled  = logo.resize((logo_px, logo_px), Image.LANCZOS)
    offset  = (size - logo_px) // 2
    canvas.paste(scaled, (offset, offset), scaled)   # use alpha mask
    return canvas.convert("RGB")


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> None:
    if not LOGO_PATH.exists():
        raise FileNotFoundError(f"Logo not found: {LOGO_PATH}")

    logo = Image.open(LOGO_PATH).convert("RGBA")
    print(f"Logo loaded: {LOGO_PATH}  ({logo.width}x{logo.height})")

    # 1 ── Legacy launcher icons (all Android versions) ───────────────────────
    print("\nGenerating legacy icons (ic_launcher.png):")
    for folder, size in LEGACY_SIZES.items():
        icon = make_icon(logo, size, LOGO_FILL_LEGACY)
        out  = ANDROID_RES / folder / "ic_launcher.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        icon.save(str(out), "PNG")
        # round variant — same image, Android clips it to a circle
        round_out = ANDROID_RES / folder / "ic_launcher_round.png"
        icon.save(str(round_out), "PNG")
        print(f"  {folder:25s} {size}x{size} px")

    # 2 ── Adaptive foreground images (Android 8+) ────────────────────────────
    print("\nGenerating adaptive foreground (ic_launcher_foreground.png):")
    for folder, size in ADAPTIVE_SIZES.items():
        fg  = make_icon(logo, size, LOGO_FILL_ADAPTIVE)
        out = ANDROID_RES / folder / "ic_launcher_foreground.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        fg.save(str(out), "PNG")
        print(f"  {folder:25s} {size}x{size} px")

    # 3 ── Black background color resource ────────────────────────────────────
    color_xml = """\
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FF000000</color>
</resources>
"""
    write_text(ANDROID_RES / "values" / "ic_launcher_background.xml", color_xml)
    print("\nCreated: values/ic_launcher_background.xml  (black background)")

    # 4 ── Adaptive icon XML (Android 8+ / API 26+) ───────────────────────────
    adaptive_xml = """\
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    anydpi = ANDROID_RES / "mipmap-anydpi-v26"
    write_text(anydpi / "ic_launcher.xml",       adaptive_xml)
    write_text(anydpi / "ic_launcher_round.xml", adaptive_xml)
    print("Created: mipmap-anydpi-v26/ic_launcher.xml")
    print("Created: mipmap-anydpi-v26/ic_launcher_round.xml")

    print("\nDone! Rebuild the APK to see the new icon.")


if __name__ == "__main__":
    main()
