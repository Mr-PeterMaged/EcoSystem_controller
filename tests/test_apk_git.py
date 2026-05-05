"""Tests for APK_GIT.py utility functions."""
import pytest
from APK_GIT import safe_tag


class TestSafeTag:
    def test_plain_version(self):
        assert safe_tag("1.0.0") == "v1.0.0"

    def test_build_separator_converted(self):
        assert safe_tag("1.0.0+3") == "v1.0.0-build.3"

    def test_already_has_v_prefix(self):
        # safe_tag always prepends v, even if input starts with v
        result = safe_tag("v1.2.3")
        assert result.startswith("v")

    def test_special_chars_replaced(self):
        result = safe_tag("1.0.0 beta!")
        assert " " not in result
        assert "!" not in result

    def test_empty_string_returns_vlatest(self):
        assert safe_tag("") == "vlatest"

    def test_only_invalid_chars(self):
        assert safe_tag("!!!") == "vlatest"

    def test_strips_leading_trailing_separators(self):
        result = safe_tag("-1.0-")
        assert not result.startswith("v-")
        assert not result.endswith("-")
