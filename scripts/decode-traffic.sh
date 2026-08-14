#!/usr/bin/env bash
# decode-traffic.sh v2  -  Decode HAR captures into structured JSON
# Usage: ./decode-traffic.sh <capture.har> <package_name> [output.json]
# Version: 2.0

set -euo pipefail

readonly SCRIPT_VERSION="2.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[DECODE v${SCRIPT_VERSION}]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <capture.har> <package_name> [output.json]

Decode a HAR capture file into structured JSON conforming to decode-traffic schema v2.

Arguments:
  capture.har    Path to the HAR file (must exist, must be valid JSON)
  package_name   Android package name or web app identifier to filter flows
  output.json    Optional output path (default: stdout)

Environment:
  MITMPROXY_VERSION  Recorded in output if set
  FRIDA_VERSION      Recorded in output if set
  EXODUS_VERSION     Recorded in output if set

Returns:
  0 on success, 1 on error
EOF
}

# Handle flags before positional args
case "${1:-}" in
    --version)
        echo "$SCRIPT_VERSION"
        exit 0
        ;;
    --check)
        echo "Checking dependencies for decode-traffic.sh..."
        for dep in python3 jq; do
            if command -v "$dep" >/dev/null 2>&1; then
                echo "  OK: $dep"
            else
                echo "  MISSING: $dep"
                exit 1
            fi
        done
        echo "All dependencies present"
        exit 0
        ;;
esac

# Validate inputs
if [ $# -lt 2 ]; then
    usage
    exit 1
fi

HAR_FILE="$1"
PACKAGE_NAME="$2"
OUTPUT_FILE="${3:-}"

# HAR file must exist and be readable
if [ ! -f "$HAR_FILE" ]; then
    error "HAR file not found: $HAR_FILE"
    exit 1
fi

if [ ! -r "$HAR_FILE" ]; then
    error "HAR file not readable: $HAR_FILE"
    exit 1
fi

# If output file specified, ensure parent directory exists and is writable
if [ -n "$OUTPUT_FILE" ]; then
    OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
    if [ ! -d "$OUTPUT_DIR" ]; then
        error "Output directory does not exist: $OUTPUT_DIR"
        exit 1
    fi
    if [ ! -w "$OUTPUT_DIR" ]; then
        error "Output directory is not writable: $OUTPUT_DIR"
        exit 1
    fi
fi
# Validate package name: no shell metacharacters or path separators (prevents traversal)
if [[ "$PACKAGE_NAME" =~ [\"\`\'\$\;\|\&\<\>\/] ]] || [[ "$PACKAGE_NAME" == *$'\n'* ]]; then
    error "Invalid characters in package_name"
    exit 1
fi

# Validate HAR is valid JSON and contains entries array
if ! python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if "log" in d and "entries" in d.get("log",{}) else 1)' "$HAR_FILE" 2>/dev/null; then
    error "Invalid HAR file: missing log.entries"
    exit 1
fi

# Extract host from package name for filtering
# For package names like com.example.app, we filter by the last two segments or full name
FILTER_HOST=""
case "$PACKAGE_NAME" in
    com.angry.shark.studio.nurturelock)
        FILTER_HOST="nurturelock"
        ;;
    com.clicksie.nuboapp)
        FILTER_HOST="nubo"
        ;;
    com.pebbi.android)
        FILTER_HOST="pebbi"
        ;;
    com.babytrack.app)
        FILTER_HOST="babytrack"
        ;;
    com.amila.babytracker)
        FILTER_HOST="amila"
        ;;
    com.amila.parenting)
        FILTER_HOST="amila"
        ;;
    com.sociodigitals.babytrack)
        FILTER_HOST="babytrack"
        ;;
    com.wachanga.babymilestones)
        FILTER_HOST="wachanga"
        ;;
    com.owletcare.sock)
        FILTER_HOST="owletcare"
        ;;
    com.owletcare.cam)
        FILTER_HOST="owletcare"
        ;;
    com.babycenter.pregnancytracker)
        FILTER_HOST="babycenter"
        ;;
    com.nanit.baby)
        FILTER_HOST="nanit"
        ;;
    com.wte.view)
        FILTER_HOST="whattoexpect"
        ;;
    com.hp.pregnancy.lite)
        FILTER_HOST="pregnancyplus"
        ;;
    com.bellyBloom.pregnancy.tracker)
        FILTER_HOST="bellybloom"
        ;;
    *)
        # Fallback: use the last segment of the package name
        FILTER_HOST="${PACKAGE_NAME##*.}"
        ;;
esac

CAPTURE_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build tool versions object
TOOL_VERSIONS="{}"
if [ -n "${MITMPROXY_VERSION:-}" ]; then
    TOOL_VERSIONS=$(echo "$TOOL_VERSIONS" | jq --arg v "$MITMPROXY_VERSION" '.mitmproxy = $v')
fi
if [ -n "${FRIDA_VERSION:-}" ]; then
    TOOL_VERSIONS=$(echo "$TOOL_VERSIONS" | jq --arg v "$FRIDA_VERSION" '.frida = $v')
fi
if [ -n "${EXODUS_VERSION:-}" ]; then
    TOOL_VERSIONS=$(echo "$TOOL_VERSIONS" | jq --arg v "$EXODUS_VERSION" '.exodus_cli = $v')
fi

# Process HAR entries with Python for reliability
PYTHON_SCRIPT=$(cat <<'PYEOF'
import json
import sys
import re
import os
from urllib.parse import urlparse

har_path = sys.argv[1]
package_name = sys.argv[2]
filter_host = sys.argv[3]

try:
    with open(har_path, 'r', encoding='utf-8') as f:
        har = json.load(f)
except (json.JSONDecodeError, UnicodeDecodeError) as e:
    print(f"ERROR: Failed to parse HAR: {e}", file=sys.stderr)
    sys.exit(1)

entries = har.get('log', {}).get('entries', [])
flows = []
tracker_flows = 0
unique_dests = set()
unique_trackers = set()

# Known tracker domains for classification
TRACKER_DOMAINS = {
    'google-analytics.com': 'Google Analytics',
    'firebase.google.com': 'Firebase',
    'firebaseio.com': 'Firebase',
    'crashlytics.com': 'Firebase Crashlytics',
    'app-measurement.com': 'Firebase Analytics',
    'googleapis.com': 'Google',
    'google.com': 'Google',
    'gstatic.com': 'Google',
    'googleadservices.com': 'Google Ads',
    'googlesyndication.com': 'Google Syndication',
    'doubleclick.net': 'DoubleClick',
    'mixpanel.com': 'Mixpanel',
    'facebook.com': 'Facebook',
    'fbcdn.net': 'Facebook',
    'appsflyer.com': 'AppsFlyer',
    'appsflyersdk.com': 'AppsFlyer',
    'adjust.com': 'Adjust',
    'clarity.ms': 'Microsoft Clarity',
    'scorecardresearch.com': 'Scorecard Research',
    'onesignal.com': 'OneSignal',
    'clevertap.com': 'CleverTap',
    'tenjin.com': 'Tenjin',
    'revenuecat.com': 'RevenueCat',
}

# Mechanism classification patterns
RTB_PATTERNS = ['bid', 'auction', 'rtb', 'exchange', 'ssp', 'dsp']
BROKER_PATTERNS = ['sale', 'broker', 'marketplace', 'dataexchange', 'audience']

def classify_mechanism(url, headers):
    url_lower = url.lower()
    for p in RTB_PATTERNS:
        if p in url_lower:
            return 'realtime_bidding'
    for p in BROKER_PATTERNS:
        if p in url_lower:
            return 'data_broker_sale'
    # Check for analytics-like paths
    if any(x in url_lower for x in ['/analytics', '/event', '/track', '/collect']):
        return 'analytics'
    if any(x in url_lower for x in ['/crash', '/error']):
        return 'crash_reporting'
    if 'firebase' in url_lower:
        return 'firebase'
    return 'unknown'

def is_tracker_domain(host):
    host_lower = host.lower()
    for domain, name in TRACKER_DOMAINS.items():
        if host_lower == domain or host_lower.endswith('.' + domain):
            return True, name
    return False, None

def safe_body(body_data):
    """Return body as string if JSON or form-encoded, else null."""
    if body_data is None:
        return None
    if isinstance(body_data, dict):
        return body_data
    if isinstance(body_data, str):
        text = body_data.strip()
        if not text:
            return None
        # Try JSON
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass
        # Form-encoded: at least one key=value pair
        if '=' in text:
            result = {}
            for pair in text.split('&'):
                if '=' in pair:
                    k, v = pair.split('=', 1)
                    result[k] = v
            return result
        # Binary/chunked: skip
        if any(c in text[:20] for c in ['\x00', '\x01', '\x02']):
            return None
        return text
    return None

for entry in entries:
    req = entry.get('request', {})
    resp = entry.get('response', {})
    
    url = req.get('url', '')
    parsed = urlparse(url)
    host = parsed.hostname or ''
    
    # Filter: attribute flow to the app when any of these hold:
    #   1. filter_host appears as a hostname label (e.g. app.pebbi.co -> "pebbi")
    #   2. host == filter_host or ends with '.'+filter_host (legacy exact-suffix match)
    #   3. package name appears in the URL
    #   4. package name appears in a request header value (e.g. X-Client-Bundle-ID, X-Android-Package)
    #   5. package name appears in the request body (e.g. Firebase batchlog packageName field)
    host_lower = host.lower()
    labels = set(host_lower.split('.'))
    filter_in_host = (host_lower == filter_host
                      or host_lower.endswith('.' + filter_host)
                      or (filter_host and filter_host in labels))
    req_headers_all = req.get('headers', [])
    header_match = any(
        package_name.lower() in (h.get('value') or '').lower()
        for h in req_headers_all
    )
    body_text = (req.get('postData') or {}).get('text') or ''
    body_match = package_name.lower() in body_text.lower()
    if not (filter_in_host or package_name.lower() in url.lower() or header_match or body_match):
        continue
    
    is_tracker, tracker_name = is_tracker_domain(host)
    mechanism = classify_mechanism(url, req.get('headers', []))
    
    req_headers = {}
    for h in req.get('headers', []):
        req_headers[h.get('name', '')] = h.get('value', '')
    
    resp_headers = {}
    for h in resp.get('headers', []):
        name = h.get('name', '')
        value = h.get('value', '')
        if name.lower() in ['set-cookie', 'cache-control', 'expires']:
            resp_headers[name] = value
    
    req_body = safe_body(req.get('postData', {}).get('text'))
    resp_body = safe_body(resp.get('content', {}).get('text'))
    
    flow = {
        'timestamp': entry.get('startedDateTime', ''),
        'request': {
            'method': req.get('method', 'GET'),
            'url': url,
            'host': host,
            'headers': req_headers,
            'body': req_body,
            'body_size_bytes': max(0, req.get('bodySize', 0))
        },
        'response': {
            'status': resp.get('status', 0),
            'headers': resp_headers,
            'body': resp_body,
            'body_size_bytes': max(0, resp.get('bodySize', 0))
        },
        'classification': {
            'is_tracker': is_tracker,
            'tracker_source': tracker_name or 'unknown',
            'protocol': parsed.scheme or 'unknown',
            'mechanism': mechanism
        }
    }
    flows.append(flow)
    
    if is_tracker:
        tracker_flows += 1
        unique_trackers.add(tracker_name)
    unique_dests.add(host)

# Per-product metadata loaded from external config
config_file = os.environ.get('PRODUCT_CONFIG', sys.argv[4] if len(sys.argv) > 4 else 'results/product-metadata.json')
product_metadata = {}
if os.path.isfile(config_file):
    try:
        with open(config_file, 'r') as cf:
            config = json.load(cf)
            product_metadata = config.get('products', {}).get(package_name, config.get('default', {}))
    except (json.JSONDecodeError, IOError):
        product_metadata = {}

if not product_metadata:
    product_metadata = {
        'retention_schedule': {'policy_days': 0, 'policy_description': 'unknown', 'indefinite': False},
        'security_eol': {'eol_date': 'unknown', 'device_model': 'unknown', 'eol_confidence': 'unknown'},
        'cve_list': [],
        'regulatory_regime': 'unknown',
        'device_identity': {'basic_udi_di': '', 'model_number': '', 'regime': 'unknown'}
    }

output = {
    '$schema': 'decode-traffic/2.0',
    'schema_version': '2.0',
    'package_name': package_name,
    'capture_timestamp': os.environ.get('CAPTURE_TIMESTAMP', ''),
    'tool_versions': json.loads(os.environ.get('TOOL_VERSIONS', '{}')),
    'flows': flows,
    'summary': {
        'total_flows': len(flows),
        'tracker_flows': tracker_flows,
        'unique_destinations': sorted(unique_dests),
        'unique_trackers': sorted(unique_trackers)
    },
    'product_metadata': product_metadata
}

print(json.dumps(output, indent=2))
PYEOF
)

export CAPTURE_TIMESTAMP
export TOOL_VERSIONS

log "Decoding HAR: $HAR_FILE for package: $PACKAGE_NAME"

# Run Python decoder
CONFIG_FILE="$(dirname "$0")/../results/product-metadata.json"
DECODED=$(python3 -c "$PYTHON_SCRIPT" "$HAR_FILE" "$PACKAGE_NAME" "$FILTER_HOST" "$CONFIG_FILE" 2>&1) || {
    error "Failed to decode HAR: $DECODED"
    exit 1
}

# Validate output against schema if available
SCHEMA_FILE="${SCHEMA_FILE:-$(dirname "$0")/../results/decode-traffic.schema.json}"
export SCHEMA_FILE
STRICT_MODE="${DECODE_TRAFFIC_STRICT:-0}"
if [ -f "$SCHEMA_FILE" ] && command -v python3 >/dev/null 2>&1; then
    if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SCHEMA_FILE" 2>/dev/null; then
        if python3 -c 'import jsonschema' 2>/dev/null; then
            VALIDATION_OUTPUT=$(printf '%s' "$DECODED" | python3 -c "
import json, sys, jsonschema, os
schema = json.load(open(os.environ['SCHEMA_FILE']))
data = json.load(sys.stdin)
try:
    jsonschema.validate(data, schema)
    sys.exit(0)
except jsonschema.ValidationError as e:
    print(f'SCHEMA_ERROR: {e.message}', file=sys.stderr)
    sys.exit(1)
" 2>&1) || VALIDATION_STATUS=$?
            VALIDATION_STATUS=${VALIDATION_STATUS:-0}
            if [ "$VALIDATION_STATUS" -eq 0 ]; then
                log "Output validated against schema: $SCHEMA_FILE"
            else
                if [ "$STRICT_MODE" = "1" ]; then
                    error "Output does not conform to schema (strict mode enabled)"
                    printf '%s\n' "$VALIDATION_OUTPUT" >&2
                    exit 1
                else
                    warn "Output does not conform to schema (install jsonschema for full validation)"
                fi
            fi
        else
            if [ "$STRICT_MODE" = "1" ]; then
                error "jsonschema module required for strict mode validation"
                exit 1
            else
                log "Schema file readable (install jsonschema for full validation): $SCHEMA_FILE"
            fi
        fi
    fi
fi

# Output
if [ -n "$OUTPUT_FILE" ]; then
    printf '%s' "$DECODED" > "$OUTPUT_FILE"
    log "Output written to: $OUTPUT_FILE"
else
    printf '%s' "$DECODED"
fi

log "Decoded $(printf '%s' "$DECODED" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('flows',[])))") flows"
exit 0
