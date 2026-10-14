#!/bin/bash
set -euo pipefail
device="${1:?usage: run-native.sh DEVICE_UUID EXTERNAL_OUTPUT RUN_NAME}"
output="${2:?missing external output directory}"
run="${3:?missing unique run name}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$output/harness"
output="$(cd "$output" && pwd)"
case "$output/" in "$root/"*) echo "Output must be outside the checkout" >&2; exit 1;; esac
test ! -e "$output/$run.xcresult"
cd "$root"
cp analysis_options.yaml "$output/$run-analysis-options.yaml"
trap 'cp "$output/$run-analysis-options.yaml" "$root/analysis_options.yaml"' EXIT
flutter pub get --enforce-lockfile > "$output/$run-pub.log" 2>&1
cp "$output/$run-analysis-options.yaml" analysis_options.yaml
(cd ios && pod install --deployment) > "$output/$run-pods.log" 2>&1
defines="$(printf %s EROS_OFFLINE_ACCEPTANCE=true | base64 | tr -d '\n'),$(printf %s EROS_DOWNLOAD_ACCEPTANCE=true | base64 | tr -d '\n')"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug-SimulatorUI -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -jobs 3 \
  -derivedDataPath "$output/app-build" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  FLUTTER_TARGET=lib/main.dart DART_DEFINES="$defines" build \
  > "$output/$run-build.log" 2>&1
xcrun simctl install "$device" \
  "$output/app-build/Build/Products/Debug-SimulatorUI-iphonesimulator/fehviewer.app"
xcodegen generate --spec benchmark/downloads_ui_tests/project.yml --project "$output/harness"
xcodebuild -project "$output/harness/CustomBranchAcceptance.xcodeproj" \
  -scheme CustomBranchAcceptance -destination "platform=iOS Simulator,id=$device" \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240 \
  -collect-test-diagnostics never -derivedDataPath "$output/ui-build" \
  -resultBundlePath "$output/$run.xcresult" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test > "$output/$run-ui.log" 2>&1
