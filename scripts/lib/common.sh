#!/usr/bin/env bash
# Shared helpers for harness scripts.
# Source: . "$(dirname "$0")/lib/common.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Log to stderr so stdout stays machine-readable.
log() { echo -e "${GREEN}[$(basename "$0")]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Fail if a required command is missing.
# Usage: check_dep <command> [command...]
check_dep() {
    local missing=0
    for dep in "$@"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            error "$dep is required but not installed"
            missing=1
        fi
    done
    return "$missing"
}

# Handle --version and --check before positional args.
# Usage: handle_flags "$1"
# Returns 0 if a flag was handled (caller should exit), 1 otherwise
handle_flags() {
    case "$1" in
        --version)
            echo "${SCRIPT_VERSION:-unknown}"
            return 0
            ;;
        --check)
            echo "Checking dependencies for $(basename "$0")..."
            return 0
            ;;
    esac
    return 1
}

# Fail if the output directory is missing or not writable.
# Usage: check_output_dir <path>
check_output_dir() {
    local output_file="$1"
    if [ -n "$output_file" ]; then
        local output_dir
        output_dir="$(dirname "$output_file")"
        if [ ! -d "$output_dir" ]; then
            error "Output directory does not exist: $output_dir"
            return 1
        fi
        if [ ! -w "$output_dir" ]; then
            error "Output directory is not writable: $output_dir"
            return 1
        fi
    fi
    return 0
}

# Fail if the path has shell metacharacters.
# Usage: validate_path <path>
validate_path() {
    if [[ "$1" =~ [\"\`\'\$\;\|\&\<\>] ]]; then
        error "Invalid characters in path: $1"
        return 1
    fi
    return 0
}
