#!/usr/bin/env python3
"""Strict Firebase-silence verdict per the METHODOLOGY bar.

A "Firebase sent nothing" claim needs all of:
  - control traffic visible in the packet record (proves a negative is real),
  - a finished-profile capture window,
  - no Firebase data endpoint in either record (pcap or proxy log).

This module is pure logic: callers hand in host sets and flags.
"""
from __future__ import annotations

FIREBASE_NEEDLES = ("firebaseio.com", "firebasedatabase.googleapis.com")
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
      not_silent        - a Firebase data endpoint appeared in either record
      silent_in_window  - control seen, window valid, zero data-endpoint hits
      inconclusive      - prerequisites missing; no negative claim allowed

    Firebase telemetry (logging, measurement, remote config) is reported via
    telemetry_present and called out in the reasons - it must never be read
    as "Firebase sent nothing" full stop.
    """
    pcap = set(pcap_hosts or set())
    mitm = set(mitm_hosts or set())
    if not control_seen:
        return {
            "verdict": "inconclusive",
            "reasons": ["control traffic absent; the capture cannot prove a negative"],
            "hits": [],
            "telemetry_present": _hits(pcap | mitm, TELEMETRY_NEEDLES) != [],
        }
    hits = _hits(pcap | mitm, needles)
    telemetry = _hits(pcap | mitm, TELEMETRY_NEEDLES)
    if not window_profile_done:
        return {
            "verdict": "inconclusive",
            "reasons": ["capture window is not a finished-profile window"],
            "hits": hits,
            "telemetry_present": telemetry != [],
        }
    if hits:
        return {
            "verdict": "not_silent",
            "reasons": ["Firebase data endpoints present in the capture records"],
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
