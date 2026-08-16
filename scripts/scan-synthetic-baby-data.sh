#!/usr/bin/env bash
# Scan raw local captures for the synthetic baby-data transmission test.
#
# Usage:
#   scripts/scan-synthetic-baby-data.sh <capture.json|.mitm|dir> [output.json]
#
# The capture is a raw, local artifact that contains live secrets. It must
# NEVER be committed. This script only reads it locally and reports:
#   - which fictional marker strings (from results/synthetic-baby-profile.json)
#     appear in a request body, a response body, or a request URL
#   - the recipient host, path, method, and status for each match
#   - a per-app verdict of whether entered baby data left the device
#
# It deliberately emits NO adjacent body content, so the report is safe to
# commit even though the source capture is not. The committed, sanitized
# network logs cannot be used for this test: their bodies are replaced by
# redaction slugs, so the fictional values would be invisible there.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input="${1:?usage: scan-synthetic-baby-data.sh <capture.json|.mitm|dir> [output.json]}"
output_file="${2:-}"

PROFILE_FILE="${SYNTHETIC_PROFILE:-$repo_root/results/synthetic-baby-profile.json}"
if [ ! -f "$PROFILE_FILE" ]; then
    printf 'ERROR: profile not found: %s\n' "$PROFILE_FILE" >&2
    exit 1
fi
if [ ! -e "$input" ]; then
    printf 'ERROR: input does not exist: %s\n' "$input" >&2
    exit 1
fi

# Collect the list of capture files to scan.
declare -a captures=()
if [ -d "$input" ]; then
    while IFS= read -r f; do
        captures+=("$f")
    done < <(find "$input" -maxdepth 1 \( -name 'decode-traffic-*.json' -o -name '*.mitm' \) -type f | sort)
    if [ "${#captures[@]}" -eq 0 ]; then
        printf 'ERROR: no decode-traffic-*.json or *.mitm files in %s\n' "$input" >&2
        exit 1
    fi
else
    captures=("$input")
fi

python3 - "$PROFILE_FILE" "$repo_root" "${captures[@]}" "$output_file" <<'PY'
import json
import os
import sys
from pathlib import Path

profile_path = sys.argv[1]
repo_root_path = Path(sys.argv[2])
captures = sys.argv[3:-1]
output_file = sys.argv[-1] if sys.argv[-1] else None

# Same boundary-only vendor attribution used by scan-analytics-pii.sh. A host
# matches a vendor only when it equals the domain or ends with "." + domain, so
# an attacker-controlled host cannot be misattributed to a real vendor.
VENDOR_SUFFIXES = (
    ("Facebook", ("facebook.com", "fbcdn.net")),
    ("Microsoft Clarity", ("clarity.ms",)),
    ("AppsFlyer", ("appsflyersdk.com", "appsflyer.com")),
    ("Adjust", ("adjust.com",)),
    ("Scorecard Research", ("scorecardresearch.com",)),
    ("Localytics", ("localytics.com",)),
    ("Mixpanel", ("mixpanel.com",)),
    ("Vungle", ("vungle.com",)),
    ("TikTok Pangle", ("tiktokpangle.us", "tiktokpangle-cdn-us.com")),
    ("InMobi", ("inmobi.com",)),
    ("Cordial", ("cordial.com",)),
    ("Coralogix", ("coralogix.com", "rum-ingress-coralogix.com")),
    ("Adapty", ("adapty.io",)),
    ("RevenueCat", ("revenuecat.com",)),
    ("OneSignal", ("onesignal.com",)),
    ("Amazon Ads", ("amazon-adsystem.com",)),
    ("Snowplow", ("snowplowanalytics.com",)),
    ("Google/Firebase", (
        "googleapis.com", "google.com", "google-analytics.com", "firebase.google.com",
        "firebaseio.com", "app-measurement.com", "crashlytics.com", "doubleclick.net",
        "googleadservices.com", "googlesyndication.com", "gstatic.com", "android.apis.google.com",
    )),
)

KNOWN_FIRST_PARTY = {
    "com.babycenter.pregnancytracker": ("babycenter.com",),
    "com.nanit.baby": ("nanit.com",),
    "com.wte.view": ("whattoexpect.com",),
    "com.hp.pregnancy.lite": ("philips",),
    "com.bellyBloom.pregnancy.tracker": ("bellybloom",),
    "com.amila.parenting": ("amila",),
    "com.drillyapps.babydaybook": ("babydaybook", "drillyapps"),
    "com.hp.babyapp": ("hp.com", "babyapp"),
    "com.angry.shark.studio.nurturelock": ("nurturelock",),
    "com.clicksie.nuboapp": ("nubo", "clicksie"),
    "com.pebbi.android": ("pebbi.co",),
    "com.naraorganics.nara": ("nara",),
    "com.heartfulsprout.baby": ("heartful",),
    "com.pixykid.app": ("pixy",),
    "com.mimiapp.mimilog": ("mimilog",),
}


def vendor_for_host(host):
    host_lower = host.lower()
    for vendor, suffixes in VENDOR_SUFFIXES:
        if any(host_lower == s or host_lower.endswith("." + s) for s in suffixes):
            return vendor
    return "Unclassified host"


def recipient_class(host, package):
    v = vendor_for_host(host)
    if v != "Unclassified host":
        return "known_third_party"
    if package and package in KNOWN_FIRST_PARTY:
        host_lower = host.lower()
        for token in KNOWN_FIRST_PARTY[package]:
            token_lower = token.lower()
            if host_lower == token_lower or host_lower.endswith("." + token_lower):
                return "first_party_suspected"
    return "unknown_host"


def load_flows(path):
    """Return a list of normalized flows with searchable text. Supports both a
    decode-traffic JSON file and a raw .mitm capture (converted via mitmdump)."""
    flows = []
    ext = path.suffix.lower()
    if ext == ".mitm":
        import shutil
        from urllib.parse import urlparse
        har_dump = repo_root_path / "scripts" / "har_dump.py"
        if not har_dump.is_file():
            print(f"ERROR: mitm conversion script missing: {har_dump}", file=sys.stderr)
            raise SystemExit(1)
        if shutil.which("mitmdump") is None:
            print(f"ERROR: mitmdump not found in PATH; cannot convert {path}", file=sys.stderr)
            raise SystemExit(1)
        har = Path(path.parent) / f".{path.stem}-har.tmp"
        import subprocess
        try:
            subprocess.run(
                ["mitmdump", "-q", "-s",
                 str(har_dump),
                 "--set", f"har_output={har}", "-nr", str(path)],
                check=True, capture_output=True, timeout=60,
            )
        except (subprocess.CalledProcessError, FileNotFoundError) as exc:
            print(f"ERROR: could not convert {path} with mitmdump: {exc}", file=sys.stderr)
            raise SystemExit(1)
        try:
            data = json.loads(har.read_text())
        except (json.JSONDecodeError, OSError) as exc:
            print(f"ERROR: failed to read HAR for {path}: {exc}", file=sys.stderr)
            raise SystemExit(1)
        finally:
            har.unlink(missing_ok=True)
        for entry in data.get("log", {}).get("entries", []):
            req = entry.get("request", {})
            res = entry.get("response", {})
            url = req.get("url", "")
            flows.append({
                "method": req.get("method", "GET"),
                "url": url,
                "host": urlparse(url).hostname or "",
                "status": res.get("status", 0),
                "req_text": req.get("postData", {}).get("text", "") or "",
                "resp_text": res.get("content", {}).get("text", "") or "",
                "req_headers": " ".join(h.get("value", "") for h in req.get("headers", [])),
            })
        return flows

    # decode-traffic JSON
    try:
        data = json.loads(Path(path).read_text())
    except (json.JSONDecodeError, OSError) as exc:
        print(f"WARN: skipping unreadable capture {path}: {exc}", file=sys.stderr)
        return []
    if not isinstance(data, dict) or "flows" not in data:
        print(f"WARN: skipping malformed capture {path} (no flows)", file=sys.stderr)
        return []
    for flow in data.get("flows", []):
        req = flow.get("request") or {}
        res = flow.get("response") or {}
        body = req.get("body")
        if isinstance(body, (dict, list)):
            body = json.dumps(body)
        else:
            body = body or ""
        rbody = res.get("body")
        if isinstance(rbody, (dict, list)):
            rbody = json.dumps(rbody)
        else:
            rbody = rbody or ""
        headers = req.get("headers") or {}
        header_text = " ".join(str(v) for v in headers.values())
        flows.append({
            "method": req.get("method", "GET"),
            "url": req.get("url", ""),
            "host": req.get("host", "") or "",
            "status": res.get("status", 0),
            "req_text": body,
            "resp_text": rbody,
            "req_headers": header_text,
        })
    return flows


def main():
    # Validate profile path is within repo_root to avoid path traversal via SYNTHETIC_PROFILE
    profile_path_resolved = Path(profile_path).resolve()
    if not str(profile_path_resolved).startswith(str(repo_root_path.resolve())):
        print("ERROR: profile path outside repo root", file=sys.stderr)
        sys.exit(1)
    profile = json.loads(profile_path_resolved.read_text())
    # Minimal schema validation
    if profile.get("$schema") != "synthetic-baby-profile/1.0":
        print("ERROR: profile schema mismatch", file=sys.stderr)
        sys.exit(1)
    if "profile_name" not in profile or "description" not in profile:
        print("ERROR: profile missing required fields", file=sys.stderr)
        sys.exit(1)
    markers = profile.get("markers", [])
    if not markers:
        print("ERROR: profile has no markers", file=sys.stderr)
        sys.exit(1)
    for m in markers:
        if not all(k in m for k in ("id", "value", "type", "confidence")):
            print(f"ERROR: marker missing fields: {m}", file=sys.stderr)
            sys.exit(1)

    apps = []
    total_transmissions = 0
    for cap in captures:
        cap_path = Path(cap)
        try:
            data = json.loads(cap_path.read_text())
            package = data.get("package_name", "")
            app_name = data.get("app", cap_path.stem)
        except (json.JSONDecodeError, OSError):
            package = ""
            app_name = cap_path.stem
        flows = load_flows(cap_path)
        import re
        findings = []
        def marker_present(haystack, val):
            # Avoid substring false positives: require word boundaries for alphanumeric markers
            if not val:
                return False
            # If marker is purely numeric, require it to be bounded by non-digit or string edges
            if val.isdigit():
                pattern = r'(^|[^0-9])' + re.escape(val) + r'([^0-9]|$)'
                return re.search(pattern, haystack) is not None
            # For alphanumeric, use word boundaries
            pattern = r'(^|\W)' + re.escape(val) + r'(\W|$)'
            return re.search(pattern, haystack) is not None

        for flow in flows:
            haystack_req = (flow["req_text"] + " " + flow["req_headers"]).lower()
            haystack_resp = flow["resp_text"].lower()
            haystack_url = flow["url"].lower()
            for marker in markers:
                val = str(marker["value"]).lower()
                if not val:
                    continue
                in_req = marker_present(haystack_req, val)
                in_resp = marker_present(haystack_resp, val)
                in_url = marker_present(haystack_url, val)
                if not (in_req or in_resp or in_url):
                    continue
                side = "request" if in_req else ("response" if in_resp else "url")
                findings.append({
                    "marker_id": marker.get("id"),
                    "marker_type": marker.get("type"),
                    "marker_confidence": marker.get("confidence"),
                    "method": flow["method"],
                    "host": flow["host"],
                    "path": flow["url"],
                    "status": flow["status"],
                    "vendor": vendor_for_host(flow["host"]),
                    "recipient_class": recipient_class(flow["host"], package),
                    "side": side,
                })
        transmission = any(f["side"] in ("request", "url") for f in findings)
        recipients = sorted({f["host"] for f in findings})
        # A high/medium string marker in a request/url is a direct transmission.
        # A numeric/low marker in a request/url is supporting evidence only.
        strong = any(
            f["side"] in ("request", "url")
            and f["marker_confidence"] in ("high", "medium")
            and f["marker_type"] in ("string", "name", "note")
            for f in findings
        )
        high_transmission = strong
        if high_transmission:
            total_transmissions += 1
        verdict = "transmission_observed" if high_transmission else "no_transmission_detected"
        apps.append({
            "app": app_name,
            "package_name": package,
            "capture": str(cap_path),
            "flows_scanned": len(flows),
            "markers_matched": len(findings),
            "transmission_observed": high_transmission,
            "recipients": recipients,
            "verdict": verdict,
            "findings": findings,
        })

    output = {
        "$schema": "synthetic-baby-data/1.0",
        "schema_version": "1.0",
        "profile_name": profile.get("profile_name", ""),
        "profile_source": str(profile_path),
        "captures_scanned": len(captures),
        "apps_with_transmission": total_transmissions,
        "scope": "Markers come from the fictional synthetic baby profile. A match in a request body or URL proves the entered value left the device. The committed, sanitized network logs are not searched because their bodies are redacted.",
        "apps": apps,
    }
    text = json.dumps(output, indent=2) + "\n"
    if output_file:
        out_path = Path(output_file).resolve()
        if not str(out_path).startswith(str(repo_root_path.resolve())):
            print("ERROR: output path outside repo root", file=sys.stderr)
            sys.exit(1)
        Path(out_path).write_text(text)
    else:
        print(text, end="")


main()
PY
