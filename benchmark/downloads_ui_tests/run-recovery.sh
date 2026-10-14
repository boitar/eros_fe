#!/bin/bash
set -euo pipefail
device="${1:?usage: run-recovery.sh DEVICE_UUID EXTERNAL_OUTPUT RUN_NAME}"
output="${2:?missing external output directory}"
run="${3:?missing unique run name}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
case "$output/" in "$root/"*) echo "Output must be outside the checkout" >&2; exit 1;; esac
test ! -e "$output/$run-result.json"
cd "$root"
# Run run-native.sh first to prepare the public config and deployment pods.
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug-SimulatorUI -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -jobs 2 \
  -derivedDataPath "$output/downloads-recovery-derived" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  FLUTTER_TARGET=test/support/download_recovery_simulator.dart DART_DEFINES= build \
  > "$output/$run-build.log" 2>&1
xcrun simctl install "$device" \
  "$output/downloads-recovery-derived/Build/Products/Debug-SimulatorUI-iphonesimulator/fehviewer.app"
touch "$output/$run-started"
xcrun simctl launch --terminate-running-process "$device" cn.honjow.fehv \
  > "$output/$run-launch.log" 2>&1
container="$(xcrun simctl get_app_container "$device" cn.honjow.fehv data)"
result="$container/Documents/download-recovery-validation/result.json"
for attempt in $(seq 1 60); do
  if [ -f "$result" ] && [ "$result" -nt "$output/$run-started" ]; then
    cp "$result" "$output/$run-result.json"
    python3 - "$output/$run-result.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report['success'], report
assert len(report['passed']) == 15, report
print('iOS Isar/filesystem recovery: 15 scenarios passed')
PY
    exit 0
  fi
  sleep 1
done
echo 'No fresh recovery result was produced' >&2
exit 1
