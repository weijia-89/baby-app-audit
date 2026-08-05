#!/usr/bin/env bash
# detect-dark-patterns.sh  -  Static dark pattern detection in APK resources
# Usage: ./detect-dark-patterns.sh <apk_path|app_name> [output.json]
# Version: 1.0

set -euo pipefail

readonly SCRIPT_VERSION="1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[DARK-PATTERNS v${SCRIPT_VERSION}]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <apk_path|app_name> [output.json]

Detect dark patterns in APK resources through static analysis.

Arguments:
  apk_path     Path to decompiled APK directory or APK file
  output.json  Optional output path (default: stdout)

Returns:
  0 on success, 1 on error
EOF
}

# Validate inputs
if [ $# -lt 1 ]; then
    usage
    exit 1
fi

APK_PATH="$1"
OUTPUT_FILE="${2:-}"

# Determine app name and package name
APP_NAME=""
PACKAGE_NAME=""

if [ -d "$APK_PATH" ]; then
    # Decompiled directory - try to get package from AndroidManifest.xml
    APP_NAME="$(basename "$APK_PATH")"
    if [ -f "$APK_PATH/AndroidManifest.xml" ]; then
        PACKAGE_NAME=$(grep -oP 'package="\K[^"]+' "$APK_PATH/AndroidManifest.xml" 2>/dev/null || echo "unknown")
    else
        PACKAGE_NAME="unknown"
    fi
elif [ -f "$APK_PATH" ]; then
    # APK file - extract to temp
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    if command -v unzip >/dev/null 2>&1; then
        unzip -q "$APK_PATH" -d "$TEMP_DIR" 2>/dev/null || {
            error "Failed to extract APK: $APK_PATH"
            exit 1
        }
        APK_PATH="$TEMP_DIR"
        APP_NAME="$(basename "$1" .apk)"
        PACKAGE_NAME="unknown"
    else
        error "unzip required for APK file extraction"
        exit 1
    fi
else
    error "Path not found: $APK_PATH"
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

SCAN_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PATTERNS="[]"

# Helper to add a pattern
add_pattern() {
    local pattern_type="$1"
    local evidence_file="$2"
    local confidence="$3"
    local description="$4"
    PATTERNS=$(echo "$PATTERNS" | jq --arg type "$pattern_type" \
        --arg file "$evidence_file" \
        --arg confidence "$confidence" \
        --arg desc "$description" \
        '. + [{"pattern_type": $type, "evidence_file": $file, "confidence": $confidence, "description": $desc}]')
}

# Scan for pre-checked consent checkboxes
scan_pre_checked_consent() {
    local layout_dir="$APK_PATH/res/layout"
    if [ ! -d "$layout_dir" ]; then
        layout_dir="$APK_PATH/res/xml"
    fi
    if [ ! -d "$layout_dir" ]; then
        return
    fi

    local found=0
    while IFS= read -r -d '' file; do
        if grep -q 'android:checked="true"' "$file" 2>/dev/null; then
            # Check if it looks like a consent-related widget
            if grep -qiE '(consent|agree|privacy|terms|share.*data|opt.in)' "$file" 2>/dev/null; then
                add_pattern "pre_checked_consent" "$file" "high" "Found pre-checked checkbox with consent-related text"
                found=1
                break
            fi
        fi
    done < <(find "$layout_dir" -type f -name "*.xml" -print0 2>/dev/null)

    # Also check for Switch or ToggleButton with checked=true and consent text
    if [ "$found" -eq 0 ]; then
        while IFS= read -r -d '' file; do
            if grep -q 'android:checked="true"' "$file" 2>/dev/null; then
                if grep -qiE '(consent|agree|privacy|terms|share.*data)' "$file" 2>/dev/null; then
                    add_pattern "pre_checked_consent" "$file" "medium" "Found pre-checked toggle with consent-related text"
                    break
                fi
            fi
        done < <(find "$APK_PATH/res" -type f -name "*.xml" -print0 2>/dev/null)
    fi
}

# Scan for hidden consent flows
scan_hidden_consent_flow() {
    local res_dir="$APK_PATH/res"
    if [ ! -d "$res_dir" ]; then
        return
    fi

    while IFS= read -r -d '' file; do
        if grep -q 'android:visibility="gone"' "$file" 2>/dev/null || \
           grep -q 'android:visibility="invisible"' "$file" 2>/dev/null; then
            if grep -qiE '(webview|web_view|browser)' "$file" 2>/dev/null; then
                if grep -qiE '(privacy|consent|terms|policy)' "$file" 2>/dev/null; then
                    add_pattern "hidden_consent_flow" "$file" "high" "Found hidden WebView with consent-related content"
                    break
                fi
            fi
        fi
        # Check for very small dimensions
        if grep -qE 'android:layout_width="[0-9]+dp"' "$file" 2>/dev/null; then
            local width
            width=$(grep -oE 'android:layout_width="[0-9]+dp"' "$file" | grep -oE '[0-9]+' | head -1)
            if [ -n "$width" ] && [ "$width" -le 5 ] 2>/dev/null; then
                if grep -qiE '(webview|web_view|browser|privacy|consent)' "$file" 2>/dev/null; then
                    add_pattern "hidden_consent_flow" "$file" "medium" "Found very small WebView that may hide consent content"
                    break
                fi
            fi
        fi
    done < <(find "$res_dir" -type f -name "*.xml" -print0 2>/dev/null)
}

# Scan for deceptive button ordering
scan_deceptive_button_order() {
    local strings_file="$APK_PATH/res/values/strings.xml"
    if [ ! -f "$strings_file" ]; then
        return
    fi

    local has_accept=0
    local has_continue=0
    local has_later=0
    local has_decline=0

    if grep -qiE 'name=.*accept.*all|>Accept All<' "$strings_file" 2>/dev/null; then
        has_accept=1
    fi
    if grep -qiE 'name=.*continue|>Continue<' "$strings_file" 2>/dev/null; then
        has_continue=1
    fi
    if grep -qiE 'name=.*later|>Maybe Later<' "$strings_file" 2>/dev/null; then
        has_later=1
    fi
    if grep -qiE 'name=.*decline|>Decline<' "$strings_file" 2>/dev/null; then
        has_decline=1
    fi

    if [ "$has_accept" -eq 1 ] || [ "$has_continue" -eq 1 ]; then
        if [ "$has_later" -eq 1 ] || [ "$has_decline" -eq 0 ]; then
            add_pattern "deceptive_button_order" "$strings_file" "medium" "Found affirmative action buttons without clear decline option"
        fi
    fi
}

# Scan for obfuscated disclaimers
scan_obfuscated_disclaimer() {
    local res_dir="$APK_PATH/res"
    if [ ! -d "$res_dir" ]; then
        return
    fi

    while IFS= read -r -d '' file; do
        # Check for very small text sizes
        if grep -qE 'android:textSize="[0-9]+sp"' "$file" 2>/dev/null; then
            local size
            size=$(grep -oE 'android:textSize="[0-9]+sp"' "$file" | grep -oE '[0-9]+' | head -1)
            if [ -n "$size" ] && [ "$size" -le 8 ] 2>/dev/null; then
                if grep -qiE '(privacy|terms|consent|disclaimer|policy)' "$file" 2>/dev/null; then
                    add_pattern "obfuscated_disclaimer" "$file" "high" "Found very small text size on disclaimer or policy text"
                    break
                fi
            fi
        fi
        # Check for low-contrast or hidden text hints
        if grep -qE 'android:textColor="#[0-9A-Fa-f]{6}"' "$file" 2>/dev/null; then
            local color
            color=$(grep -oE 'android:textColor="#[0-9A-Fa-f]{6}"' "$file" | grep -oE '[0-9A-Fa-f]{6}' | head -1)
            if [ -n "$color" ]; then
                # Check if color is very light (likely low contrast on white background)
                local r g b
                r=$((16#${color:0:2}))
                g=$((16#${color:2:2}))
                b=$((16#${color:4:2}))
                if [ "$r" -gt 200 ] && [ "$g" -gt 200 ] && [ "$b" -gt 200 ] 2>/dev/null; then
                    if grep -qiE '(privacy|terms|consent|disclaimer)' "$file" 2>/dev/null; then
                        add_pattern "obfuscated_disclaimer" "$file" "medium" "Found low-contrast text color on disclaimer text"
                        break
                    fi
                fi
            fi
        fi
    done < <(find "$res_dir" -type f -name "*.xml" -print0 2>/dev/null)
}

# Scan for pressure tactics
scan_pressure_tactics() {
    local strings_file="$APK_PATH/res/values/strings.xml"
    if [ ! -f "$strings_file" ]; then
        return
    fi

    local pressure_patterns="limited.time|expire|urgent|act.now|don.t.miss|only.left|last.chance|countdown|timer"
    if grep -qiE "$pressure_patterns" "$strings_file" 2>/dev/null; then
        add_pattern "pressure_tactic" "$strings_file" "low" "Found urgency or scarcity language in app strings"
    fi
}

# Run all scans
log "Scanning $APP_NAME for dark patterns..."

scan_pre_checked_consent
scan_hidden_consent_flow
scan_deceptive_button_order
scan_obfuscated_disclaimer
scan_pressure_tactics

# Build output
PATTERN_COUNT=$(echo "$PATTERNS" | jq 'length')
PATTERN_TYPES=$(echo "$PATTERNS" | jq '[.[].pattern_type] | unique')

OUTPUT=$(jq -n \
    --arg app_name "$APP_NAME" \
    --arg package_name "$PACKAGE_NAME" \
    --arg scan_timestamp "$SCAN_TIMESTAMP" \
    --argjson patterns "$PATTERNS" \
    --argjson pattern_types "$PATTERN_TYPES" \
    --argjson count "$PATTERN_COUNT" \
    '{
        app_name: $app_name,
        package_name: $package_name,
        scan_timestamp: $scan_timestamp,
        patterns: $patterns,
        summary: {
            total_patterns: $count,
            pattern_types_found: $pattern_types
        }
    }')

# Output
if [ -n "$OUTPUT_FILE" ]; then
    printf '%s\n' "$OUTPUT" > "$OUTPUT_FILE"
    log "Output written to: $OUTPUT_FILE"
else
    printf '%s\n' "$OUTPUT"
fi

log "Scan complete. Found $PATTERN_COUNT patterns."
exit 0
