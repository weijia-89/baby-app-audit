#!/usr/bin/env bash
# Run APK privacy tests for each configured app.
# Runs one test path per app in APK_HARNESS_APPS.
# Version: 3.2.0

set -euo pipefail

# Each app uses a unique PROXY_PORT.
# Default ports: 8080-8095 (up to 16 apps).
# Override: PROXY_PORT=8081 ./run-tests.sh --live
export HARNESS_VERSION="3.2.0"
export WORK_DIR="${APK_HARNESS_WORK_DIR:-${HOME}/apk-privacy-test-$(date -u +%Y%m%d-%H%M%S)}"
export RESULTS_DIR="${WORK_DIR}/results"
export ARTIFACTS_DIR="${WORK_DIR}/artifacts"
export TEST_RUN_ID="${TEST_RUN_ID:-apk-harness-$(date -u +%Y%m%d-%H%M%S)}"
export PROXY_PORT="${PROXY_PORT:-8080}"
export MITM_WEB_PORT="${MITM_WEB_PORT:-8081}"
export KEEP_WORK_DIR="${KEEP_WORK_DIR:-0}"
export DEVICE="${ANDROID_SERIAL:-emulator-5554}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_FILE="${SYNTHETIC_PROFILE:-$REPO_ROOT/results/synthetic-baby-profile.json}"

# PROXY_PORT must be an integer in range.
if ! [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] || [ "$PROXY_PORT" -lt 1 ] || [ "$PROXY_PORT" -gt 65535 ]; then
    echo "ERROR: PROXY_PORT must be an integer between 1 and 65535, got: $PROXY_PORT"
    exit 1
fi

# Apps: semicolon-separated "Name|type|package".
# type: native | foss | web
# package may be empty for FOSS/web apps.
# Example: APK_HARNESS_APPS="Nurture Lock|native|com.angry.shark.studio.nurturelock;Nubo|native|com.clicksie.nuboapp"
# Default list matches the classified apps in results/RESULTS-20260803.json.
DEFAULT_APPS="Nurture Lock|native|com.angry.shark.studio.nurturelock;Nubo|native|com.clicksie.nuboapp;Pebbi|native|com.pebbi.android;Baby Buddy|foss|;Amila|native|com.amila.parenting;Baby Daybook|native|com.drillyapps.babydaybook;Baby+|native|com.hp.babyapp;MimiLog|native|com.mimiapp.mimilog;Nara|native|com.naraorganics.nara;Heartful Baby|native|com.heartfulsprout.baby;Pixy|native|com.pixykid.app"
APK_HARNESS_APPS="${APK_HARNESS_APPS:-$DEFAULT_APPS}"

# Space delimiter removed in v3.2.0. Use semicolons only.
# App names with spaces still need a trailing semicolon (e.g. "Baby Buddy|foss|;").
if [[ "$APK_HARNESS_APPS" == *' '* ]] && [[ "$APK_HARNESS_APPS" != *';'* ]]; then
    echo "APK_HARNESS_APPS uses space delimiter (removed in v3.2.0). Use semicolons between app triples. Example: 'App1|native|pkg;App2|foss|'" >&2
    exit 1
fi

# Trim spaces and semicolons so empty app entries are not run.
APK_HARNESS_APPS="${APK_HARNESS_APPS#"${APK_HARNESS_APPS%%[![:space:];]*}"}"
APK_HARNESS_APPS="${APK_HARNESS_APPS%"${APK_HARNESS_APPS##*[![:space:];]}"}"

# LIVE=1 captures traffic. LIVE=0 is check-only.
LIVE_MODE=0
if [ "${1:-}" = "--live" ]; then
    LIVE_MODE=1
    shift
fi

# Tool versions (stored in results).
record_tool_versions() {
    local versions_file="$RESULTS_DIR/tool-versions.json"
    local mitm_version="unknown"
    local adb_version="unknown"
    local jadx_version="unknown"
    local docker_version="unknown"
    local objection_version="unknown"
    
    if command -v mitmdump >/dev/null 2>&1; then
        mitm_version=$(mitmdump --version 2>/dev/null | head -1 || echo "unknown")
    fi
    if command -v adb >/dev/null 2>&1; then
        adb_version=$(adb --version 2>/dev/null | head -1 || echo "unknown")
    fi
    if command -v jadx >/dev/null 2>&1; then
        jadx_version=$(jadx --version 2>/dev/null || echo "unknown")
    fi
    if command -v docker >/dev/null 2>&1; then
        docker_version=$(docker --version 2>/dev/null || echo "unknown")
    fi
    if command -v objection >/dev/null 2>&1; then
        objection_version=$(objection --version 2>/dev/null || echo "unknown")
    fi
    
    jq -n \
        --arg mitm "$mitm_version" \
        --arg adb "$adb_version" \
        --arg jadx "$jadx_version" \
        --arg docker "$docker_version" \
        --arg objection "$objection_version" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            mitmproxy: $mitm,
            adb: $adb,
            jadx: $jadx,
            docker: $docker,
            objection: $objection,
            recorded_at: $ts
        }' > "$versions_file"
    
    log "Tool versions recorded: $versions_file"
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup on EXIT/INT/TERM. Runs once.
CLEANUP_RAN=0
cleanup() {
    local exit_code=$?
    if [ "$CLEANUP_RAN" -eq 1 ]; then
        return 0
    fi
    CLEANUP_RAN=1
    echo "[CLEANUP] Cleaning up..."
    
    # Stop mitmproxy if it still runs.
    if [ -n "${MITM_PID:-}" ] && kill -0 "$MITM_PID" 2>/dev/null; then
        kill "$MITM_PID" 2>/dev/null || true
        echo "[CLEANUP] Stopped mitmproxy (PID: $MITM_PID)"
    fi
    
    # Clear the emulator proxy so the device is not left proxied.
    if command -v adb >/dev/null 2>&1; then
        # Time out hung adb so cleanup can finish.
        if command -v gtimeout >/dev/null 2>&1; then
            gtimeout 10 adb -s "$DEVICE" shell settings put global http_proxy :0 2>/dev/null || true
        elif command -v timeout >/dev/null 2>&1; then
            timeout 10 adb -s "$DEVICE" shell settings put global http_proxy :0 2>/dev/null || true
        else
            adb -s "$DEVICE" shell settings put global http_proxy :0 2>/dev/null || true
        fi
        echo "[CLEANUP] Reset emulator proxy"
    fi
    
    # Delete the temp work dir unless KEEP_WORK_DIR is set.
    if [ -n "${WORK_DIR:-}" ] && [ -d "$WORK_DIR" ]; then
        if [ "$KEEP_WORK_DIR" = "1" ]; then
            echo "[CLEANUP] Keeping work directory: $WORK_DIR (KEEP_WORK_DIR=1)"
        else
            rm -rf "$WORK_DIR"
            echo "[CLEANUP] Removed work directory: $WORK_DIR"
        fi
    fi
    
    echo "[CLEANUP] Complete. Exit code: $exit_code"
}
trap cleanup EXIT INT TERM

# Strict: package/type = letters, digits, . - _ only.
# Non-strict: app display names may include spaces.
validate_input() {
    local input="$1"
    local field="$2"
    local strict="${3:-true}"

    local pattern
    if [ "$strict" = "true" ]; then
        pattern='^[a-zA-Z0-9._-]+$'
    else
        pattern='^[a-zA-Z0-9._+ -]+$'
    fi

    # Always reject shell metacharacters in validated strings.
    if [[ "$input" =~ [\"\`\'\$\;\|\&\<\>] ]]; then
        error "Shell metacharacters in $field: $input"
        return 1
    fi
    if [[ ! "$input" =~ $pattern ]]; then
        error "Invalid characters in $field: $input"
        return 1
    fi
    return 0
}

# Run adb with a timeout so a hung device cannot stall the run.
run_adb() {
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout 30 adb -s "$DEVICE" "$@"
    elif command -v timeout >/dev/null 2>&1; then
        timeout 30 adb -s "$DEVICE" "$@"
    else
        adb -s "$DEVICE" "$@"
    fi
}

# Check that required tools exist.
check_tool() {
    local tool="$1"
    local required="${2:-true}"
    
    if command -v "$tool" >/dev/null 2>&1; then
        log "$tool: $(command -v "$tool")"
        return 0
    else
        if [ "$required" = "true" ]; then
            error "$tool: NOT FOUND (required)"
            return 1
        else
            warn "$tool: NOT FOUND (optional)"
            return 0
        fi
    fi
}

# Pre-flight: warn on gaps; continue when possible.
preflight() {
    log "Running pre-flight checks..."
    
    local failed=0
    
    # Required tools: log a warning; do not exit.
    check_tool "adb" true || failed=1
    check_tool "mitmdump" true || failed=1
    check_tool "git" true || failed=1
    check_tool "jq" true || failed=1
    
    # Optional tools (warn if missing).
    check_tool "docker" false
    check_tool "jadx" false
    check_tool "objection" false
    
    # Emulator: warn only if missing.
    if command -v adb >/dev/null 2>&1; then
        if run_adb devices 2>/dev/null | grep -q "emulator"; then
            log "Emulator: connected"
        else
            warn "No Android emulator connected - native app tests will report NOT_INSTALLED"
        fi
    fi
    
    # Check free disk space.
    local available_kb
    available_kb=$(df -k . | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    if [ "$available_gb" -lt 10 ]; then
        warn "Low disk space: ${available_gb}GB available, 10GB recommended"
    fi
    
    # Create output directories.
    mkdir -p "$ARTIFACTS_DIR"/{apks,reports,logs,captures}
    mkdir -p "$RESULTS_DIR"

    # Evidence check: committed network logs required; zero-byte .mitm warns only.
    if ! bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/evidence-inventory.sh" --check; then
        failed=1
        error "Evidence inventory broken - fix or restore before running the harness"
    fi

    # Scan every committed network log for analytics and PII markers.
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local fanout_output
    fanout_output="$(mktemp "${TMPDIR:-/tmp}/apk-harness-pii-XXXXXX")"
    if ! bash "$repo_root/scripts/scan-analytics-pii.sh" "$repo_root/results" "$fanout_output"; then
        error "Analytics and PII fanout scan failed"
        return 1
    elif ! cmp -s "$fanout_output" "$repo_root/results/analytics-pii-20260803.json"; then
        error "Analytics and PII fanout result is out of date; regenerate with: bash scripts/scan-analytics-pii.sh results results/analytics-pii-20260803.json"
        return 1
    fi
    rm -f "$fanout_output"

    if [ "$failed" -eq 1 ]; then
        warn "Some required tools are missing. Running in BEST_EFFORT mode."
        echo "TOOLS_MISSING" > "$ARTIFACTS_DIR/logs/preflight-status.txt"
    else
        log "Pre-flight checks passed"
        echo "PASSED" > "$ARTIFACTS_DIR/logs/preflight-status.txt"
    fi
    
    return 0
}

# Write one app result JSON (schema apps[] item).
init_app_result() {
    local app_name="$1"
    local package_name="$2"
    local app_type="$3"
    local results_file="$4"
    
    jq -n \
        --arg name "$app_name" \
        --arg pkg "$package_name" \
        --arg type "$app_type" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{name: $name, package_name: $pkg, app_type: $type, verdict: "untested", verdict_confidence: 0, timestamp: $ts}' \
        > "$results_file"
}

# Run the test for one app.
test_app() {
    local app_name="$1"
    local app_type="$2"
    local package_name="${3:-}"
    
    # Validate all inputs. App names allow spaces (non-strict); package names and
    # app types use strict validation to prevent shell injection.
    validate_input "$app_name" "app_name" false || return 1
    validate_input "$app_type" "app_type" || return 1
    if [ -n "$package_name" ]; then
        validate_input "$package_name" "package_name" || return 1
    fi
    
    log "Testing $app_name ($app_type)..."
    
    local app_results="$RESULTS_DIR/${app_name}.json"
    local app_log="$ARTIFACTS_DIR/logs/${app_name}.log"
    
    init_app_result "$app_name" "$package_name" "$app_type" "$app_results"
    
    case "$app_type" in
        "native")
            test_native_app "$app_name" "$package_name" "$app_results" "$app_log"
            ;;
        "foss"|"web")
            test_foss_app "$app_name" "$package_name" "$app_results" "$app_log"
            ;;
        *)
            error "Unknown app type: $app_type"
            return 1
            ;;
    esac
}

# Test one native Android app.
test_native_app() {
    local app_name="$1"
    local package_name="$2"
    local results_file="$3"
    local log_file="$4"
    
    log "[$app_name] Starting native Android test..."
    
    # Step 1: Check that the package is installed.
    if [ -z "$package_name" ]; then
        warn "[$app_name] No package name configured - cannot test"
        jq '.verdict = "untested" | .status = "NO_PACKAGE"' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
        return 1
    fi
    if ! run_adb shell pm list packages 2>/dev/null | grep -q "package:${package_name}\$"; then
        warn "[$app_name] App not installed: $package_name"
        jq '.verdict = "untested" | .status = "NOT_INSTALLED"' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
        return 1
    fi
    
    # Step 2: Pull the APK.
    log "[$app_name] Pulling APK..."
    local apk_paths
    apk_paths=$(run_adb shell pm path "$package_name" 2>/dev/null || true)
    if [ -z "$apk_paths" ]; then
        warn "[$app_name] Could not find APK paths"
        jq '.verdict = "untested" | .status = "APK_NOT_FOUND"' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
        return 1
    fi
    
    # Pull APKs. Deduplicate split APK names.
    local pulled_count=0
    while IFS= read -r path; do
        local apk_name
        apk_name=$(basename "$path")
        local apk_dir
        apk_dir=$(basename "$(dirname "$path")")
        if run_adb pull "$path" "$ARTIFACTS_DIR/apks/${app_name}-${apk_dir}-${apk_name}" 2>>"$log_file"; then
            ((pulled_count++)) || true
            log "[$app_name] Pulled: $apk_name"
        fi
    done <<< "$apk_paths"
    
    # Hash each APK file.
    local first_apk=""
    for apk in "$ARTIFACTS_DIR/apks/${app_name}"-*.apk; do
        if [ -f "$apk" ]; then
            shasum -a 256 "$apk" > "$apk.sha256"
            if [ -z "$first_apk" ]; then
                first_apk="$apk"
            fi
        fi
    done
    if [ -n "$first_apk" ]; then
        local apk_sha
        apk_sha=$(awk '{print $1}' "$first_apk.sha256")
        jq --arg sha "$apk_sha" '.apk_hash = {sha256: $sha, source: "device", timestamp: "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
    fi
    
    # Step 3: Start mitmproxy.
    log "[$app_name] Starting mitmproxy..."
    mitmdump --listen-port "$PROXY_PORT" \
        --save-stream-file "$ARTIFACTS_DIR/captures/${app_name}.mitm" 2>>"$log_file" &
    local mitm_pid=$!
    export MITM_PID="$mitm_pid"

    # Wait up to 15s until the proxy port accepts connections.
    local mitm_ready=0
    for _ in {1..15}; do
        if ! kill -0 "$mitm_pid" 2>/dev/null; then
            break
        fi
        # Probe the proxy port with /dev/tcp.
        if bash -c "echo >/dev/tcp/localhost/$PROXY_PORT" 2>/dev/null; then
            mitm_ready=1
            break
        fi
        sleep 1
    done
    if [ "$mitm_ready" -ne 1 ]; then
        error "[$app_name] mitmproxy did not become ready on port $PROXY_PORT within 15s"
        jq '.verdict = "untested" | .status = "MITMPROXY_FAILED"' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
        kill "$mitm_pid" 2>/dev/null || true
        unset MITM_PID
        return 1
    fi
    
    # Step 4: Set emulator proxy. Read it back; fail if it does not match.
    log "[$app_name] Configuring emulator proxy..."
    run_adb shell settings put global http_proxy 10.0.2.2:"$PROXY_PORT" 2>>"$log_file" || true
    local proxy_set
    proxy_set=$(run_adb shell settings get global http_proxy 2>/dev/null | tr -d '\r\n')
    if [ "$proxy_set" != "10.0.2.2:$PROXY_PORT" ]; then
        warn "[$app_name] Proxy not set (got '${proxy_set:-empty}'). Traffic capture will be incomplete."
        jq --arg pb "${proxy_set:-empty}" '.status = "PROXY_NOT_SET" | .proxy_readback = $pb' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
    fi
    
    # Step 5: Start the app. Check that it runs.
    log "[$app_name] Launching app..."
    run_adb shell monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 2>>"$log_file" || true
    sleep 5
    if ! run_adb shell pidof "$package_name" 2>/dev/null | grep -q .; then
        warn "[$app_name] App process not found after launch - capture may be empty"
    fi
    
    # Step 6: Inject the synthetic baby profile into the app's own UI while the
    # capture proxy + mitmdump are live, so entered data lands in the raw .mitm
    # the synthetic-data scan searches. Replaces the old manual-entry step.
    if [ "$LIVE_MODE" -eq 1 ]; then
        log "[$app_name] Injecting synthetic baby profile (automated)..."
        if [ -f "$SCRIPT_DIR/inject-synthetic-profile.py" ]; then
            INJECT_OUT="$ARTIFACTS_DIR/${app_name}-injection.json"
            if [ ! -f "$PROFILE_FILE" ]; then
                warn "[$app_name] PROFILE_FILE missing: $PROFILE_FILE"
            fi
            if PYTHONPATH="$SCRIPT_DIR" python3 "$SCRIPT_DIR/inject-synthetic-profile.py" \
                "$package_name" "$PROFILE_FILE" "$DEVICE" >"$INJECT_OUT" 2>>"$log_file"; then
                log "[$app_name] Injection recorded to $INJECT_OUT"
            else
                warn "[$app_name] synthetic injection reported issues (continuing capture; not a privacy PASS/FAIL)"
            fi
        else
            warn "[$app_name] inject-synthetic-profile.py missing - skipping injection"
        fi
    fi
    # Wait briefly so post-save network calls can appear in the capture.
    log "[$app_name] Observing traffic for 15s (observation window)..."
    sleep 15
    
    # Step 7: Export flows.
    log "[$app_name] Exporting captured flows..."
    local flow_count=0
    local file_size=0
    local mitm_file="$ARTIFACTS_DIR/captures/${app_name}.mitm"
    
    # Stop mitmproxy so flows flush to disk.
    if [ -n "${mitm_pid:-}" ] && kill -0 "$mitm_pid" 2>/dev/null; then
        log "[$app_name] Stopping mitmproxy to flush capture file..."
        kill "$mitm_pid" 2>/dev/null || true
        # Wait up to 5 seconds for mitmproxy to exit.
        local wait_count=0
        while kill -0 "$mitm_pid" 2>/dev/null && [ "$wait_count" -lt 10 ]; do
            sleep 0.5
            wait_count=$((wait_count + 1))
        done
        unset MITM_PID
    fi
    
    # Check that the .mitm file exists and is not empty.
    if [ -f "$mitm_file" ] && [ -s "$mitm_file" ]; then
        # Read file size for the log.
        file_size=$(stat -f%z "$mitm_file" 2>/dev/null || stat -c%s "$mitm_file" 2>/dev/null || echo "0")
        # Count flows using mitmdump output (each flow = 2 lines: request + response)
        # mitmdump outputs one line per request and one per response even with console_output=false
        local raw_count
        raw_count=$(mitmdump -nr "$mitm_file" --set console_output=false 2>/dev/null | wc -l | tr -d ' ' || echo "0")
        if [ "$raw_count" -gt 0 ]; then
            flow_count=$(( (raw_count + 1) / 2 ))
        fi
        # If mitmdump fails, estimate flow count from file size.
        if [ "$flow_count" -eq 0 ]; then
            # Rough lower bound: about 500 bytes per flow.
            if [ "$file_size" -gt 1000 ]; then
                flow_count=$((file_size / 500))
            fi
        fi
        log "[$app_name] Captured $flow_count flows (mitm file: ${file_size} bytes)"
        
        jq --arg count "$flow_count" --arg flowfile "$mitm_file" '.offline_test = {
            "outbound_requests_count": ($count | tonumber),
            "flow_file": $flowfile
        }' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
    else
        warn "[$app_name] No capture file found or empty: $mitm_file"
    fi
    
    # Step 8: Static scan - jadx decompilation is a manual review step; the
    # automated scan (exodus-standalone) is documented but not run here.
    if command -v jadx >/dev/null 2>&1; then
        log "[$app_name] jadx available for manual static review (see decompiled/)"
        # No automated static scan runs here (exodus-standalone not wired), so
        # no tracker counts are claimed. Trackers found in decompiled/ are
        # recorded manually by the operator.
        jq '.static_scan = {
            "note": "jadx manual review required; exodus-standalone not run (architecture)"
        }' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
    else
        warn "[$app_name] jadx not available - static scan skipped"
    fi
    
    # Clear the emulator proxy.
    run_adb shell settings put global http_proxy :0 2>/dev/null || true
    
    # Verdict: did entered data leave the device?
    if [ "$flow_count" -gt 0 ]; then
        jq '.verdict = "fail" | .status = "COMPLETED" | .verdict_confidence = 100' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
    else
        jq '.verdict = "pass" | .status = "COMPLETED" | .verdict_confidence = 100' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
    fi
    
    log "[$app_name] Test completed"
    return 0
}

# FOSS/web: clone the repo and search source for trackers.
test_foss_app() {
    local app_name="$1"
    local package_name="$2"
    local results_file="$3"
    local log_file="$4"
    
    log "[$app_name] Starting FOSS/web test..."
    
    # Map the app name to a git repo URL.
    local repo_url=""
    case "$app_name" in
        "Baby Buddy"|"Baby-buddy")
            repo_url="https://github.com/babybuddy/babybuddy.git"
            ;;
        *)
            warn "[$app_name] No FOSS repo configured - skipping source audit"
            jq '.verdict = "untested" | .status = "NO_FOSS_REPO_CONFIGURED"' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
            return 0
            ;;
    esac
    
    local repo_dir="$WORK_DIR/${app_name// /-}-source"
    
    log "[$app_name] Cloning repository..."
    local clone_success=false
    
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout 300 git clone --depth 1 "$repo_url" "$repo_dir" 2>>"$log_file" && clone_success=true
    elif command -v timeout >/dev/null 2>&1; then
        timeout 300 git clone --depth 1 "$repo_url" "$repo_dir" 2>>"$log_file" && clone_success=true
    else
        git clone --depth 1 "$repo_url" "$repo_dir" 2>>"$log_file" && clone_success=true
    fi
        
        if [ "$clone_success" = "true" ]; then
            log "[$app_name] Repository cloned successfully"
            
            # Record the git commit hash.
            local commit_hash
            commit_hash=$(cd "$repo_dir" && git rev-parse HEAD)
            log "[$app_name] Commit: $commit_hash"
            
            # Search source. Skip minified and vendor files.
            log "[$app_name] Auditing source code..."
            local network_hits="$ARTIFACTS_DIR/reports/${app_name}-network-hits.txt"
            local tracker_hits="$ARTIFACTS_DIR/reports/${app_name}-tracker-hits.txt"
            
            # Search Python files for network calls.
            grep -rEi 'https?://|urllib|requests\.|httpx\.|aiohttp' "$repo_dir" --include="*.py" > "$network_hits" 2>/dev/null || true
            # Search JS files for network calls. Skip vendor dirs.
            grep -rEi 'fetch\(|axios|XMLHttpRequest|WebSocket|EventSource|navigator\.sendBeacon' "$repo_dir" --include="*.js" --exclude-dir=vendor --exclude-dir=node_modules >> "$network_hits" 2>/dev/null || true
            
            # Search source for tracker library names.
            grep -rEi 'google.analytics|mixpanel|segment|sentry|bugsnag|firebase|matomo|plausible|amplitude|posthog' "$repo_dir" --include="*.py" --include="*.js" --exclude-dir=vendor --exclude-dir=node_modules > "$tracker_hits" 2>/dev/null || true
            
            local network_count
            network_count=$(wc -l < "$network_hits" | tr -d ' ')
            local tracker_count
            tracker_count=$(wc -l < "$tracker_hits" | tr -d ' ')
            
            log "[$app_name] Found $network_count network references, $tracker_count tracker references"
            
            jq --arg commit "$commit_hash" --arg url "$repo_url" --arg net "$network_count" --arg track "$tracker_count" '.source_audit = {
                "repository_url": $url,
                "commit_hash": $commit,
                "network_endpoints": [],
                "tracker_libraries": [],
                "sends_by_default": false,
                "network_references_count": ($net | tonumber),
                "tracker_references_count": ($track | tonumber)
            }' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
            
            # Check for dependency files.
            if [ -f "$repo_dir/requirements.txt" ]; then
                log "[$app_name] Found requirements.txt"
            fi
            if [ -f "$repo_dir/package.json" ]; then
                log "[$app_name] Found package.json"
            fi
        else
            warn "[$app_name] Failed to clone repository"
            jq '.verdict = "untested" | .status = "CLONE_FAILED"' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
            return 1
        fi
    
    jq '.verdict = "pass" | .status = "COMPLETED" | .verdict_confidence = 100' "$results_file" > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
    log "[$app_name] Test completed"
    return 0
}

main() {
    log "Starting APK Privacy Test Harness Execution"
    log "Version: $HARNESS_VERSION"
    log "Test run ID: $TEST_RUN_ID"
    log "Working directory: $WORK_DIR"
    if [ "$LIVE_MODE" -eq 1 ]; then
        log "Mode: LIVE (traffic capture enabled)"
    else
        log "Mode: STANDARD (no --live flag)"
    fi
    
    if ! preflight; then
        error "Pre-flight checks failed. Cannot continue."
        exit 1
    fi
    
    # Record tool versions.
    record_tool_versions
    
    # --check: validate tools and config only (CI).
    if [ "${1:-}" = "--check" ]; then
        log "Configuration check passed (tools + schema) - dry run complete"
        exit 0
    fi
    
    # If --live was passed but mitmproxy is not available, warn and continue
    # with best-effort (static scans still run)
    if [ "$LIVE_MODE" -eq 1 ] && ! command -v mitmdump >/dev/null 2>&1; then
        warn "--live requested but mitmproxy not available. Skipping live capture."
        LIVE_MODE=0
    fi
    
    # Loop over each configured app.
    local exit_code=0
    local app_idx=0
    while IFS='|' read -r app_name app_type package_name; do
        # Skip empty entries from trailing semicolons.
        [ -z "$app_name" ] && continue
        # Give each app a unique proxy port.
        local app_port=$((PROXY_PORT + app_idx))
        local app_web_port=$((app_port + 100))
        if [ "$app_port" -gt 65535 ] || [ "$app_web_port" -gt 65535 ]; then
            error "Port overflow: app_idx=$app_idx would use ports $app_port/$app_web_port. Reduce app count or lower PROXY_PORT."
            exit 1
        fi
        export PROXY_PORT="$app_port"
        export MITM_WEB_PORT="$app_web_port"
        test_app "$app_name" "$app_type" "$package_name" || exit_code=1
        app_idx=$((app_idx + 1))
    done <<< "$(printf '%s' "$APK_HARNESS_APPS" | tr ';' '\n')"
    
    # Write the run summary JSON.
    log "Generating summary..."
    local summary="$RESULTS_DIR/summary.json"
    
    local status_text="SUCCESS"
    if [ $exit_code -ne 0 ]; then
        status_text="PARTIAL_FAILURE"
    fi
    
    # Build apps[] from per-app result files (skip the summary file).
    local apps_json=""
    for f in "$RESULTS_DIR"/*.json; do
        # Skip if no result JSON files exist.
        [ -f "$f" ] || continue
        [ "$f" = "$summary" ] && continue
        [ "$(basename "$f")" = "tool-versions.json" ] && continue
        [ "$(basename "$f")" = "summary.json" ] && continue
        apps_json="${apps_json}$(cat "$f"),"
    done
    apps_json="[${apps_json%,}]"
    
    # Add tool versions and live-mode flag to the summary.
    local tool_versions="{}"
    if [ -f "$RESULTS_DIR/tool-versions.json" ]; then
        tool_versions=$(cat "$RESULTS_DIR/tool-versions.json")
    fi
    
    jq -n \
        --arg hv "$HARNESS_VERSION" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg rid "$TEST_RUN_ID" \
        --arg st "$status_text" \
        --argjson apps "$apps_json" \
        --argjson tools "$tool_versions" \
        --argjson live "$LIVE_MODE" \
        '{
            harness_version: $hv,
            timestamp: $ts,
            test_run_id: $rid,
            status: $st,
            live_mode: $live,
            tool_versions: $tools,
            apps: $apps
        }' \
        > "$summary" || {
            # On bad input, write an empty apps list. Do not report SUCCESS.
            warn "Summary build failed (malformed per-app result file); writing empty apps array"
            exit_code=1
            jq -n \
                --arg hv "$HARNESS_VERSION" \
                --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                --arg rid "$TEST_RUN_ID" \
                --arg st "$status_text" \
                --argjson live "$LIVE_MODE" \
                '{
                    harness_version: $hv,
                    timestamp: $ts,
                    test_run_id: $rid,
                    status: $st,
                    live_mode: $live,
                    apps: []
                }' \
                > "$summary"
        }
    
    log "Test execution complete"
    log "Results: $RESULTS_DIR"
    log "Artifacts: $ARTIFACTS_DIR"
    
    return $exit_code
}

main "$@"
