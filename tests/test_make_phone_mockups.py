"""Tests for make_phone_mockups.py — geometry, backgrounds, and compositing."""
import pytest

try:
    from PIL import Image
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

pytestmark = pytest.mark.skipif(not PIL_AVAILABLE, reason="Pillow not installed")

import make_phone_mockups as m


class TestConstants:
    def test_screen_fits_inside_phone(self):
        assert m.SCR_X >= m.PHONE_X
        assert m.SCR_Y >= m.PHONE_Y
        assert m.SCR_X + m.SCR_W <= m.PHONE_X + m.PHONE_W
        assert m.SCR_Y + m.SCR_H <= m.PHONE_Y + m.PHONE_H

    def test_dynamic_island_inside_screen(self):
        assert m.DI_X1 >= m.SCR_X
        assert m.DI_X2 <= m.SCR_X + m.SCR_W
        assert m.DI_Y1 >= m.SCR_Y
        assert m.DI_Y2 <= m.SCR_Y + m.SCR_H

    def test_canvas_larger_than_phone(self):
        assert m.CANVAS_W > m.PHONE_W
        assert m.CANVAS_H > m.PHONE_H

    def test_all_phone_palettes_present(self):
        for key in ("black", "silver", "green"):
            assert key in m.PHONE_PALETTES


class TestApplyMockup:
    def _make_screenshot(self, w: int = 390, h: int = 844) -> Image.Image:
        return Image.new("RGB", (w, h), color=(30, 120, 200))

    def test_output_is_canvas_size(self):
        shot = self._make_screenshot()
        result = m.apply_mockup(shot)
        assert result.size == (m.CANVAS_W, m.CANVAS_H)

    def test_output_is_rgb(self):
        shot = self._make_screenshot()
        result = m.apply_mockup(shot)
        assert result.mode == "RGB"

    def test_all_backgrounds(self):
        shot = self._make_screenshot()
        for bg in ("dark", "green", "light"):
            result = m.apply_mockup(shot, background=bg)
            assert result.size == (m.CANVAS_W, m.CANVAS_H)

    def test_all_phone_colors(self):
        shot = self._make_screenshot()
        for phone in ("black", "silver", "green"):
            result = m.apply_mockup(shot, phone=phone)
            assert result.size == (m.CANVAS_W, m.CANVAS_H)

    def test_landscape_screenshot_handled(self):
        shot = self._make_screenshot(w=1280, h=720)
        result = m.apply_mockup(shot, fit="cover")
        assert result.size == (m.CANVAS_W, m.CANVAS_H)

    def test_contain_fit(self):
        shot = self._make_screenshot(w=200, h=800)
        result = m.apply_mockup(shot, fit="contain")
        assert result.size == (m.CANVAS_W, m.CANVAS_H)
