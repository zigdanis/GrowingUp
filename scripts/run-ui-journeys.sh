#!/bin/bash

set -euo pipefail

: "${SIM_UDID:?Set SIM_UDID to an existing, booted simulator}"
: "${ARTIFACT_DIR:?Set ARTIFACT_DIR to a temporary directory outside the repository}"
: "${GROWINGUP_VISUAL_CHECKS:?Set GROWINGUP_VISUAL_CHECKS to 0 or 1}"

# Build first so the recording contains the journeys rather than compilation.
xcodebuild build-for-testing -project GrowingUp.xcodeproj -scheme GrowingUpUI \
  -destination "id=$SIM_UDID" -parallel-testing-enabled NO \
  GROWINGUP_VISUAL_CHECKS="$GROWINGUP_VISUAL_CHECKS" GROWINGUP_RECORD_SNAPSHOTS=0 \
  CODE_SIGNING_ALLOWED=NO | tee "$ARTIFACT_DIR/build.log"

RECORDER_PID=''
stop_recording() {
  if [ -n "$RECORDER_PID" ]; then
    kill -INT "$RECORDER_PID" 2>/dev/null || true
    wait "$RECORDER_PID"
    RECORDER_PID=''
  fi
}
trap stop_recording EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 "$ARTIFACT_DIR/journeys.mp4" \
  > "$ARTIFACT_DIR/recording.log" 2>&1 &
RECORDER_PID=$!

TEST_STATUS=0
xcodebuild test-without-building -project GrowingUp.xcodeproj -scheme GrowingUpUI \
  -destination "id=$SIM_UDID" -parallel-testing-enabled NO \
  -resultBundlePath "$ARTIFACT_DIR/UI.xcresult" \
  GROWINGUP_VISUAL_CHECKS="$GROWINGUP_VISUAL_CHECKS" GROWINGUP_RECORD_SNAPSHOTS=0 \
  CODE_SIGNING_ALLOWED=NO | tee "$ARTIFACT_DIR/xcodebuild.log" || TEST_STATUS=$?

# SIGINT lets simctl finish the MP4 container, including when a journey fails.
stop_recording
test -s "$ARTIFACT_DIR/journeys.mp4"
exit "$TEST_STATUS"
