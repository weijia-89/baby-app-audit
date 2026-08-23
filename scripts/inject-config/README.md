# Per-app injector overrides

Drop a file named `<package>.json` here to tune `inject-synthetic-profile.py` for a
specific app. All keys are optional. Example:

```json
{
  "spray_token_on_unknown": true,
  "field_values": {
    "name": "Privatia Rigatoni",
    "babynote": "PRIVATIA-RIGATONI-SYNTH",
    "feed": "Rigatoni-8823-synthfeed"
  }
}
```

- `spray_token_on_unknown` (bool): when the heuristic cannot classify a text field,
  fill it with the high-confidence `synth_token` anyway. Default true.
- `field_values` (map): keyword substring (matched against hint + text + resource-id,
  lowercased) -> exact value to type. Highest priority; overrides the built-in
  heuristic. Use it to pin a value or to target a field the heuristic mis-classifies.

The injector is heuristic-first and works with no override file; add one only when a
specific app's onboarding needs tuning.

WebView or Chrome Custom Tab login (Baby+, Pebbi) is not driven by this
JSON. Use Appium:

```
appium '--allow-insecure=*:chromedriver_autodownload'
.test-venv/bin/python scripts/appium-webview-login.py --package com.hp.babyapp --tap-text LOGIN
```

The emulator must already have a Google account. The script does not print passwords.

MimiLog is native Flutter after Create profile. Labels live in `content-desc`. The onboarded recipe is `com.mimiapp.mimilog.json` (Feeding / Bottle / 482 mL). Set `"dismiss": false` on `fill_nth` so ESCAPE does not close the Bottle sheet.

A `fill_nth` step without `dismiss` still sends DPAD_CENTER and ESCAPE after typing (Amila, Baby Daybook). That hides the keyboard so later `tap_bounds` can hit Done.

`am_start` launches an activity in the same package only (`package/class`). The class name must start with that package. Shell characters are rejected. `keyevent` only sends BACK, DPAD_CENTER, TAB, ENTER, DEL, or ESCAPE (111 hides the keyboard on the Nubo Notes screen so Save is tappable). Wait steps stop at 30 seconds. `force_stop` (config root, bool) kills the app before launch so a leftover screen does not hide home buttons. `tap_id` skips a node with `enabled=false`.

Baby+ **About Baby** gender is a required control with no TalkBack name (empty `content-desc`, no Boy/Girl nodes). See FINAL-REPORT.md Baby+. If the control is two icons and skip is not offered, tap female.

Nubo (`com.clicksie.nuboapp.json`) is native after onboarding. `tap_id` hits resource-id suffixes (`btnMilkL`, `btnMilkR`, `btnSleep`, `btnBottle`, `btnPee`, `btnPoop`, `btnPump`). Milk, sleep, and pump: tap start then tap stop. Bottle, pee, and poop: one tap logs the event. `am_start` may open `NoteActivity` in the same package only. Skip device pairing. Formula-per-click 90 is not the 482 mL bottle volume. As of 2026-08-23 the 90 chip does not stay selected: `viewMap1` covers the row and `tvFormulaClick` is not clickable.
