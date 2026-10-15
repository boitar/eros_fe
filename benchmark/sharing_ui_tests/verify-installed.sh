#!/bin/bash
set -euo pipefail
device="${1:?usage: verify-installed.sh DEVICE_UUID EXTERNAL_OUTPUT RUN_NAME}"
output="${2:?missing external output directory}"
run="${3:?missing unique run name}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$output/sharing-harness"
output="$(cd "$output" && pwd)"
case "$output/" in "$root/"*) echo 'Output must be outside the checkout' >&2; exit 1;; esac
cd "$root"
xcodegen generate --spec benchmark/sharing_ui_tests/project.yml --project "$output/sharing-harness" \
  > "$output/$run-project.log" 2>&1
for phase in ${4:-GalleryLink ProfileExport LocalImage DownloadArchive}; do
  test ! -e "$output/$run-$phase.xcresult"
  # Start outside XCTest so each phase attaches to an already running process.
  # Each entry starts from the production home route in a fresh process.
  xcrun simctl terminate "$device" cn.honjow.fehv >/dev/null 2>&1 || true
  xcrun simctl launch "$device" cn.honjow.fehv --eros-test-semantics \
    > "$output/$run-$phase-launch.log" 2>&1
  method="testProduction$phase"
  xcodebuild -project "$output/sharing-harness/CustomBranchAcceptance.xcodeproj" \
    -scheme CustomBranchAcceptance -destination "platform=iOS Simulator,id=$device" \
    -only-testing:"CustomBranchAcceptanceUITests/ShareEntryTests/$method" \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
    -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240 \
    -collect-test-diagnostics never -derivedDataPath "$output/sharing-ui-tests" \
    -resultBundlePath "$output/$run-$phase.xcresult" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test > "$output/$run-$phase.log" 2>&1
done
