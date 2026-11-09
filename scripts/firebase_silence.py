#!/usr/bin/env python3
"""Data-host check for one Firebase window.

Callers pass host sets and the two flags. A data host returns not_silent
even when either flag is false. silent_in_window means only that both flags
were true and no data host matched. It is not a ten-gate negative.
"""
from __future__ import annotations

FIREBASE_NEEDLES = (
    "firebaseio.com",
    "firebasedatabase.googleapis.com",
    "firestore.googleapis.com",
    "firebasestorage.googleapis.com",
)
TELEMETRY_NEEDLES = (
    "firebaselogging", "app-measurement.com",
    "firebase-settings.crashlytics.com",
    "firebaserc",
    "firebaseremoteconfig",
)


def _hits(hosts, needles):
    lowered = {h.lower() for h in hosts}
    return sorted({h for h in lowered for n in needles if n.lower() in h})


def evaluate_silence(pcap_hosts, mitm_hosts, control_seen, window_profile_done,
                     needles=FIREBASE_NEEDLES):
    """Return {verdict, reasons, hits, telemetry_present} for one window.

    Verdicts:
      not_silent        - a Firebase data host appeared in either record
      silent_in_window  - both flags true and zero data-host hits
      inconclusive      - a flag is missing and there is no data host

    Telemetry is reported separately. It is not a data host.
    """
    pcap = set(pcap_hosts or set())
    mitm = set(mitm_hosts or set())
    union = pcap | mitm
    hits = _hits(union, needles)
    telemetry = _hits(union, TELEMETRY_NEEDLES)
    # A data host is not_silent even when a flag is false (G10). Do not drop hits.
    if hits:
        return {
            "verdict": "not_silent",
            "reasons": ["Firebase data endpoints present in the capture records"],
            "hits": hits,
            "telemetry_present": telemetry != [],
        }
    if not control_seen:
        return {
            "verdict": "inconclusive",
            "reasons": ["control traffic absent; the capture cannot prove a negative"],
            "hits": [],
            "telemetry_present": telemetry != [],
        }
    if not window_profile_done:
        return {
            "verdict": "inconclusive",
            "reasons": ["capture window is not a finished-profile window"],
            "hits": hits,
            "telemetry_present": telemetry != [],
        }
    reasons = ["control traffic seen, finished-profile window, and zero "
               "Firebase DATA endpoints across both records"]
    if telemetry:
        reasons.append("Firebase telemetry endpoints were present "
                       "(logging/measurement/config); this verdict covers "
                       "data sync only")
    return {
        "verdict": "silent_in_window",
        "reasons": reasons,
        "hits": [],
        "telemetry_present": telemetry != [],
    }
