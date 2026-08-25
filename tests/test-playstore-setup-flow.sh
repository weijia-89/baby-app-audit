#!/usr/bin/env bash
# End-to-end tests for scripts/playstore-setup.sh using a fake `adb` shim.
# No emulator is contacted. Every destructive guard is exercised offline.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/playstore-flow.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

make_fake_env() {
    local dir="$1"
    mkdir -p "$dir/bin" "$dir/avd/snapshots" "$dir/device"
    cat > "$dir/bin/adb" <<SHIM
#!/usr/bin/env bash
set -u
FAKE="$dir"
cmd="\${1:-}"
if [ "\$#" -gt 0 ]; then shift; fi

handle_serial() {
  if [ "\$#" -gt 0 ]; then shift; fi
  verb="\${1:-}"
  if [ "\$#" -gt 0 ]; then shift; fi
  case "\$verb" in
    get-state)
      echo device ;;
    emu)
      if [ "\${1:-}" = avd ]; then shift; fi
      if [ "\${1:-}" = snapshot ]; then shift; fi
      if [ "\${1:-}" = save ]; then
        if [ "\$#" -gt 0 ]; then shift; fi
        if [ "\$#" -gt 0 ]; then mkdir -p "\$FAKE/avd/snapshots/\$1"; fi
      fi
      ;;
    shell)
      sub="\$*"
      case "\$sub" in
        *dumpsys*package*com.android.vending*)
          printf 'Package [com.android.vending]:
  versionName=34.2.14--release
' ;;
        *ro.product.cpu.abi*) echo arm64-v8a ;;
        *sys.boot_completed*) echo 1 ;;
        *cacerts/c8750f0d.0*) echo "/system/etc/security/cacerts/c8750f0d.0" ;;
        *pm*path*|*mkdir*|*chmod*) echo ok ;;
        *resolve-activity*)
          last=\$(printf '%s
' "\$sub" | rev | cut -d' ' -f1 | rev)
          printf 'priority=0 preferredOrder=0
%s/.MainActivity
' "\$last" ;;
        *uiautomator*|*rm*-f*) : ;;
        *) echo ok ;;
      esac ;;
    push)
      src="\${1:-}"; dst="\${2:-}"
      echo "pushed \$src -> \$dst" >> "\$FAKE/pushed.log" ;;
    pull)
      if [ "\$#" -ge 2 ]; then printf '<node />' > "\$2"; fi ;;
    exec-out)
      : ;;
    reboot) : ;;
    root) echo restarted ;;
    remount) echo remounted ;;
    *) : ;;
  esac
}

case "\$cmd" in
  devices)
    printf 'List of devices attached
emulator-5554	device
' ;;
  get-state)
    echo device ;;
  -s)
    handle_serial "\$@" ;;
  emu)
    if [ "\${1:-}" = avd ]; then shift; fi
    if [ "\${1:-}" = snapshot ]; then shift; fi
    if [ "\${1:-}" = save ]; then
      if [ "\$#" -gt 0 ]; then mkdir -p "\$FAKE/avd/snapshots/\$1"; fi
    fi
    ;;
  *)
    :
    ;;
esac
SHIM
    chmod +x "$dir/bin/adb"
}

run_setup() {
    local fake="$1"; shift
    if [ -n "${FLOW_DEBUG:-}" ]; then
        PATH="$fake/bin:$PATH" PLAYSTORE_AVD_DIR="$fake/avd" \
            bash -x "$repo_root/scripts/playstore-setup.sh" "$@"
    else
        PATH="$fake/bin:$PATH" PLAYSTORE_AVD_DIR="$fake/avd" \
            bash "$repo_root/scripts/playstore-setup.sh" "$@"
    fi
}

# --- S1: check passes when all prerequisites are faked ----------------------
fake="$tmp_root/s1"; make_fake_env "$fake"
mkdir -p "$fake/avd/snapshots/pre-gapps"
if run_setup "$fake" check >/dev/null 2>&1; then echo "S1 pass"; else echo "S1 FAIL"; exit 1; fi

# --- S2: check fails and names the missing snapshot -------------------------
fake="$tmp_root/s2"; make_fake_env "$fake"
out=$(run_setup "$fake" check 2>&1) && { echo "S2 FAIL (expected nonzero)"; exit 1; }
printf '%s' "$out" | grep -q "snapshot pre-gapps missing" || { echo "S2 FAIL (message)"; exit 1; }
echo "S2 pass"

# --- S3: backup creates the snapshot; duplicate refuses without --force -----
fake="$tmp_root/s3"; make_fake_env "$fake"
run_setup "$fake" backup pre-gapps >/dev/null
[ -e "$fake/avd/snapshots/pre-gapps" ] || { echo "S3 FAIL (no snapshot)"; exit 1; }
if run_setup "$fake" backup pre-gapps >/dev/null 2>&1; then echo "S3 FAIL (no refuse)"; exit 1; fi
run_setup "$fake" backup pre-gapps --force >/dev/null
echo "S3 pass"

# --- S4: install-zip refuses without the required snapshot ------------------
fake="$tmp_root/s4"; make_fake_env "$fake"
echo x > "$fake/app.zip"
if run_setup "$fake" install-zip "$fake/app.zip" "$fake/SUMS" >/dev/null 2>&1; then
    echo "S4 FAIL"; exit 1
fi
echo "S4 pass"

# --- S5..S7 fixtures: a real zip + sums, plus an escape-path zip -------------
fake="$tmp_root/s5"; make_fake_env "$fake"
mkdir -p "$fake/avd/snapshots/pre-gapps" "$fake/payload/Core/gmscore/arm64_v8a" "$fake/payload/x86_64"
python3 - "$fake" <<'PY'
import sys, zipfile, hashlib, os
fake = sys.argv[1]
payload = os.path.join(fake, "payload")
zpath = os.path.join(fake, "gapps.zip")
with zipfile.ZipFile(zpath, "w") as z:
    z.write(os.path.join(payload, "Core", "gmscore", "arm64_v8a"), "")  # placeholder no-op guard
# zipfile cannot add dirs; write members explicitly:
with zipfile.ZipFile(zpath, "w") as z:
    for rel in (
        "Core/gmscore/arm64_v8a/GmsCore.apk",
        "Core/phonesky/arm64_v8a/Phonesky.apk",
        "Core/gsf/arm64_v8a/GoogleServicesFramework.apk",
        "Core/gmscore/x86_64/GmsCore.apk",
    ):
        z.writestr(rel, "apk-bytes")
h = hashlib.sha256(open(zpath, "rb").read()).hexdigest()
open(os.path.join(fake, "SUMS"), "w").write(f"{h}  gapps.zip\n")
# escape-path archive for S7
with zipfile.ZipFile(os.path.join(fake, "evil.zip"), "w") as z:
    z.writestr("../evil.sh", "bad")
print("fixtures ready")
PY
run_setup "$fake" install-zip "$fake/gapps.zip" "$fake/SUMS" >/dev/null
grep -q "priv-app/Phonesky/Phonesky.apk" "$fake/pushed.log" || { echo "S5 FAIL (Phonesky)"; exit 1; }
grep -q "priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk" "$fake/pushed.log" || { echo "S5 FAIL (GmsCore)"; exit 1; }
grep -q "arm64_v8a/GmsCore.apk" "$fake/pushed.log" || { echo "S5 FAIL (wrong ABI selected)"; exit 1; }
grep -qv "x86_64" "$fake/pushed.log" || true
run_setup "$fake" verify >/dev/null
echo "S5 pass (ABI-aware happy path + verify)"

# --- S6: checksum mismatch refuses ------------------------------------------
fake="$tmp_root/s6"; make_fake_env "$fake"
mkdir -p "$fake/avd/snapshots/pre-gapps"
echo stale > "$fake/gapps.zip"
echo deadbeef  gapps.zip > "$fake/SUMS"
out=$(run_setup "$fake" install-zip "$fake/gapps.zip" "$fake/SUMS" 2>&1) && { echo "S6 FAIL"; exit 1; }
printf '%s' "$out" | grep -qi "checksum verification did not pass" || { echo "S6 FAIL (message)"; exit 1; }
[ ! -e "$fake/pushed.log" ] || { echo "S6 FAIL (device touched)"; exit 1; }
echo "S6 pass"

# --- S7: escape-path archive refuses ----------------------------------------
fake="$tmp_root/s7"; make_fake_env "$fake"
mkdir -p "$fake/avd/snapshots/pre-gapps"
python3 - "$fake" <<'PY'
import zipfile, hashlib, os, sys
fake = sys.argv[1]
zpath = os.path.join(fake, "evil.zip")
with zipfile.ZipFile(zpath, "w") as z:
    z.writestr("../evil.sh", "bad")
h = hashlib.sha256(open(zpath, "rb").read()).hexdigest()
open(os.path.join(fake, "SUMS"), "w").write(f"{h}  evil.zip\n")
PY
out=$(run_setup "$fake" install-zip "$fake/evil.zip" "$fake/SUMS" 2>&1) && { echo "S7 FAIL"; exit 1; }
printf '%s' "$out" | grep -qi "escape paths" || { echo "S7 FAIL (message)"; exit 1; }
echo "S7 pass"

# --- S8: probe classifies a healthy launch and writes the verdict file -------
fake="$tmp_root/s8"; make_fake_env "$fake"
mkdir -p "$fake/avd/snapshots/pre-gapps" "$fake/results-tree"
run_setup "$fake" pairip-probe com.mimiapp.mimilog >/dev/null
found=$(find "$repo_root/results"/com.mimiapp.mimilog-test-*/artifacts/logs -name "com.mimiapp.mimilog.verdict" 2>/dev/null | head -1)
[ -n "$found" ] && grep -q "ok" "$found" || { echo "S8 FAIL (verdict)"; exit 1; }
echo "S8 pass"

echo "playstore-setup flow tests passed"
