#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 -m json.tool "$root/scripts/inject-config/com.amila.parenting.json" > /dev/null
python3 -m json.tool "$root/scripts/inject-config/com.drillyapps.babydaybook.json" > /dev/null
python3 -m json.tool "$root/scripts/inject-config/com.hp.babyapp.json" > /dev/null
python3 "$root/tests/test_inject_config.py"
