#!/usr/bin/env python3
"""Unit tests for injector node matching. No device required."""
import importlib.util
import xml.etree.ElementTree as ET
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "inject-synthetic-profile.py"
spec = importlib.util.spec_from_file_location("inject_synthetic_profile", SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


FLUTTER_DUMP = """<?xml version="1.0" encoding="UTF-8"?>
<hierarchy>
  <node index="0" text="" content-desc="0×
Feedings
0.0 / day" class="android.view.View" bounds="[44,363][524,718]" />
  <node index="1" text="" content-desc="Create profile" class="android.widget.Button"
      clickable="true" bounds="[293,1168][787,1322]" />
  <node index="2" text="" content-desc="Feeding" class="android.view.View"
      clickable="true" bounds="[44,1351][276,1664]" />
  <node index="3" text="LOGIN" content-desc="" class="android.widget.Button"
      clickable="true" bounds="[0,0][10,10]" />
  <node index="4" text="" content-desc="Dashboard
Tab 1 of 4" class="android.widget.Button" clickable="true" bounds="[0,1830][270,2028]" />
</hierarchy>
"""


def _nodes():
    return list(ET.fromstring(FLUTTER_DUMP).iter())


def test_matches_content_desc_when_text_empty():
    n = mod.find_node_by_text(_nodes(), "Create profile")
    assert n is not None
    assert n.get("content-desc") == "Create profile"


def test_still_matches_visible_text():
    n = mod.find_node_by_text(_nodes(), "LOGIN")
    assert n is not None
    assert n.get("text") == "LOGIN"


def test_exact_content_desc_beats_partial():
    n = mod.find_node_by_text(_nodes(), "Feeding")
    assert n is not None
    assert n.get("content-desc") == "Feeding"
    assert n.get("bounds") == "[44,1351][276,1664]"


def test_contains_content_desc_for_multiline_tab():
    n = mod.find_node_by_text(_nodes(), "Dashboard")
    assert n is not None
    assert "Dashboard" in (n.get("content-desc") or "")


def test_missing_label_returns_none():
    assert mod.find_node_by_text(_nodes(), "Get started") is None


def test_fill_nth_defaults_to_dismiss():
    vals, dismiss = mod.parse_fill_nth({"fill_nth": ["Privatia Rigatoni"]})
    assert vals == ["Privatia Rigatoni"]
    assert dismiss is True


def test_fill_nth_dismiss_false_for_flutter_sheet():
    vals, dismiss = mod.parse_fill_nth({"fill_nth": ["482"], "dismiss": False})
    assert vals == ["482"]
    assert dismiss is False


def test_fill_nth_rejects_non_list():
    vals, dismiss = mod.parse_fill_nth({"fill_nth": "482"})
    assert vals == []
    assert dismiss is True


def test_fill_nth_string_false_is_false():
    vals, dismiss = mod.parse_fill_nth({"fill_nth": ["482"], "dismiss": "false"})
    assert vals == ["482"]
    assert dismiss is False


if __name__ == "__main__":
    test_matches_content_desc_when_text_empty()
    test_still_matches_visible_text()
    test_exact_content_desc_beats_partial()
    test_contains_content_desc_for_multiline_tab()
    test_missing_label_returns_none()
    test_fill_nth_defaults_to_dismiss()
    test_fill_nth_dismiss_false_for_flutter_sheet()
    test_fill_nth_rejects_non_list()
    test_fill_nth_string_false_is_false()
    print("ok")
