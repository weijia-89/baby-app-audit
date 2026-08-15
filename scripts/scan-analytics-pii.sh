#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input_dir="${1:-$repo_root/results}"
output_file="${2:-}"

if [ ! -d "$input_dir" ]; then
    printf 'ERROR: input directory does not exist: %s\n' "$input_dir" >&2
    exit 1
fi

python3 - "$input_dir" "$output_file" <<'PY'
import json
import sys
from collections import defaultdict
from pathlib import Path

input_dir = Path(sys.argv[1])
# output_file is optional; when omitted the scan prints to stdout.
output_file = sys.argv[2] if len(sys.argv) > 2 else None

# Vendor attribution uses FULL-DOMAIN boundary matching only. A host is
# attributed to a vendor when it equals a known domain or ends with "." + that
# domain. Substring matching is intentionally avoided: an attacker-controlled
# host such as "evilgoogle.com.attacker.net" must never be attributed to a
# real vendor. Every suffix below is a full registrable domain (or a known
# exact host) so boundary matching is both safe and complete for observed traffic.
VENDOR_SUFFIXES = (
    ("Facebook", ("facebook.com", "fbcdn.net")),
    ("Microsoft Clarity", ("clarity.ms",)),
    ("AppsFlyer", ("appsflyer.com", "appsflyersdk.com")),
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
    ("Sentry", ("sentry.io",)),
    ("Bugsnag", ("bugsnag.com",)),
    ("New Relic", ("newrelic.com",)),
    ("Datadog", ("datadoghq.com",)),
    ("FullStory", ("fullstory.com",)),
    ("Smartlook", ("smartlook.com",)),
    ("UXCam", ("uxcam.com",)),
    ("Appsee", ("appsee.com",)),
    ("Glassbox", ("glassbox.com",)),
    ("LogRocket", ("logrocket.com",)),
    ("Contentsquare", ("contentsquare.com",)),
    ("Heap", ("heap.io",)),
    ("Quantum Metric", ("quantummetric.com",)),
    ("Mouseflow", ("mouseflow.com",)),
    ("Hotjar", ("hotjar.com",)),
    ("Instabug", ("instabug.com",)),
    (
        "Google/Firebase",
        (
            "googleapis.com",
            "google.com",
            "google-analytics.com",
            "firebase.google.com",
            "firebaseio.com",
            "app-measurement.com",
            "crashlytics.com",
            "doubleclick.net",
            "googleadservices.com",
            "googlesyndication.com",
            "gstatic.com",
            "android.apis.google.com",
        ),
    ),
)

ROLE_TOKENS = {
    "session_replay": (
        "clarity",
        "fullstory",
        "smartlook",
        "uxcam",
        "appsee",
        "glassbox",
        "screen",
        "replay",
        "upload-asset",
        "/rum",
    ),
    "analytics": (
        "analytics",
        "/track",
        "/event",
        "/activities",
        "/collect",
        "/batch",
        "/logs",
        "/tp2",
        "/profile",
        "/uploads",
        "/firelog",
        "app-measurement",
    ),
    "attribution": (
        "appsflyer",
        "adjust",
        "attribution",
        "install_data",
        "dlsdk",
        "pia-android",
    ),
    "advertising": (
        "ads",
        "adnw",
        "pangle",
        "doubleclick",
        "inmobi",
        "vungle",
        "scorecard",
        "amazon-ads",
    ),
    "diagnostics": ("crash", "crashlytics", "rum", "/error"),
    "account_or_messaging": ("cordial", "/auth", "/contacts", "onesignal", "c2dm"),
    "sdk_configuration": (
        "config",
        "settings",
        "pubsetting",
        "mobile_sdk_gk",
        "model_asset",
        "android_params",
    ),
    "identifier_registration": ("installations", "register_dev", "update_dev_info"),
}

IDENTIFIER_KEYS = {
    "adid",
    "fid",
    "identityid",
    "ol_id",
    "install_time",
    "app_token",
}
TOKEN_KEYS = {"token", "authtoken", "refreshtoken", "authorization"}
SENSITIVE_HEADERS = {
    "authorization",
    "x-api-key",
    "x-goog-api-key",
    "x-firebase-client",
    "x-android-cert",
    "x-android-package",
    "x-apikey",
}


def vendor_for_host(host):
    # Boundary-only matching: a host matches a vendor suffix only when it
    # equals the domain or ends with "." + domain. This prevents an
    # attacker-controlled host (e.g. "evilgoogle.com.attacker.net") from being
    # misattributed to a real vendor, which would corrupt the audit's data-flow
    # findings. Every suffix in VENDOR_SUFFIXES is a full domain for this reason.
    host_lower = host.lower()
    for vendor, suffixes in VENDOR_SUFFIXES:
        if any(host_lower == suffix or host_lower.endswith("." + suffix) for suffix in suffixes):
            return vendor
    return "Unclassified host"


def roles_for(vendor, host, path):
    text = (vendor + " " + host + " " + path).lower()
    roles = []
    for role, tokens in ROLE_TOKENS.items():
        if any(token in text for token in tokens):
            roles.append(role)
    return sorted(set(roles))


def body_keys(flow, side):
    detail = flow.get(side) or {}
    keys = detail.get("body_keys")
    return set(keys or []) if isinstance(keys, list) else set()


def request_detail(flow):
    return flow.get("request") if isinstance(flow.get("request"), dict) else None


def response_detail(flow):
    return flow.get("response") if isinstance(flow.get("response"), dict) else None


def redaction_slugs(flow):
    slugs = list(flow.get("redactions") or [])
    request = request_detail(flow)
    response = response_detail(flow)
    if request:
        if request.get("size", 0) > 0 and request.get("body_keys") is None:
            slugs.append("[REDACTED:request-body-values:secret-or-PII]")
        if any(str(header).lower() in SENSITIVE_HEADERS for header in request.get("headers", [])):
            slugs.append("[REDACTED:request-header-values:secret-or-PII]")
    if response and response.get("size", 0) > 0 and response.get("body_keys") is None:
        slugs.append("[REDACTED:response-body-values:secret-or-PII]")
    if "[REDACTED" in str(flow.get("path", "")):
        slugs.append("[REDACTED:path-token-or-id:secret-or-PII]")
    if not slugs and isinstance(flow.get("path"), str) and flow.get("path") == "(destination only)":
        slugs.append("[REDACTED:legacy-log:body-and-header-values]")
    return sorted(set(slugs))


def assessments(flow):
    values = []
    request = request_detail(flow)
    response = response_detail(flow)
    if request is None:
        values.append("destination_only")
    else:
        if request.get("size", 0) > 0 and request.get("body_keys") is None:
            values.append("call_sent_body_scrubbed")
        if any(str(header).lower() in SENSITIVE_HEADERS for header in request.get("headers", [])):
            values.append("call_sent_header_value_scrubbed")
    if response and response.get("body_keys"):
        values.append("response_key_names_observed_values_scrubbed")
        response_keys = {str(key).lower() for key in response.get("body_keys")}
        if {"screencapture", "webviewcapture"} & response_keys:
            values.append("capability_observed")
    if not values and request is not None:
        values.append("call_metadata_only")
    return sorted(set(values))


def pii_categories(vendor, host, path, flow, roles):
    text = (vendor + " " + host + " " + path).lower()
    request = request_detail(flow) or {}
    response = response_detail(flow) or {}
    request_headers = {str(header).lower() for header in request.get("headers", [])}
    response_keys = {str(key).lower() for key in response.get("body_keys") or []}
    categories = set()

    if vendor == "Facebook":
        if "/activities" in path.lower():
            categories.update({"app_activity_events", "device_or_app_identifiers", "advertising_or_attribution"})
        elif "adnw_sync" in path.lower():
            categories.update({"device_or_app_identifiers", "advertising_or_attribution"})
    if vendor == "Microsoft Clarity":
        if "screencapture" in response_keys or "webviewcapture" in response_keys:
            categories.add("screen_content_and_interactions")
        if "/collect" in path.lower():
            categories.add("screen_content_and_interactions")
        if "upload-asset" in path.lower():
            categories.add("screen_images_or_assets")
    if "/contacts" in path.lower():
        categories.add("contact_data")
    if "/auth" in path.lower() or "authorization" in request_headers:
        categories.add("account_or_authentication_data")
    if "semanticlocation" in text or "location" in path.lower():
        categories.add("location_data")
    if response_keys & IDENTIFIER_KEYS:
        categories.add("device_or_app_identifiers")
    if response_keys & TOKEN_KEYS:
        categories.add("authentication_tokens")
    if "app_activity_events" not in categories and "analytics" in roles and vendor != "Unclassified host":
        categories.add("app_activity_events")
    if "advertising" in roles or "attribution" in roles:
        categories.add("advertising_or_attribution")
    return sorted(categories)


def is_analytics_call(roles, categories):
    return bool(set(roles) & {"analytics", "attribution", "advertising", "diagnostics", "session_replay", "account_or_messaging"}) or bool(categories)


logs = sorted(input_dir.glob("network-log-*.json"))
if not logs:
    print(f"ERROR: no network logs found in {input_dir}", file=sys.stderr)
    sys.exit(1)

apps = []
vendor_map = defaultdict(lambda: {"hosts": set(), "apps": set(), "call_count": 0, "roles": set(), "pii_categories": set(), "assessments": set()})
total_calls = 0
# Resolve the results summary by glob so the scan does not break if the
# capture date in the filename changes. The package names from any
# RESULTS-*.json in the input dir scope which network logs are in scope.
results_files = sorted(input_dir.glob("RESULTS-*.json"))
result_path = results_files[0] if results_files else None
result_data = json.loads(result_path.read_text()) if result_path is not None else None
result_packages = {
    app.get("package_name")
    for app in (result_data or {}).get("apps", [])
}

for log_path in logs:
    data = json.loads(log_path.read_text())
    if result_data is not None and data.get("package_name") not in result_packages:
        continue
    app_name = data.get("app", log_path.stem.removeprefix("network-log-"))
    package_name = data.get("package_name", "")
    calls = []
    analytics_call_count = 0
    pii_call_count = 0
    unassessed_call_count = 0
    for flow in data.get("flows", []):
        host = str(flow.get("host", ""))
        path = str(flow.get("path", ""))
        vendor = vendor_for_host(host)
        roles = roles_for(vendor, host, path)
        assessments_for_flow = assessments(flow)
        categories = pii_categories(vendor, host, path, flow, roles)
        slugs = redaction_slugs(flow)
        count = flow.get("count", 1)
        count = count if isinstance(count, int) and count > 0 else 1
        analytics = is_analytics_call(roles, categories)
        if analytics:
            analytics_call_count += count
        if categories:
            pii_call_count += count
        if "call_sent_body_scrubbed" in assessments_for_flow:
            unassessed_call_count += count
        if categories and "call_sent_body_scrubbed" not in assessments_for_flow and "capability_observed" not in assessments_for_flow:
            assessments_for_flow.append("capability_or_endpoint_inference")
            assessments_for_flow.sort()
        total_calls += count
        vendor_entry = vendor_map[vendor]
        vendor_entry["hosts"].add(host)
        vendor_entry["apps"].add(app_name)
        vendor_entry["call_count"] += count
        vendor_entry["roles"].update(roles)
        vendor_entry["pii_categories"].update(categories)
        vendor_entry["assessments"].update(assessments_for_flow)
        calls.append({
            "method": flow.get("method", "unknown"),
            "host": host,
            "path": path,
            "status": flow.get("status", "unknown"),
            "count": count,
            "vendor": vendor,
            "roles": roles,
            "sent_call": True,
            "request_size": (request_detail(flow) or {}).get("size"),
            "response_size": (response_detail(flow) or {}).get("size"),
            "analytics_call": analytics,
            "pii_categories": categories,
            "assessments": assessments_for_flow,
            "redaction_slugs": slugs,
        })
    apps.append({
        "app": app_name,
        "package_name": package_name,
        "call_count": sum(call["count"] for call in calls),
        "analytics_call_count": analytics_call_count,
        "pii_call_count": pii_call_count,
        "unassessed_call_count": unassessed_call_count,
        "calls": calls,
    })

static_capabilities = []
for result_app in (result_data or {}).get("apps", []):
    for tracker_name in (result_app.get("static_scan") or {}).get("tracker_names", []):
        static_capabilities.append({
            "app": result_app.get("name", ""),
            "package_name": result_app.get("package_name", ""),
            "name": tracker_name,
            "assessment": "capability_only",
        })

output = {
    "$schema": "analytics-pii/1.0",
    "schema_version": "1.0",
    "scope": {
        "input_pattern": "network-log-*.json",
        "apps_scanned": len(apps),
        "calls_scanned": total_calls,
        "assessment_rule": "A sent call remains evidence even when body or header values are scrubbed. Scrubbed content is not evidence that PII was absent.",
    },
    "static_capabilities": static_capabilities,
    "vendors": [
        {
            "vendor": vendor,
            "hosts": sorted(values["hosts"]),
            "apps": sorted(values["apps"]),
            "call_count": values["call_count"],
            "roles": sorted(values["roles"]),
            "pii_categories": sorted(values["pii_categories"]),
            "assessments": sorted(values["assessments"]),
        }
        for vendor, values in sorted(vendor_map.items())
    ],
    "apps": apps,
}

text = json.dumps(output, indent=2) + "\n"
if output_file:
    Path(output_file).write_text(text)
else:
    print(text, end="")
PY
