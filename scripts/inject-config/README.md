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

WebView or Chrome Custom Tab login (Baby+, Pebbi, MimiLog) is not driven by this
JSON. Use Appium:

```
appium '--allow-insecure=*:chromedriver_autodownload'
.test-venv/bin/python scripts/appium-webview-login.py --package com.hp.babyapp --tap-text LOGIN
```

The emulator must already have a Google account. The script does not print passwords.

Baby+ **About Baby** gender is a required control with no TalkBack name (empty `content-desc`, no Boy/Girl nodes). See FINAL-REPORT.md Baby+. Do not expect `tap_text` to select gender.
