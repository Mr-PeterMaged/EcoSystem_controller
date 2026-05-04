"""
make_phone_mockups.py — iPhone 14 Pro mockup generator.

Visual design matches mockup/index.html + styles.css exactly:
  Background : linear-gradient(145deg, #060708, #0d1114, #040506)
               + radial green glow rgba(47,255,154,…) at 24% 16%
               + radial blue  glow rgba(123,146,255,…) at 85% 20%
  Frame      : iPhone 14 Pro — Dynamic Island, titanium sides, thin bezels
  Canvas     : 1080 x 1920 px  (matches <canvas width="1080" height="1920">)

Called by capture_app_screens.py after screenshots are taken, or standalone:

    python make_phone_mockups.py
    python make_phone_mockups.py --background green --phone silver
    python make_phone_mockups.py --input mockup/input --output mockup/output

Arguments:
    --input   DIR            Source screenshots  (default: mockup/input)
    --output  DIR            Output folder       (default: mockup/output)
    --fit     cover|contain  Scaling mode        (default: cover)
    --background dark|green|light               (default: dark)
    --phone   black|silver|green                (default: black)
    --scale   FACTOR         e.g. 0.5 = half    (default: 1.0)

Requires: Pillow  ->  pip install Pillow
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
except ImportError as exc:
    raise SystemExit(
        "Pillow is required. Install it with:\n  python -m pip install pillow"
    ) from exc


# ── Project paths ─────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent
MOCKUP_DIR   = PROJECT_ROOT / "mockup"
INPUT_DIR    = MOCKUP_DIR / "input"
OUTPUT_DIR   = MOCKUP_DIR / "output"
SUPPORTED    = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
# ─────────────────────────────────────────────────────────────────────────────


# ── Canvas (matches index.html canvas element) ────────────────────────────────
CANVAS_W = 1080
CANVAS_H = 1920
# ─────────────────────────────────────────────────────────────────────────────


# ── iPhone 14 Pro geometry ────────────────────────────────────────────────────
#   Real device ratio:  147.5 mm / 71.5 mm = 2.063
PHONE_W  = 620         # phone outer width  (px)
PHONE_H  = 1279        # phone outer height (= 620 × 2.063)
CORNER_R = 73          # outer body corner radius  (very rounded, iPhone style)
FRAME_T  = 11          # titanium frame thickness
CHIN_H   = 28          # bottom chin below screen glass (houses home indicator)

PHONE_X  = (CANVAS_W - PHONE_W) // 2   # = 230  (horizontally centred)
PHONE_Y  = (CANVAS_H - PHONE_H) // 2   # = 320  (vertically centred)

# Screen glass area (inset from titanium frame, above chin)
SCR_X = PHONE_X + FRAME_T               # = 241
SCR_Y = PHONE_Y + FRAME_T               # = 331
SCR_W = PHONE_W - 2 * FRAME_T           # = 598
SCR_H = PHONE_H - FRAME_T - CHIN_H      # = 1240
SCR_R = max(CORNER_R - FRAME_T, 4)      # = 62  (screen corner radius)

# Dynamic Island — centred pill at top of screen
DI_W  = 162
DI_H  = 48
DI_R  = 24
DI_CX = PHONE_X + PHONE_W // 2          # = 540
DI_X1 = DI_CX - DI_W // 2              # = 459
DI_X2 = DI_CX + DI_W // 2              # = 621
DI_Y1 = SCR_Y + 15                      # = 346
DI_Y2 = DI_Y1 + DI_H                    # = 394

# Home indicator bar  (inside chin)
HOME_W  = 148
HOME_H  = 5
HOME_R  = 3
HOME_CX = PHONE_X + PHONE_W // 2        # = 540
HOME_X1 = HOME_CX - HOME_W // 2         # = 466
HOME_X2 = HOME_CX + HOME_W // 2         # = 614
HOME_Y1 = PHONE_Y + PHONE_H - 17        # = 1582
HOME_Y2 = HOME_Y1 + HOME_H

# Side buttons — sit slightly outside the phone body for a 3-D look
_L1 = PHONE_X - 10        # left button left  edge
_L2 = PHONE_X - 3         # left button right edge
_R1 = PHONE_X + PHONE_W + 3    # right button left  edge
_R2 = PHONE_X + PHONE_W + 10   # right button right edge

BTN_MUTE   = (_L1, PHONE_Y + 150, _L2, PHONE_Y + 182)   # action/mute toggle
BTN_VOL_UP = (_L1, PHONE_Y + 218, _L2, PHONE_Y + 322)   # volume up
BTN_VOL_DN = (_L1, PHONE_Y + 346, _L2, PHONE_Y + 450)   # volume down
BTN_POWER  = (_R1, PHONE_Y + 420, _R2, PHONE_Y + 592)   # power (taller)
# ─────────────────────────────────────────────────────────────────────────────


# ── Phone colour palettes ─────────────────────────────────────────────────────
#   Each tuple: (frame_rgb, body_rgb, button_rgb, highlight_rgba, glow_rgb)
PHONE_PALETTES: dict[str, tuple] = {
    "black": (
        (26, 26, 30),           # Space Black titanium frame
        (20, 20, 23),           # body fill
        (46, 46, 50),           # side buttons
        (80, 80, 88, 35),       # glass sheen
        (47, 255, 154),         # accent glow  — matches CSS  --accent: #2fff9a
    ),
    "silver": (
        (196, 198, 204),        # Natural Titanium frame
        (186, 188, 195),        # body fill
        (172, 174, 180),        # side buttons
        (255, 255, 255, 55),
        (47, 255, 154),
    ),
    "green": (
        (56, 70, 50),           # Alpine Green titanium frame
        (48, 60, 43),           # body fill
        (42, 55, 37),           # side buttons
        (78, 102, 66, 40),
        (80, 200, 100),         # warmer green glow for green phone
    ),
}
# ─────────────────────────────────────────────────────────────────────────────


# ── Background helpers ────────────────────────────────────────────────────────

def _gradient_strip(
    h: int,
    stops: list[tuple[float, tuple[int, int, int]]],
) -> Image.Image:
    """1-px-wide vertical strip sampled from colour stops, ready to resize."""
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        # find the two surrounding stops
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t <= t1:
                s = (t - t0) / max(t1 - t0, 1e-9)
                px[0, y] = (
                    round(c0[0] + s * (c1[0] - c0[0])),
                    round(c0[1] + s * (c1[1] - c0[1])),
                    round(c0[2] + s * (c1[2] - c0[2])),
                )
                break
    return strip


def _angled_gradient(
    w: int,
    h: int,
    stops: list[tuple[float, tuple[int, int, int]]],
    angle: float = 145,
) -> Image.Image:
    """
    Approximate CSS  linear-gradient(<angle>deg, …)  using PIL.
    Projects each pixel onto the gradient axis and samples the colour stops.
    Memory-efficient: builds the final image directly without large intermediates.
    """
    rad   = math.radians(angle)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)

    # Project all four corners to find the t range along the gradient axis
    corners = [(0, 0), (w, 0), (0, h), (w, h)]
    projs   = [x * cos_a + y * sin_a for x, y in corners]
    t_min, t_max = min(projs), max(projs)
    t_range = max(t_max - t_min, 1e-9)

    # Build a 1-px vertical strip sampled per row (approximate but fast)
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        proj = (w / 2) * cos_a + y * sin_a
        t    = max(0.0, min(1.0, (proj - t_min) / t_range))
        # Linearly interpolate between colour stops
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t <= t1:
                s = (t - t0) / max(t1 - t0, 1e-9)
                px[0, y] = (
                    round(c0[0] + s * (c1[0] - c0[0])),
                    round(c0[1] + s * (c1[1] - c0[1])),
                    round(c0[2] + s * (c1[2] - c0[2])),
                )
                break

    return strip.resize((w, h), Image.NEAREST).convert("RGBA")


def _radial_glow(
    w: int, h: int,
    cx_r: float, cy_r: float,   # position as fraction of (w, h)
    radius_r: float,             # radius as fraction of min(w, h)
    rgba: tuple[int, int, int, int],
) -> Image.Image:
    """
    Replicates one CSS  radial-gradient(circle at X% Y%, rgba(…), transparent R%).
    """
    cx = round(w * cx_r)
    cy = round(h * cy_r)
    r  = round(min(w, h) * radius_r)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(
        [cx - r, cy - r, cx + r, cy + r], fill=rgba
    )
    return layer.filter(ImageFilter.GaussianBlur(r * 0.38))


# ── Three background styles ───────────────────────────────────────────────────

def _make_bg_dark(w: int, h: int) -> Image.Image:
    """
    CSS body background (default web UI):
        linear-gradient(145deg, #060708 0%, #0d1114 48%, #040506 100%)
        radial-gradient green at 24% 16%
        radial-gradient blue  at 85% 20%
    """
    canvas = _angled_gradient(
        w, h,
        stops=[(0.00, (6, 7, 8)), (0.48, (13, 17, 20)), (1.00, (4, 5, 6))],
        angle=145,
    )
    canvas = Image.alpha_composite(canvas, _radial_glow(w, h, 0.24, 0.16, 0.30, (47, 255, 154, 65)))
    canvas = Image.alpha_composite(canvas, _radial_glow(w, h, 0.85, 0.20, 0.26, (123, 146, 255, 50)))
    return canvas


def _make_bg_green(w: int, h: int) -> Image.Image:
    """Intensified green glow (glowIntensity slider at 100% in the web UI)."""
    canvas = _angled_gradient(
        w, h,
        stops=[(0.00, (4, 8, 6)), (0.48, (7, 14, 10)), (1.00, (2, 5, 4))],
        angle=145,
    )
    canvas = Image.alpha_composite(canvas, _radial_glow(w, h, 0.24, 0.16, 0.38, (47, 255, 154, 82)))
    canvas = Image.alpha_composite(canvas, _radial_glow(w, h, 0.75, 0.55, 0.28, (20, 200, 100, 45)))
    canvas = Image.alpha_composite(canvas, _radial_glow(w, h, 0.50, 0.92, 0.22, (30, 180, 90, 30)))
    return canvas


def _make_bg_light(w: int, h: int) -> Image.Image:
    """Reduced darkness (backgroundDarkness slider at ~50%)."""
    canvas = _angled_gradient(
        w, h,
        stops=[(0.00, (18, 22, 28)), (0.48, (22, 28, 38)), (1.00, (12, 15, 22))],
        angle=145,
    )
    canvas = Image.alpha_composite(canvas, _radial_glow(w, h, 0.24, 0.16, 0.30, (47, 255, 154, 18)))
    canvas = Image.alpha_composite(canvas, _radial_glow(w, h, 0.85, 0.20, 0.26, (123, 146, 255, 15)))
    return canvas


BG_BUILDERS = {
    "dark":  _make_bg_dark,
    "green": _make_bg_green,
    "light": _make_bg_light,
}
# ─────────────────────────────────────────────────────────────────────────────


# ── Phone frame builder ───────────────────────────────────────────────────────

def _build_frame(phone_key: str) -> Image.Image:
    """
    Draw the complete iPhone 14 Pro shell onto a transparent CANVAS_W x CANVAS_H canvas:
      drop shadow → titanium frame → body glass → side buttons →
      Dynamic Island → home indicator.

    The screen area is punched transparent so the screenshot shows through.
    """
    frame_c, body_c, btn_c, highlight_rgba, _ = PHONE_PALETTES[phone_key]

    frame_rgba  = (*frame_c,  255)
    body_rgba   = (*body_c,   255)
    btn_rgba    = (*btn_c,    255)
    W, H = CANVAS_W, CANVAS_H

    # ── 1. Drop shadow (multi-layer softness) ─────────────────────────────────
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for dy, alpha in ((30, 75), (18, 50), (8, 30)):
        sd.rounded_rectangle(
            [PHONE_X, PHONE_Y + dy, PHONE_X + PHONE_W, PHONE_Y + PHONE_H + dy],
            radius=CORNER_R, fill=(0, 0, 0, alpha),
        )
    shadow = shadow.filter(ImageFilter.GaussianBlur(42))

    # ── 2. Titanium frame (outermost body) ────────────────────────────────────
    frame_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame_layer)
    fd.rounded_rectangle(
        [PHONE_X, PHONE_Y, PHONE_X + PHONE_W, PHONE_Y + PHONE_H],
        radius=CORNER_R, fill=frame_rgba,
    )
    # Inner bevel (darker strip on the inside edge of the frame)
    inset = 3
    bevel_c = tuple(max(0, c - 18) for c in frame_c)
    fd.rounded_rectangle(
        [PHONE_X + inset, PHONE_Y + inset,
         PHONE_X + PHONE_W - inset, PHONE_Y + PHONE_H - inset],
        radius=max(CORNER_R - inset, 4), fill=(*bevel_c, 255),
    )

    # ── 3. Screen glass (fills inside of frame, above chin) ───────────────────
    glass_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass_layer)
    # Full glass pane (slightly darker than frame, represents OLED black)
    gd.rounded_rectangle(
        [SCR_X, SCR_Y, SCR_X + SCR_W, SCR_Y + SCR_H + CHIN_H],
        radius=SCR_R, fill=body_rgba,
    )
    # Subtle top-edge glass sheen
    gd.rounded_rectangle(
        [SCR_X + 2, SCR_Y + 2, SCR_X + SCR_W - 2, SCR_Y + 8],
        radius=SCR_R, fill=highlight_rgba,
    )

    # ── 4. Side buttons ───────────────────────────────────────────────────────
    btn_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(btn_layer)
    for rect in (BTN_MUTE, BTN_VOL_UP, BTN_VOL_DN, BTN_POWER):
        bd.rounded_rectangle(list(rect), radius=4, fill=btn_rgba)
    # Fill vertical gap between buttons and rounded phone corners
    bd.rectangle(
        [PHONE_X - 3, PHONE_Y + CORNER_R, PHONE_X, PHONE_Y + PHONE_H - CORNER_R],
        fill=frame_rgba,
    )
    bd.rectangle(
        [PHONE_X + PHONE_W, PHONE_Y + CORNER_R,
         PHONE_X + PHONE_W + 3, PHONE_Y + PHONE_H - CORNER_R],
        fill=frame_rgba,
    )

    # ── 5. Dynamic Island ─────────────────────────────────────────────────────
    di_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(di_layer)
    # Pill shape — pure black (OLED off)
    dd.rounded_rectangle([DI_X1, DI_Y1, DI_X2, DI_Y2], radius=DI_R, fill=(0, 0, 0, 255))
    # Tiny camera dot (depth hint)
    cam_cx = DI_X2 - 22
    cam_cy = DI_Y1 + DI_H // 2
    dd.ellipse([cam_cx - 7, cam_cy - 7, cam_cx + 7, cam_cy + 7], fill=(14, 14, 16, 255))
    dd.ellipse([cam_cx - 4, cam_cy - 4, cam_cx + 4, cam_cy + 4], fill=(4, 4, 5, 255))

    # ── 6. Home indicator ─────────────────────────────────────────────────────
    hi_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hi_layer)
    hd.rounded_rectangle(
        [HOME_X1, HOME_Y1, HOME_X2, HOME_Y2],
        radius=HOME_R, fill=(255, 255, 255, 140),
    )

    # ── Composite all non-screen layers (DI excluded until after hole punch) ──
    composite = shadow
    composite = Image.alpha_composite(composite, frame_layer)
    composite = Image.alpha_composite(composite, glass_layer)
    composite = Image.alpha_composite(composite, btn_layer)
    composite = Image.alpha_composite(composite, hi_layer)

    # ── Punch transparent hole for the screen area ────────────────────────────
    # Preserve existing rounded-corner alpha by multiplying rather than replacing
    from PIL import ImageChops
    frame_alpha = composite.getchannel("A")
    screen_hole = Image.new("L", (W, H), 255)
    ImageDraw.Draw(screen_hole).rounded_rectangle(
        [SCR_X, SCR_Y, SCR_X + SCR_W, SCR_Y + SCR_H], radius=SCR_R, fill=0
    )
    composite.putalpha(ImageChops.multiply(frame_alpha, screen_hole))

    # ── Dynamic Island after hole punch (sits above the screen opening) ───────
    composite = Image.alpha_composite(composite, di_layer)
    return composite


# ── Phone accent glow (halo around frame, matches CSS --accent #2fff9a) ───────

def _phone_glow(phone_key: str, bg_key: str) -> Image.Image:
    _, _, _, _, glow_rgb = PHONE_PALETTES[phone_key]
    alpha = 72 if bg_key == "green" else 42
    layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        [PHONE_X, PHONE_Y, PHONE_X + PHONE_W, PHONE_Y + PHONE_H],
        radius=CORNER_R, outline=(*glow_rgb, alpha), width=28,
    )
    return layer.filter(ImageFilter.GaussianBlur(36))


# ── Screen glare (thin diagonal highlight on glass) ───────────────────────────

def _screen_glare() -> Image.Image:
    layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(
        [
            (SCR_X + 20, SCR_Y + 20),
            (SCR_X + SCR_W // 4, SCR_Y + 20),
            (SCR_X + 20, SCR_Y + SCR_H // 7),
        ],
        fill=(255, 255, 255, 11),
    )
    return layer
# ─────────────────────────────────────────────────────────────────────────────


# ── Screenshot scaling ────────────────────────────────────────────────────────

def _fit_screenshot(img: Image.Image, w: int, h: int, mode: str) -> Image.Image:
    src_w, src_h = img.size
    if mode == "cover":
        scale = max(w / src_w, h / src_h)
        nw, nh = round(src_w * scale), round(src_h * scale)
        resized = img.resize((nw, nh), Image.LANCZOS)
        left = (nw - w) // 2
        top  = (nh - h) // 2
        return resized.crop((left, top, left + w, top + h))
    else:   # contain
        scale = min(w / src_w, h / src_h)
        nw, nh = round(src_w * scale), round(src_h * scale)
        resized = img.resize((nw, nh), Image.LANCZOS)
        out = Image.new("RGBA", (w, h), (0, 0, 0, 255))
        out.paste(resized.convert("RGBA"), ((w - nw) // 2, (h - nh) // 2))
        return out
# ─────────────────────────────────────────────────────────────────────────────


# ── Status bar (time + shield left | signal + wifi + battery right) ───────────

def _draw_status_bar(canvas: Image.Image) -> Image.Image:
    """Overlay iPhone 14 Pro status bar icons at the Dynamic Island level."""
    layer = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    white = (255, 255, 255, 230)

    # Vertical midpoint shared by time, icons, and Dynamic Island
    bar_cy = DI_Y1 + DI_H // 2   # ≈ 370

    # ── Font ──────────────────────────────────────────────────────────────────
    font_size = 34
    font = None
    for fp in [
        r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\arial.ttf",
        r"/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        r"/System/Library/Fonts/Helvetica.ttc",
    ]:
        try:
            font = ImageFont.truetype(fp, font_size)
            break
        except Exception:
            pass
    if font is None:
        font = ImageFont.load_default()

    # ── Left: time ────────────────────────────────────────────────────────────
    tx = SCR_X + 30
    time_str = "9:41"
    d.text((tx, bar_cy), time_str, font=font, fill=white, anchor="lm")
    tw = d.textlength(time_str, font=font)

    # ── Left: shield icon (VPN indicator) ────────────────────────────────────
    sh_cx = tx + tw + 16
    sh_w, sh_h = 18, 22
    sh_top  = bar_cy - sh_h // 2
    sh_bot  = bar_cy + sh_h // 2
    sh_mid  = bar_cy + 2
    shield_pts = [
        (sh_cx - sh_w // 2, sh_top),   # top-left
        (sh_cx + sh_w // 2, sh_top),   # top-right
        (sh_cx + sh_w // 2, sh_mid),   # mid-right
        (sh_cx,             sh_bot),   # bottom point
        (sh_cx - sh_w // 2, sh_mid),   # mid-left
    ]
    d.polygon(shield_pts, fill=white)
    # Checkmark inside shield
    ck_y = bar_cy - 1
    d.line(
        [(sh_cx - 5, ck_y), (sh_cx - 1, ck_y + 5), (sh_cx + 6, ck_y - 5)],
        fill=(0, 0, 0, 200), width=2,
    )

    # ── Right: battery ────────────────────────────────────────────────────────
    rx = SCR_X + SCR_W - 22
    bat_w, bat_h, bat_r = 46, 22, 4
    bat_cap_w, bat_cap_h = 4, 10
    bat_x2 = rx
    bat_x1 = bat_x2 - bat_w
    bat_y1 = bar_cy - bat_h // 2
    bat_y2 = bat_y1 + bat_h
    d.rounded_rectangle([bat_x1, bat_y1, bat_x2, bat_y2], radius=bat_r, outline=white, width=2)
    # Nub cap on right
    d.rounded_rectangle(
        [bat_x2 + 2, bar_cy - bat_cap_h // 2, bat_x2 + 2 + bat_cap_w, bar_cy + bat_cap_h // 2],
        radius=2, fill=white,
    )
    # Fill (~60 %)
    fill_w = round((bat_w - 6) * 0.60)
    d.rounded_rectangle(
        [bat_x1 + 3, bat_y1 + 3, bat_x1 + 3 + fill_w, bat_y2 - 3],
        radius=2, fill=white,
    )

    # ── Right: WiFi ───────────────────────────────────────────────────────────
    rx = bat_x1 - 16
    wifi_r_max = 17
    wifi_cx = rx - wifi_r_max
    wifi_dot_y = bar_cy + wifi_r_max // 2
    for r in (wifi_r_max, round(wifi_r_max * 0.63), round(wifi_r_max * 0.30)):
        d.arc(
            [wifi_cx - r, wifi_dot_y - r * 2, wifi_cx + r, wifi_dot_y],
            start=210, end=330, fill=white, width=3,
        )
    dot_r = 3
    d.ellipse(
        [wifi_cx - dot_r, wifi_dot_y - dot_r, wifi_cx + dot_r, wifi_dot_y + dot_r],
        fill=white,
    )

    # ── Right: signal bars ───────────────────────────────────────────────────
    rx = wifi_cx - wifi_r_max - 14
    bar_w, bar_gap, n_bars = 7, 4, 4
    sig_bot = bar_cy + 12
    sig_x1 = rx - (n_bars * bar_w + (n_bars - 1) * bar_gap)
    for i in range(n_bars):
        bh = 8 + i * 5
        bx = sig_x1 + i * (bar_w + bar_gap)
        d.rounded_rectangle([bx, sig_bot - bh, bx + bar_w, sig_bot], radius=2, fill=white)

    # Clip the overlay to the rounded screen area so nothing bleeds outside
    scr_clip = Image.new("L", (CANVAS_W, CANVAS_H), 0)
    ImageDraw.Draw(scr_clip).rounded_rectangle(
        [SCR_X, SCR_Y, SCR_X + SCR_W, SCR_Y + SCR_H], radius=SCR_R, fill=255
    )
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), scr_clip))

    return Image.alpha_composite(canvas, layer)
# ─────────────────────────────────────────────────────────────────────────────


# ── Main compositor ───────────────────────────────────────────────────────────

def apply_mockup(
    screenshot: Image.Image,
    *,
    fit: str        = "cover",
    background: str = "dark",
    phone: str      = "black",
) -> Image.Image:
    """
    Composite one screenshot onto the iPhone 14 Pro frame.
    Returns a CANVAS_W x CANVAS_H RGB image.
    """
    # 1. Background (dark with CSS-matching radial glows)
    canvas = BG_BUILDERS.get(background, _make_bg_dark)(CANVAS_W, CANVAS_H)

    # 2. Accent glow halo behind the phone frame
    canvas = Image.alpha_composite(canvas, _phone_glow(phone, background))

    # 3. Screenshot scaled + clipped to screen area
    shot = _fit_screenshot(screenshot.convert("RGBA"), SCR_W, SCR_H, fit)
    scr_mask = Image.new("L", (SCR_W, SCR_H), 0)
    ImageDraw.Draw(scr_mask).rounded_rectangle(
        [0, 0, SCR_W, SCR_H], radius=SCR_R, fill=255
    )
    shot.putalpha(scr_mask)
    canvas.paste(shot, (SCR_X, SCR_Y), shot)

    # 4. iPhone 14 Pro frame (screen area is transparent → screenshot shows through)
    frame = _build_frame(phone)
    canvas = Image.alpha_composite(canvas, frame)

    # 5. Status bar (time + shield on left, signal/wifi/battery on right)
    canvas = _draw_status_bar(canvas)

    # 6. Subtle screen glare
    canvas = Image.alpha_composite(canvas, _screen_glare())

    return canvas.convert("RGB")
# ─────────────────────────────────────────────────────────────────────────────


# ── Batch processor ───────────────────────────────────────────────────────────

def process_all(
    input_dir: Path,
    output_dir: Path,
    *,
    fit: str        = "cover",
    background: str = "dark",
    phone: str      = "black",
    scale: float    = 1.0,
) -> int:
    input_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    images = sorted(p for p in input_dir.iterdir() if p.suffix.lower() in SUPPORTED)
    if not images:
        print(f"No images found in: {input_dir}")
        print("Put app screenshots there, then run again.")
        return 0

    print(
        f"Found {len(images)} screenshot(s)  |  "
        f"bg: {background}  |  phone: {phone}  |  fit: {fit}  |  scale: {scale}"
    )
    print(f"Output -> {output_dir}\n")

    ok = fail = 0
    for idx, img_path in enumerate(images, 1):
        label = f"[{idx}/{len(images)}]"
        try:
            result = apply_mockup(
                Image.open(img_path),
                fit=fit,
                background=background,
                phone=phone,
            )
            if scale != 1.0:
                result = result.resize(
                    (round(result.width * scale), round(result.height * scale)),
                    Image.LANCZOS,
                )
            # keep original stem, add _phone_mockup suffix (matches capture_app_screens.py expectation)
            safe_stem = "".join(
                c if c.isalnum() or c in {"-", "_"} else "-" for c in img_path.stem
            ).strip("-_") or "screen"
            out_path = output_dir / f"{safe_stem}_phone_mockup.png"
            result.save(str(out_path), "PNG", optimize=True)
            size_kb = out_path.stat().st_size // 1024
            print(f"  {label}  {img_path.name[:40]:<40}  ->  {out_path.name}  ({size_kb} KB)")
            ok += 1
        except Exception as exc:
            print(f"  {label}  FAILED  {img_path.name}: {exc}")
            fail += 1

    print()
    print(f"Done - {ok} saved{f', {fail} failed' if fail else ''}.")
    return ok
# ─────────────────────────────────────────────────────────────────────────────


# ── CLI ───────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description=(
            "iPhone 14 Pro mockup generator — design matches "
            "mockup/index.html + styles.css."
        ),
    )
    p.add_argument("--input",  default=str(INPUT_DIR),  metavar="DIR",
                   help=f"Source screenshots folder  (default: mockup/input)")
    p.add_argument("--output", default=str(OUTPUT_DIR), metavar="DIR",
                   help=f"Output folder              (default: mockup/output)")
    p.add_argument("--fit",
                   choices=["cover", "contain"], default="cover",
                   help="cover = fill screen & crop  |  contain = letterbox  (default: cover)")
    p.add_argument("--background",
                   choices=sorted(BG_BUILDERS), default="dark",
                   help=f"Background: {' | '.join(sorted(BG_BUILDERS))}  (default: dark)")
    p.add_argument("--phone",
                   choices=sorted(PHONE_PALETTES), default="black",
                   help=f"Frame colour: {' | '.join(sorted(PHONE_PALETTES))}  (default: black)")
    p.add_argument("--scale",
                   type=float, default=1.0, metavar="FACTOR",
                   help="Output scale, e.g. 0.5 halves the size  (default: 1.0)")
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if not 0.1 <= args.scale <= 4.0:
        print("Error: --scale must be between 0.1 and 4.0", file=sys.stderr)
        return 1
    input_dir  = Path(args.input)
    output_dir = Path(args.output)
    if not input_dir.is_absolute():
        input_dir  = PROJECT_ROOT / input_dir
    if not output_dir.is_absolute():
        output_dir = PROJECT_ROOT / output_dir
    process_all(
        input_dir, output_dir,
        fit=args.fit,
        background=args.background,
        phone=args.phone,
        scale=args.scale,
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nCancelled.")
        raise SystemExit(130)
