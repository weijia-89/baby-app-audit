#!/usr/bin/env bash
# Deterministic tests for scripts/firebase_silence.py.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$repo_root" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.environ["REPO_ROOT"], "scripts"))
import firebase_silence as fs

N = fs.FIREBASE_NEEDLES

# Control traffic is mandatory before any negative claim.
r = fs.evaluate_silence(pcap_hosts=set(), mitm_hosts=set(),
                        control_seen=False, window_profile_done=True)
assert r["verdict"] == "inconclusive" and "control" in r["reasons"][0], r

# Window requirement comes after control.
r = fs.evaluate_silence(set(), set(), True, False)
assert r["verdict"] == "inconclusive" and "window" in r["reasons"][0], r

# A hit in EITHER record inside a finished-profile window = not_silent.
for hosts in ({"firebaseio.com"}, set(), ):
    pass
r = fs.evaluate_silence({"firebaseio.com"}, set(), True, True)
assert r["verdict"] == "not_silent" and "firebaseio.com" in r["hits"], r
r = fs.evaluate_silence(set(), {"xx.firebasedatabase.googleapis.com"}, True, True)
assert r["verdict"] == "not_silent", r
# Needle matching is substring + case-insensitive on hosts.
r = fs.evaluate_silence({"FirebaseIO.COM"}, set(), True, True)
assert r["verdict"] == "not_silent", r

# Data-endpoint silence with telemetry flow must say so explicitly.
r = fs.evaluate_silence(
    {"firebaselogging-pa.googleapis.com", "app-measurement.com"},
    set(), True, True)
assert r["verdict"] == "silent_in_window", r
assert r["telemetry_present"] is True, r
assert any("telemetry" in reason.lower() for reason in r["reasons"]), r

# Non-Firebase noise never triggers.
r = fs.evaluate_silence({"googleads.g.doubleclick.net", "connectivitycheck.gstatic.com"},
                        {"play.googleapis.com"}, True, True)
assert r["verdict"] == "silent_in_window" and r["hits"] == [], r

print("firebase-silence tests passed")
PY
echo "test-firebase-silence passed"
