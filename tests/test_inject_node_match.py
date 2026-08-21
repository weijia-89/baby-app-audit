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


NUBO_DUMP = """<?xml version="1.0" encoding="UTF-8"?>
<hierarchy>
  <node class="android.widget.ImageView" resource-id="com.clicksie.nuboapp:id/btnMilkL"
      clickable="true" bounds="[170,724][489,1043]" />
  <node class="android.widget.ImageView" resource-id="com.clicksie.nuboapp:id/btnSleep"
      clickable="true" bounds="[498,355][928,671]" />
  <node class="android.widget.TextView" text="Skip" clickable="true"
      bounds="[800,1800][1000,1900]" />
</hierarchy>
"""


def test_matches_resource_id_suffix():
    ns = list(ET.fromstring(NUBO_DUMP).iter())
    n = mod.find_node_by_id(ns, "btnMilkL")
    assert n is not None
    assert n.get("resource-id").endswith("btnMilkL")


def test_resource_id_miss_returns_none():
    ns = list(ET.fromstring(NUBO_DUMP).iter())
    assert mod.find_node_by_id(ns, "btnBottle") is None


def test_am_start_requires_same_package():
    ok = mod.parse_am_start(
        {"am_start": "com.clicksie.nuboapp/com.clicksie.nuboapp.ui.activity.NoteActivity"},
        "com.clicksie.nuboapp",
    )
    assert ok.endswith("NoteActivity")
    assert (
        mod.parse_am_start(
            {"am_start": "com.evil/com.evil.Leak"},
            "com.clicksie.nuboapp",
        )
        is None
    )


def test_am_start_rejects_shell_metacharacters():
    assert (
        mod.parse_am_start(
            {"am_start": "com.clicksie.nuboapp/com.clicksie.nuboapp.Note;reboot"},
            "com.clicksie.nuboapp",
        )
        is None
    )


def test_am_start_rejects_class_outside_package():
    assert (
        mod.parse_am_start(
            {"am_start": "com.clicksie.nuboapp/com.android.settings.Settings"},
            "com.clicksie.nuboapp",
        )
        is None
    )


def test_am_start_rejects_whitespace_and_flags():
    assert (
        mod.parse_am_start(
            {"am_start": "com.clicksie.nuboapp/com.clicksie.nuboapp.Note --user 0"},
            "com.clicksie.nuboapp",
        )
        is None
    )


def test_swipe_requires_numeric_on_screen_coords():
    assert mod.parse_swipe({"swipe": [540, 1500, 540, 700, 400]}) == [540, 1500, 540, 700, 400]
    assert mod.parse_swipe({"swipe": ["left"]}) is None
    assert mod.parse_swipe({"swipe": [540, 1500, 540, 700, 99999]})[4] == 5000
    assert mod.parse_swipe({"swipe": [-1, 0, 1, 1]}) is None


def test_keyevent_allowlist():
    assert mod.parse_keyevent({"keyevent": 111}) == 111
    assert mod.parse_keyevent({"keyevent": "111"}) == 111
    assert mod.parse_keyevent({"keyevent": 26}) is None
    assert mod.parse_keyevent({"keyevent": "home"}) is None


def test_wait_is_capped():
    assert mod.parse_wait({"wait": 1}) == 1.0
    assert mod.parse_wait({"wait": 9999}) == 30.0
    assert mod.parse_wait({"wait": -1}) == 0.0
    assert mod.parse_wait({"wait": "nope"}) is None


def test_node_enabled_false():
    n = ET.fromstring(
        '<node resource-id="com.clicksie.nuboapp:id/btnSave" enabled="false" />'
    )
    assert mod.node_enabled(n) is False
    n2 = ET.fromstring('<node resource-id="com.clicksie.nuboapp:id/btnSave" />')
    assert mod.node_enabled(n2) is True


BABYPLUS_DUMP = """<?xml version="1.0" encoding="UTF-8"?>
<hierarchy>
  <node text="By tapping 'Done' you agree to our terms" clickable="true"
      bounds="[55,1655][1025,1713]" />
  <node text="DONE" resource-id="com.hp.babyapp:id/done_button" clickable="true"
      bounds="[55,1746][1025,1889]" />
</hierarchy>
"""


def test_done_exact_text_beats_terms_sentence():
    ns = list(ET.fromstring(BABYPLUS_DUMP).iter())
    n = mod.find_node_by_text(ns, "DONE")
    assert n is not None
    assert n.get("text") == "DONE"
    assert n.get("resource-id").endswith("done_button")


def test_done_button_id_suffix():
    ns = list(ET.fromstring(BABYPLUS_DUMP).iter())
    n = mod.find_node_by_id(ns, "done_button")
    assert n is not None
    assert n.get("text") == "DONE"


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
    test_matches_resource_id_suffix()
    test_resource_id_miss_returns_none()
    test_am_start_requires_same_package()
    test_am_start_rejects_shell_metacharacters()
    test_am_start_rejects_class_outside_package()
    test_am_start_rejects_whitespace_and_flags()
    test_swipe_requires_numeric_on_screen_coords()
    test_keyevent_allowlist()
    test_wait_is_capped()
    test_node_enabled_false()
    test_done_exact_text_beats_terms_sentence()
    test_done_button_id_suffix()
    print("ok")
