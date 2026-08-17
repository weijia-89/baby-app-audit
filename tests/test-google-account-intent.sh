#!/usr/bin/env bash
set -euo pipefail
# The MinuteMaid / IMAP dump activity is the wrong Google add-account path.
script="$(cd "$(dirname "$0")/.." && pwd)/scripts/add-google-account.py"
grep -q 'android.settings.ADD_ACCOUNT_SETTINGS' "$script"
if grep -qE 'am start.*UiMinfaActivity' "$script"; then
  echo "FAIL: add-google-account.py still launches UiMinfaActivity"
  exit 1
fi
if grep -q 'shell", "cmd", "account"' "$script"; then
  echo "FAIL: API 29 has no cmd account list; use dumpsys account"
  exit 1
fi
echo "ok"
