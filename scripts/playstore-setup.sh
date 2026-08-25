#!/usr/bin/env bash
# Play-store unlock slice: put a real Google Play store on the test emulator
# so Pairip-licensed apps can pass their license check, while keeping root
# so traffic capture still works.
#
# Subcommands:
#   check                     Print current state; mutate nothing; exit 1 when prerequisites are missing.
#   backup NAME               Save a quickboot snapshot NAME on the running emulator (refuses overwrite without --force).
#   install-zip ZIP SUMS      Verify ZIP against SHA256SUMS file, then push core GApps packages into /system and reboot.
#   verify                    Post-boot assertions: boot complete, real store, GMS present, mitm CA intact.
#   pairip-probe PACKAGE      Launch PACKAGE up to 3 times and classify what happens (license dialog vs running app).
#
# Safety rules baked in:
# - install-zip refuses to run unless snapshot "pre-gapps" exists (see backup).
# - install-zip refuses to run unless the zip checksum matches SUMS exactly.
# - Every destructive step is one explicit subcommand; nothing runs implicitly.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERIAL="${ANDROID_SERIAL:-emulator-5554}"
AVD_DIR="${HOME}/.android/avd/apk-test-api29.avd"
REQUIRED_SNAPSHOT="pre-gapps"
MITM_CA_HASH="c8750f0d"
PROBE_TRIES=3

log() { printf '[playstore] %s\n' "$*"; }
die() { printf '[playstore] ERROR: %s\n' "$*" >&2; exit 1; }

adb_sel() { adb -s "$SERIAL" "$@"; }

require_device() {
    adb_sel get-state 2>/dev/null | grep -q device || die "emulator $SERIAL not connected"
}

cmd() { python3 -c "import sys; sys.path.insert(0,'$repo_root/scripts'); import gapps_state" || die "scripts/gapps_state.py import failed"; }

vending_dump() { adb_sel shell dumpsys package com.android.vending 2>/dev/null || true; }

state_line() {
    local ver cls
    ver=$(vending_dump | python3 -c "import sys;sys.path.insert(0,'$repo_root/scripts');import gapps_state as g;print(g.parse_vending_version(sys.stdin.read()) or '')")
    if [ -z "$ver" ]; then
        echo "store: absent"
        return
    fi
    cls=$(VVER="$ver" python3 -c "
import os, sys
sys.path.insert(0, '$repo_root/scripts')
import gapps_state as g
v = os.environ['VVER']
print(('STUB ' + v) if g.is_stub_vending(v) else ('REAL ' + v))")
    echo "store: $cls"
}

cmd_check() {
    cmd
    log "device: $(adb devices | grep -w "$SERIAL" >/dev/null 2>&1 && echo connected || echo absent)"
    if adb devices | grep -qw "$SERIAL"; then log "$(state_line)"; fi
    if [ -d "$AVD_DIR/snapshots/$REQUIRED_SNAPSHOT" ]; then
        log "snapshot $REQUIRED_SNAPSHOT: present"
    else
        log "snapshot $REQUIRED_SNAPSHOT: MISSING (run: $0 backup $REQUIRED_SNAPSHOT)"
    fi
    local ca
    ca=$(adb devices | grep -qw "$SERIAL" && adb_sel shell "ls /system/etc/security/cacerts/${MITM_CA_HASH}.0 2>/dev/null" || true)
    [ -n "$ca" ] && log "mitm CA ${MITM_CA_HASH}: present" || log "mitm CA ${MITM_CA_HASH}: absent (captures will be empty)"
    [ -d "$AVD_DIR/snapshots/$REQUIRED_SNAPSHOT" ] || exit 1
}

cmd_backup() {
    local name="" force=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --force) force=1 ;;
            *) name="$1" ;;
        esac
        shift
    done
    [ -n "$name" ] || die "usage: $0 backup NAME [--force]"
    require_device
    if [ -e "$AVD_DIR/snapshots/$name" ] && [ -z "$force" ]; then
        die "snapshot '$name' already exists; pass --force to overwrite"
    fi
    log "saving snapshot '$name' (takes up to ~60s)"
    adb_sel emu avd snapshot save "$name"
    sleep 5
    [ -e "$AVD_DIR/snapshots/$name" ] || die "snapshot save reported ok but no files appeared under $AVD_DIR/snapshots/"
    log "snapshot saved: $name"
}

cmd_install_zip() {
    local zip_path="${1:?usage: $0 install-zip CORE_ZIP SHA256SUMS}"
    local sums="${2:?usage: $0 install-zip CORE_ZIP SHA256SUMS}"
    [ -f "$zip_path" ] || die "zip not found: $zip_path"
    [ -f "$sums" ] || die "checksums file not found: $sums"
    [ -e "$AVD_DIR/snapshots/$REQUIRED_SNAPSHOT" ] \
        || die "refusing to modify the system image without a '$REQUIRED_SNAPSHOT' snapshot (run: $0 backup $REQUIRED_SNAPSHOT)"
    local zip_abs sums_abs
    zip_abs=$(abs_path "$zip_path")
    sums_abs=$(abs_path "$sums")
    log "checking archive for escape paths"
    if zip_listing_has_escape "$(unzip -l "$zip_abs")"; then
        die "archive listing contains absolute or parent-escape paths; refusing"
    fi
    log "verifying checksum"
    local report target
    target=$(basename "$zip_abs")
    report=$(cd "$(dirname "$zip_abs")" && shasum -a 256 -c "$sums_abs" 2>&1 || true)
    checksum_report_ok "$report" "$target" \
        || die "checksum verification did not pass for $target; refusing to install. Report was:
$report"

    local work
    work=$(mktemp -d "${TMPDIR:-/tmp}/gapps.XXXXXX")
    unzip -q "$zip_path" -d "$work"
    local pushed=0 pkg base
    for pkg in Phonesky GoogleServicesFramework PrebuiltGmsCore; do
        case "$pkg" in
            Phonesky)                base=$(find "$work" \( -iname 'Phonesky.apk' -o -iname 'Vending.apk' \) | head -1) ;;
            PrebuiltGmsCore)         base=$(find "$work" -iname '*GmsCore*.apk' | head -1) ;;
            *)                       base=$(find "$work" -iname "${pkg}.apk" | head -1) ;;
        esac
        [ -n "$base" ] || { log "WARN: ${pkg}.apk not in zip (skipped)"; continue; }
        adb_sel root >/dev/null 2>&1 || true; sleep 2
        adb_sel remount >/dev/null || die "adb remount failed; system image is not writable"
        adb_sel shell "mkdir -p /system/priv-app/${pkg}"
        adb_sel push "$base" "/system/priv-app/${pkg}/${pkg}.apk" >/dev/null
        adb_sel shell "chmod 644 /system/priv-app/${pkg}/${pkg}.apk"
        log "installed ${pkg}.apk into /system/priv-app/${pkg}/"
        pushed=$((pushed+1))
    done
    rm -rf "$work"
    [ "$pushed" -ge 1 ] || die "nothing was installed; check the zip layout"
    log "rebooting (wait for boot before verify)"
    adb_sel reboot
}

cmd_verify() {
    require_device
    local i b
    for i in $(seq 1 40); do
        b=$(adb_sel shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
        [ "$b" = "1" ] && break
        sleep 10
    done
    [ "$b" = "1" ] || die "device did not finish booting"
    log "$(state_line)"
    state_line | grep -q REAL || die "store is still stub or absent after install"
    for pkg in com.google.android.gsf com.google.android.gms; do
        adb_sel shell pm path "$pkg" >/dev/null 2>&1 || die "$pkg missing after install"
    done
    log "GMS core + services present"
    if adb_sel shell "ls /system/etc/security/cacerts/${MITM_CA_HASH}.0" >/dev/null 2>&1; then
        log "mitm CA ${MITM_CA_HASH}: intact"
    else
        local HASH="$MITM_CA_HASH"
        log "WARN: mitm CA lost during install; re-push it before any capture:"
        log "  cp ~/.mitmproxy/mitmproxy-ca-cert.pem /tmp/${HASH}.0 && \\"
        log "  adb -s ${SERIAL} push /tmp/${HASH}.0 /system/etc/security/cacerts/${HASH}.0 && \\"
        log "  adb -s ${SERIAL} shell chmod 644 /system/etc/security/cacerts/${HASH}.0"
        exit 1
    fi
    log "verify OK"
}

cmd_pairip_probe() {
    local package="${1:?usage: $0 pairip-probe PACKAGE}"
    require_device
    local try resumed xml verdict out_dir probe_date
    probe_date=$(date +%Y%m%d)
    out_dir="$repo_root/results/${package}-test-${probe_date}/artifacts/uiux"
    mkdir -p "$out_dir" "$repo_root/results/${package}-test-${probe_date}/artifacts/logs"
    for try in $(seq 1 "$PROBE_TRIES"); do
        adb_sel shell am force-stop "$package" 2>/dev/null || true
        adb_sel shell am start -n "$(adb_sel shell cmd package resolve-activity --brief "$package" | tail -1 | tr -d '\r')" >/dev/null
        sleep 8
        resumed=$(adb_sel shell "dumpsys activity activities | grep mResumedActivity | head -1")
        adb_sel shell rm -f /sdcard/ui.xml 2>/dev/null || true
        rm -f /tmp/probe-ui.xml
        adb_sel shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true
        adb_sel pull /sdcard/ui.xml /tmp/probe-ui.xml >/dev/null 2>&1 || : > /tmp/probe-ui.xml
        xml=$(cat /tmp/probe-ui.xml 2>/dev/null || true)
        adb_sel exec-out screencap -p > "$out_dir/${package}-try${try}.png"
        verdict=$(RESUMED="$resumed" XML="$xml" python3 -c "
import os, sys
sys.path.insert(0, '$repo_root/scripts')
import gapps_state as g
print(g.classify_pairip(os.environ['RESUMED'], os.environ['XML']))")
        log "probe try ${try}: $verdict"
        [ "$verdict" = "ok" ] && break
        sleep 4
    done
    echo "$verdict" > "$repo_root/results/${package}-test-${probe_date}/artifacts/logs/${package}.verdict"
    [ "$verdict" = "ok" ] && log "PASS: app is running past licensing" || die "app never got past licensing (see $out_dir)"
}

abs_path() { python3 -c "import os,sys;print(os.path.abspath(sys.argv[1]))" "$1"; }

case "${1:-}" in
    check) shift; cmd_check "$@" ;;
    backup) shift; cmd_backup "$@" ;;
    install-zip) shift; cmd_install_zip "$@" ;;
    verify) shift; cmd_verify ;;
    pairip-probe) shift; cmd_pairip_probe "$@" ;;
    *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
