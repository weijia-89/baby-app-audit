#!/usr/bin/env bash
# detect-dark-patterns.sh  -  Static dark pattern detection in APK resources
# Usage: ./detect-dark-patterns.sh <apk_path|app_name> [output.json]
# Version: 1.0

set -euo pipefail

readonly SCRIPT_VERSION="1.0"
readonly MAX_APK_SIZE=$((100 * 1024 * 1024))  # 100 MB zip bomb limit

# Source common functions
. "$(dirname "$0")/lib/common.sh"

# Handle flags before dependency checks (--check must run before check_dep)
case "${1:-}" in
    --version)
        echo "$SCRIPT_VERSION"
        exit 0
        ;;
    --check)
        echo "Checking dependencies for detect-dark-patterns.sh..."
        for dep in jq unzip python3 sed grep find; do
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

# Dependency checks (after --check so --check can report missing deps)
check_dep jq unzip python3 sed grep find || exit 1

usage() {
    cat <<EOF
Usage: $(basename "$0") <apk_path|app_name> [output.json]

Detect dark patterns in APK resources through static analysis.

Arguments:
  apk_path     Path to decompiled APK directory or APK file
  output.json  Optional output path (default: stdout)

Options:
  --version    Show version and exit
  --check      Check dependencies and exit

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

# Validate APK path: no shell metacharacters
validate_path "$APK_PATH" || exit 1

# Determine app name and package name
APP_NAME=""
PACKAGE_NAME=""

if [ -d "$APK_PATH" ]; then
    # Decompiled directory - try to get package from AndroidManifest.xml
    APP_NAME="$(basename "$APK_PATH")"
    if [ -f "$APK_PATH/AndroidManifest.xml" ]; then
        # Use sed (POSIX, macOS-compatible) instead of grep -P
        PACKAGE_NAME=$(sed -n 's/.*package="\([^"]*\)".*/\1/p' "$APK_PATH/AndroidManifest.xml" 2>/dev/null | head -1)
        if [ -z "$PACKAGE_NAME" ]; then
            PACKAGE_NAME="unknown"
        fi
    else
        PACKAGE_NAME="unknown"
    fi
elif [ -f "$APK_PATH" ]; then
    # APK file - validate size then extract to temp
    _filesize=$(stat -f%z "$APK_PATH" 2>/dev/null || stat -c%s "$APK_PATH" 2>/dev/null || echo "0")
    if [ "$_filesize" -gt "$MAX_APK_SIZE" ]; then
        error "APK file too large (${_filesize} bytes, max ${MAX_APK_SIZE})"
        exit 1
    fi
    TEMP_DIR=$(mktemp -d /tmp/apk-scan-XXXXXX)
    trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM
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

# Validate output directory
check_output_dir "$OUTPUT_FILE" || exit 1

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
            if grep -qiE '(consent|agree|privacy|terms|share.*data|opt[-_.]?in)' "$file" 2>/dev/null; then
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
            if grep -qiE '(consent|agree|privacy|terms|share.*data|opt[-_.]?in)' "$file" 2>/dev/null; then
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
    # Check all strings.xml files including localized variants (values-en, values-fr, etc.)
    local strings_files=()
    while IFS= read -r -d '' f; do
        strings_files+=("$f")
    done < <(find "$APK_PATH/res" -type f -name "strings.xml" -print0 2>/dev/null)

    if [ ${#strings_files[@]} -eq 0 ]; then
        return
    fi

    local has_accept=0 has_continue=0 has_later=0 has_decline=0
    local evidence_file=""

    for strings_file in "${strings_files[@]}"; do
        if [ "$has_accept" -eq 0 ] && grep -qiE 'name=.*accept.*all|>Accept All<' "$strings_file" 2>/dev/null; then
            has_accept=1; evidence_file="$strings_file"
        fi
        if [ "$has_continue" -eq 0 ] && grep -qiE 'name=.*continue|>Continue<' "$strings_file" 2>/dev/null; then
            has_continue=1; evidence_file="$strings_file"
        fi
        if [ "$has_later" -eq 0 ] && grep -qiE 'name=.*later|>Maybe Later<' "$strings_file" 2>/dev/null; then
            has_later=1; evidence_file="$strings_file"
        fi
        if [ "$has_decline" -eq 0 ] && grep -qiE 'name=.*decline|>Decline<' "$strings_file" 2>/dev/null; then
            has_decline=1; evidence_file="$strings_file"
        fi
    done

    if [ "$has_accept" -eq 1 ] || [ "$has_continue" -eq 1 ]; then
        if [ "$has_later" -eq 1 ] || [ "$has_decline" -eq 0 ]; then
            add_pattern "deceptive_button_order" "$evidence_file" "medium" "Found affirmative action buttons without clear decline option"
        fi
    fi
}

# Scan for obfuscated disclaimers
# Heuristic thresholds:
# - textSize <= 8sp: Below Android accessibility minimum (12sp is typical readable size)
# - textColor with RGB all > 200: Very light color on assumed white background (low contrast)
#   This catches colors like #EEEEEE, #F5F5F5, #FFFFFF
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
        # Supports 3-digit (#RGB), 6-digit (#RRGGBB), and 8-digit (#AARRGGBB) hex colors
        if grep -qE 'android:textColor="#[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?([0-9A-Fa-f]{2})?"' "$file" 2>/dev/null; then
            local color
            color=$(grep -oE 'android:textColor="#[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?([0-9A-Fa-f]{2})?"' "$file" | grep -oE '#[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?([0-9A-Fa-f]{2})?' | head -1)
            if [ -n "$color" ]; then
                # Normalize to 6-digit hex (without # prefix)
                local norm_color=""
                local len=${#color}
                if [ "$len" -eq 4 ]; then
                    norm_color="${color:1:1}${color:1:1}${color:2:1}${color:2:1}${color:3:1}${color:3:1}"
                elif [ "$len" -eq 7 ]; then
                    norm_color="${color:1:6}"
                elif [ "$len" -eq 9 ]; then
                    norm_color="${color:3:6}"
                fi
                if [ -n "$norm_color" ]; then
                    local r g b
                    r=$((16#${norm_color:0:2}))
                    g=$((16#${norm_color:2:2}))
                    b=$((16#${norm_color:4:2}))
                    if [ "$r" -gt 200 ] && [ "$g" -gt 200 ] && [ "$b" -gt 200 ] 2>/dev/null; then
                        if grep -qiE '(privacy|terms|consent|disclaimer)' "$file" 2>/dev/null; then
                            add_pattern "obfuscated_disclaimer" "$file" "medium" "Found low-contrast text color on disclaimer text"
                            break
                        fi
                    fi
                fi
            fi
        fi
    done < <(find "$res_dir" -type f -name "*.xml" -print0 2>/dev/null)
}

# Scan for pressure tactics
scan_pressure_tactics() {
    # Check all strings.xml files including localized variants
    local strings_files=()
    while IFS= read -r -d '' f; do
        strings_files+=("$f")
    done < <(find "$APK_PATH/res" -type f -name "strings.xml" -print0 2>/dev/null)

    if [ ${#strings_files[@]} -eq 0 ]; then
        return
    fi

    local pressure_patterns="limited.time|expire|urgent|act.now|don.t.miss|only.left|last.chance|countdown|timer"
    for strings_file in "${strings_files[@]}"; do
        if grep -qiE "$pressure_patterns" "$strings_file" 2>/dev/null; then
            add_pattern "pressure_tactic" "$strings_file" "low" "Found urgency or scarcity language in app strings"
            return
        fi
    done
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
