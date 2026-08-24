#!/usr/bin/env bash
# Compare network findings across apps.
# Usage: ./compare-apps.sh <app1.json> <app2.json> [app3.json ...] [output.json]
# Version: 1.0

set -euo pipefail

readonly SCRIPT_VERSION="1.0"

. "$(dirname "$0")/lib/common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") <app1.json> <app2.json> [app3.json ...] [output.json]

Compare decoded traffic data across two or more apps.

Arguments:
  appN.json    Decoded traffic JSON files (from decode-traffic.sh)
  output.json  Optional output path (default: stdout)

Options:
  --version    Show version and exit

Returns:
  0 on success, 1 on error
EOF
}

case "${1:-}" in
    --version)
        echo "$SCRIPT_VERSION"
        exit 0
        ;;
    --check)
        echo "Checking dependencies for compare-apps.sh..."
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

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

# Parse input files and the optional output file.
# With 3+ args, the last arg is the output path.
# With 2 args, both are inputs; print to stdout.
INPUT_FILES=()
OUTPUT_FILE=""

if [ $# -eq 2 ]; then
    # Two args: both are input files.
    for arg in "$@"; do
        if [ -f "$arg" ]; then
            if python3 -m json.tool "$arg" >/dev/null 2>&1; then
                INPUT_FILES+=("$arg")
            else
                error "Invalid JSON file: $arg"
                exit 1
            fi
        else
            error "File not found: $arg"
            exit 1
        fi
    done
elif [ $# -ge 3 ]; then
    # 3+ args: last arg is output file, rest are inputs
    # Validate all but last arg
    all_but_last=()
    idx=0
    for arg in "$@"; do
        idx=$((idx + 1))
        if [ "$idx" -eq "$#" ]; then
            OUTPUT_FILE="$arg"
        else
            all_but_last+=("$arg")
        fi
    done
    for arg in "${all_but_last[@]}"; do
        if [ -f "$arg" ]; then
            if python3 -m json.tool "$arg" >/dev/null 2>&1; then
                INPUT_FILES+=("$arg")
            else
                error "Invalid JSON file: $arg"
                exit 1
            fi
        else
            error "File not found: $arg"
            exit 1
        fi
    done
fi

if [ ${#INPUT_FILES[@]} -lt 2 ]; then
    error "At least two valid JSON input files required"
    exit 1
fi

# Check that the output directory is writable.
check_output_dir "$OUTPUT_FILE" || exit 1

COMPARISON_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
export COMPARISON_TIMESTAMP

# Build the comparison with an embedded Python block.
    TEMP_SCRIPT=$(mktemp "${TMPDIR:-/tmp}/compare-XXXXXX.py")
trap 'rm -f "$TEMP_SCRIPT"' EXIT INT TERM

cat > "$TEMP_SCRIPT" <<'PYEOF'
import json
import os
import sys
from collections import defaultdict

input_files = sys.argv[1:]

apps = []
all_trackers = defaultdict(set)
all_endpoints = defaultdict(lambda: defaultdict(int))
all_mechanisms = defaultdict(set)
data_volume = {}
regime_coverage = {}

for f in input_files:
    try:
        with open(f, 'r') as fh:
            data = json.load(fh)
    except (json.JSONDecodeError, IOError) as e:
        print(f"ERROR: Failed to load {f}: {e}", file=sys.stderr)
        sys.exit(1)

    # Check the JSON has the required fields.
    if not isinstance(data.get('package_name'), str):
        print(f"ERROR: Missing or invalid package_name in {f}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(data.get('summary'), dict):
        print(f"ERROR: Missing or invalid summary in {f}", file=sys.stderr)
        sys.exit(1)

    package_name = data.get('package_name', 'unknown')
    apps.append(package_name)

    summary = data.get('summary', {})
    flows = data.get('flows', [])
    metadata = data.get('product_metadata', {})

    for tracker in summary.get('unique_trackers', []):
        all_trackers[tracker].add(package_name)

    # Endpoints, plus unique_destinations from the summary.
    for host in summary.get('unique_destinations', []):
        if host:
            all_endpoints[host][package_name] += 1

    # Mechanisms from flows.
    for flow in flows:
        mechanism = flow.get('classification', {}).get('mechanism', '')
        if mechanism and mechanism != 'unknown':
            all_mechanisms[mechanism].add(package_name)

    total_req = sum(max(0, flow.get('request', {}).get('body_size_bytes', 0)) for flow in flows)
    total_resp = sum(max(0, flow.get('response', {}).get('body_size_bytes', 0)) for flow in flows)
    data_volume[package_name] = {
        'total_flows': summary.get('total_flows', 0),
        'tracker_flows': summary.get('tracker_flows', 0),
        'total_request_bytes': total_req,
        'total_response_bytes': total_resp
    }

    regime_coverage[package_name] = metadata.get('regulatory_regime', 'unknown')

# Trackers seen in more than one app.
shared_trackers = [t for t, app_set in all_trackers.items() if len(app_set) > 1]

# Endpoints seen in more than one app.
similar_endpoints = []
for host, app_counts in all_endpoints.items():
    if len(app_counts) > 1:
        similar_endpoints.append({
            'host': host,
            'apps': sorted(app_counts.keys()),
            'flow_counts': dict(app_counts)
        })

# Mechanisms seen in more than one app.
shared_mechanisms = [m for m, app_set in all_mechanisms.items() if len(app_set) > 1]

output = {
    'apps': apps,
    'comparison_timestamp': os.environ.get('COMPARISON_TIMESTAMP', ''),
    'shared_trackers': sorted(shared_trackers),
    'similar_endpoints': sorted(similar_endpoints, key=lambda x: x['host']),
    'data_volume': data_volume,
    'regime_coverage': regime_coverage,
    'shared_mechanisms': sorted(shared_mechanisms)
}

print(json.dumps(output, indent=2))
PYEOF

log "Comparing ${#INPUT_FILES[@]} apps..."

OUTPUT=$(python3 "$TEMP_SCRIPT" "${INPUT_FILES[@]}") || {
    error "Failed to compare apps"
    exit 1
}

if [ -n "$OUTPUT_FILE" ]; then
    printf '%s\n' "$OUTPUT" > "$OUTPUT_FILE"
    log "Output written to: $OUTPUT_FILE"
else
    printf '%s\n' "$OUTPUT"
fi

APP_COUNT=$(echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('apps',[])))")
TRACKER_COUNT=$(echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('shared_trackers',[])))")
log "Comparison complete. $APP_COUNT apps, $TRACKER_COUNT shared trackers."
exit 0
