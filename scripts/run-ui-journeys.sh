#!/bin/bash

set -euo pipefail

: "${SIM_UDID:?Set SIM_UDID to an existing, booted simulator}"
: "${ARTIFACT_DIR:?Set ARTIFACT_DIR to a temporary directory outside the repository}"

# Build first so optional video contains the journeys rather than compilation.
xcodebuild build-for-testing -project GrowingUp.xcodeproj -scheme GrowingUpUI \
  -destination "id=$SIM_UDID" -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO | tee "$ARTIFACT_DIR/build.log"

RECORDER_PID=''
stop_recording() {
  if [ -n "$RECORDER_PID" ]; then
    kill -INT "$RECORDER_PID" 2>/dev/null || true
    # An unresponsive simctl must not turn a 30-second recording failure into a 40-minute CI timeout.
    for ATTEMPT in {1..10}; do
      kill -0 "$RECORDER_PID" 2>/dev/null || break
      sleep 1
    done
    kill -KILL "$RECORDER_PID" 2>/dev/null || true
    local RECORD_STATUS=0
    wait "$RECORDER_PID" 2>/dev/null || RECORD_STATUS=$?
    RECORDER_PID=''
    return "$RECORD_STATUS"
  fi
}
trap stop_recording EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# XCTest screenshots are the default evidence. Video is opt-in for changes whose motion needs review.
if [ "${UI_RECORD_VIDEO:-0}" = 1 ]; then
# Devices with several screens, such as iPhone Duo, record only the one named in SIM_DISPLAY.
xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 ${SIM_DISPLAY:+"--display=$SIM_DISPLAY"} \
  "$ARTIFACT_DIR/journeys.mp4" > "$ARTIFACT_DIR/recording.log" 2>&1 &
RECORDER_PID=$!

# Wait for simctl to attach before allowing the first app interaction.
for ATTEMPT in {1..30}; do
  grep -q 'Recording started' "$ARTIFACT_DIR/recording.log" && break
  kill -0 "$RECORDER_PID" 2>/dev/null || { cat "$ARTIFACT_DIR/recording.log" >&2; exit 1; }
  sleep 1
done
grep -q 'Recording started' "$ARTIFACT_DIR/recording.log" \
  || { echo 'Simulator video recording did not start within 30 seconds.' >&2; exit 1; }
fi

TEST_STATUS=0
# Skipping diagnostics collection keeps a failing journey from stalling the run for minutes.
xcodebuild test-without-building -project GrowingUp.xcodeproj -scheme GrowingUpUI \
  -destination "id=$SIM_UDID" -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath "$ARTIFACT_DIR/UI.xcresult" \
  CODE_SIGNING_ALLOWED=NO | tee "$ARTIFACT_DIR/xcodebuild.log" || TEST_STATUS=$?

# SIGINT lets simctl finish the MP4 container, including when a journey fails.
RECORD_STATUS=0
stop_recording || RECORD_STATUS=$?
if [ "${UI_RECORD_VIDEO:-0}" = 1 ]; then
  test -s "$ARTIFACT_DIR/journeys.mp4" || RECORD_STATUS=1
fi
test "$TEST_STATUS" = 0 || exit "$TEST_STATUS"
test "$RECORD_STATUS" = 0 || exit "$RECORD_STATUS"
exit "$TEST_STATUS"
