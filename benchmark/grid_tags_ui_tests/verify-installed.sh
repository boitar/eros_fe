#!/bin/bash
set -euo pipefail
device="${1:?usage: verify-installed.sh DEVICE_UUID EXTERNAL_OUTPUT RUN_NAME}"
output="${2:?missing external output directory}"
run="${3:?missing unique run name}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$output/grid_tags-harness"
output="$(cd "$output" && pwd)"
case "$output/" in "$root/"*) echo 'Output must be outside the checkout' >&2; exit 1;; esac
cd "$root"
xcodegen generate --spec benchmark/grid_tags_ui_tests/project.yml --project "$output/grid_tags-harness" \
  > "$output/$run-project.log" 2>&1
for phase in ${4:-GeometryAndRotation ModeWidthAndPersistence RestoredModeAndWidth}; do
  test ! -e "$output/$run-$phase.xcresult"
  # Start outside XCTest so each phase attaches to an already running process.
  # A new process must read the persisted database for each phase.
  xcrun simctl terminate "$device" cn.honjow.fehv >/dev/null 2>&1 || true
  xcrun simctl launch "$device" cn.honjow.fehv --eros-test-semantics \
    > "$output/$run-$phase-launch.log" 2>&1
  method="testProduction$phase"
  xcodebuild -project "$output/grid_tags-harness/CustomBranchAcceptance.xcodeproj" \
    -scheme CustomBranchAcceptance -destination "platform=iOS Simulator,id=$device" \
    -only-testing:"CustomBranchAcceptanceUITests/GridTagsEntryTests/$method" \
    -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
    -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240 \
    -collect-test-diagnostics never -derivedDataPath "$output/grid_tags-ui-tests" \
    -resultBundlePath "$output/$run-$phase.xcresult" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test > "$output/$run-$phase.log" 2>&1
done
if [[ -f "$output/$run-ModeWidthAndPersistence.log" &&
      -f "$output/$run-RestoredModeAndWidth.log" ]]; then
  python3 - "$output" "$run" <<'PY'
from pathlib import Path
import re
import sys

output = Path(sys.argv[1])
run = sys.argv[2]

def observed(phase, marker):
    text = (output / f"{run}-{phase}.log").read_text()
    values = {int(value) for value in re.findall(marker + r"=(\d+)", text)}
    assert len(values) == 1, f"Missing or inconsistent real UI observation: {phase}"
    value = values.pop()
    assert 100 <= value <= 400, f"Width outside supported range: {value}"
    return value

expected = observed("ModeWidthAndPersistence", "EROS_GRID_EXPECTED_WIDTH")
restored = observed("RestoredModeAndWidth", "EROS_GRID_RESTORED_WIDTH")
assert restored == expected, f"Width did not persist: expected {expected}, restored {restored}"
print(f"EROS_GRID_PERSISTENCE_CONFIRMED width={restored}")
PY
fi
