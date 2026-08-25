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
AVD_DIR="${PLAYSTORE_AVD_DIR:-${HOME}/.android/avd/apk-test-api29.avd}"
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
    local device_ok=0 snap_ok=0 ca_ok=0
    log "device: $(adb devices | grep -w "$SERIAL" >/dev/null 2>&1 && echo connected || echo absent)"
    if adb devices | grep -qw "$SERIAL"; then
        device_ok=1
        log "$(state_line)"
    fi
    if [ -d "$AVD_DIR/snapshots/$REQUIRED_SNAPSHOT" ]; then
        snap_ok=1
        log "snapshot $REQUIRED_SNAPSHOT: present"
    else
        log "snapshot $REQUIRED_SNAPSHOT: MISSING (run: $0 backup $REQUIRED_SNAPSHOT)"
    fi
    local ca=""
    if [ "$device_ok" = "1" ]; then
        ca=$(adb_sel shell "ls /system/etc/security/cacerts/${MITM_CA_HASH}.0 2>/dev/null")
    fi
    if [ -n "$ca" ]; then
        ca_ok=1
        log "mitm CA ${MITM_CA_HASH}: present"
    else
        log "mitm CA ${MITM_CA_HASH}: absent (captures will be empty)"
    fi
    local ok
    ok=$(PREREQ_DEVICE="$device_ok" PREREQ_SNAP="$snap_ok" PREREQ_CA="$ca_ok" python3 -c "
import os, sys
sys.path.insert(0, '$repo_root/scripts')
import gapps_state as g
good, _ = g.evaluate_prerequisites(
    device=os.environ['PREREQ_DEVICE'] == '1',
    snapshot=os.environ['PREREQ_SNAP'] == '1',
    ca=os.environ['PREREQ_CA'] == '1',
)
print(1 if good else 0)")
    if [ "$ok" != "1" ]; then
        printf '[playstore] unmet prerequisites:\n%s\n' "$(
            PREREQ_DEVICE="$device_ok" PREREQ_SNAP="$snap_ok" PREREQ_CA="$ca_ok" python3 -c "
import os, sys
sys.path.insert(0, '$repo_root/scripts')
import gapps_state as g
_, failures = g.evaluate_prerequisites(
    device=os.environ['PREREQ_DEVICE'] == '1',
    snapshot=os.environ['PREREQ_SNAP'] == '1',
    ca=os.environ['PREREQ_CA'] == '1',
)
print('\n'.join('  - ' + f for f in failures))" )" >&2
        exit 1
    fi
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
    local waited=0
    until [ -e "$AVD_DIR/snapshots/$name" ]; do
        waited=$((waited + 5))
        [ "$waited" -ge 60 ] && die "snapshot '$name' never appeared under $AVD_DIR/snapshots/"
        sleep 5
    done
    log "snapshot saved: $name (waited ${waited}s)"
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
    local escape
    escape=$(LISTING="$(unzip -l "$zip_abs")" python3 -c "
import os, sys
sys.path.insert(0, '$repo_root/scripts')
import gapps_state as g
print(g.zip_listing_has_escape(os.environ['LISTING']))")
    [ "$escape" = "True" ] \
        && die "archive listing contains absolute or parent-escape paths; refusing"
    log "verifying checksum"
    local report target verdict
    target=$(basename "$zip_abs")
    report=$(cd "$(dirname "$zip_abs")" && shasum -a 256 -c "$sums_abs" 2>&1 || true)
    verdict=$(REPORT="$report" TARGET="$target" python3 -c "
import os, sys
sys.path.insert(0, '$repo_root/scripts')
import gapps_state as g
print(g.checksum_report_ok(os.environ['REPORT'], os.environ['TARGET']))")
    [ "$verdict" = "True" ] \
        || die "checksum verification did not pass for $target; refusing to install. Report was:
$report"
    log "checksum OK"

    local work abi
    work=$(mktemp -d "${TMPDIR:-/tmp}/gapps.XXXXXX")
    unzip -q "$zip_path" -d "$work"
    abi=$(adb_sel shell getprop ro.product.cpu.abi | tr -d '\r')
    log "device ABI: ${abi:-unknown}"

    # Phase 1: locate every core package (ABI-aware) before touching the device.
    local found="" missing="" pkg cands base
    for pkg in Phonesky GoogleServicesFramework PrebuiltGmsCore; do
        case "$pkg" in
            Phonesky)        cands=$(find "$work" \( -iname 'Phonesky.apk' -o -iname 'Vending.apk' \)) ;;
            PrebuiltGmsCore) cands=$(find "$work" -iname '*GmsCore*.apk') ;;
            *)               cands=$(find "$work" -iname "${pkg}.apk") ;;
        esac
        base=$(CANDS="$cands" ABI="$abi" python3 -c "
import os, sys
sys.path.insert(0, '$repo_root/scripts')
import gapps_state as g
cands = [line for line in os.environ['CANDS'].splitlines() if line.strip()]
print(g.select_abi_candidate(cands, os.environ['ABI']) or '')")
        if [ -n "$base" ]; then
            found+="${pkg}=${base}"$'\n'
        else
            missing+=" $pkg"
        fi
    done
    rm -rf "$work"
    [ -z "$missing" ] || die "core packages missing or ambiguous in zip:$missing; refusing a partial store install"
    log "all core packages located for this ABI"

    # Phase 2: push the resolved set.
    adb_sel root >/dev/null 2>&1 || true; sleep 2
    adb_sel remount >/dev/null || die "adb remount failed; system image is not writable"
    printf '%s' "$found" | while IFS='=' read -r pkg base; do
        [ -n "$pkg" ] || continue
        adb_sel shell "mkdir -p /system/priv-app/${pkg}"
        adb_sel push "$base" "/system/priv-app/${pkg}/${pkg}.apk" >/dev/null
        adb_sel shell "chmod 644 /system/priv-app/${pkg}/${pkg}.apk"
        log "installed ${pkg}.apk into /system/priv-app/${pkg}/"
    done
    log "rebooting (wait for boot before verify)"
    adb_sel reboot
    log "if this flash leaves the AVD unbootable: quit the emulator, delete $AVD_DIR/snapshots/default_boot, and start once from the '$REQUIRED_SNAPSHOT' snapshot to roll back"
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
        local comp
        comp=$(adb_sel shell cmd package resolve-activity --brief "$package" | tail -1 | tr -d '\r')
        comp=$(COMP_IN="$comp" python3 -c "
import os, sys
sys.path.insert(0, '$repo_root/scripts')
import gapps_state as g
print(g.validate_component(os.environ['COMP_IN']) or '')")
        [ -n "$comp" ] || die "could not resolve a launchable activity for $package (got: '$(adb_sel shell cmd package resolve-activity --brief "$package" | tail -1 | tr -d '\r')')"
        adb_sel shell am start -n "$comp" >/dev/null
        sleep 8
        resumed=$(adb_sel shell "dumpsys activity activities | grep mResumedActivity | head -1")
        adb_sel shell rm -f /sdcard/ui.xml 2>/dev/null || true
        rm -f /tmp/probe-ui.xml
        adb_sel shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true
        adb_sel pull /sdcard/ui.xml /tmp/probe-ui.xml >/dev/null 2>&1 || : > /tmp/probe-ui.xml
        xml=$(cat /tmp/probe-ui.xml 2>/dev/null || true)
        if ! adb_sel exec-out screencap -p > "$out_dir/${package}-try${try}.png" 2>/dev/null; then
            log "WARN: screenshot failed for try ${try}; continuing with classification only"
            rm -f "$out_dir/${package}-try${try}.png"
        fi
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
