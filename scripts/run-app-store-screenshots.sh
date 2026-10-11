#!/bin/bash

set -euo pipefail

: "${SIM_UDID:?Set SIM_UDID to an existing, booted iPhone 17 Pro Max simulator}"
: "${ARTIFACT_DIR:?Set ARTIFACT_DIR to a temporary directory outside the repository}"
: "${GROWINGUP_APP_STORE_PHOTOS:?Set GROWINGUP_APP_STORE_PHOTOS to the absolute demo photo directory}"

for PHOTO in baby-girl young-boy cat dog; do
  test -s "$GROWINGUP_APP_STORE_PHOTOS/$PHOTO.png" \
    || { echo "Missing demo photo: $GROWINGUP_APP_STORE_PHOTOS/$PHOTO.png" >&2; exit 1; }
done

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

CAPTURE_STATUS=0
for LOCALE in en ru; do
  LOCALE_DIR="$ARTIFACT_DIR/$LOCALE"
  mkdir -p "$LOCALE_DIR"
  jq --arg locale "$LOCALE" '. + {locale: $locale}' "$ARTIFACT_DIR/metadata.json" \
    > "$LOCALE_DIR/metadata.json"

  # Expand the locale into the test runner configuration before recording.
  # The second build reuses Xcode's default DerivedData and is incremental.
  xcodebuild build-for-testing -project GrowingUp.xcodeproj -scheme GrowingUpUI \
    -destination "id=$SIM_UDID" -parallel-testing-enabled NO \
    -only-testing:GrowingUpUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots \
    GROWINGUP_APP_STORE_CAPTURE=1 GROWINGUP_APP_STORE_PHOTOS="$GROWINGUP_APP_STORE_PHOTOS" \
    GROWINGUP_APP_STORE_LOCALE="$LOCALE" GROWINGUP_VISUAL_CHECKS=0 GROWINGUP_RECORD_SNAPSHOTS=0 \
    CODE_SIGNING_ALLOWED=NO | tee "$LOCALE_DIR/build.log"

  xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 "$LOCALE_DIR/journeys.mp4" \
    > "$LOCALE_DIR/recording.log" 2>&1 &
  RECORDER_PID=$!

  for ATTEMPT in {1..30}; do
    grep -q 'Recording started' "$LOCALE_DIR/recording.log" && break
    kill -0 "$RECORDER_PID" 2>/dev/null \
      || { cat "$LOCALE_DIR/recording.log" >&2; exit 1; }
    sleep 1
  done
  grep -q 'Recording started' "$LOCALE_DIR/recording.log" \
    || { echo 'Simulator video recording did not start within 30 seconds.' >&2; exit 1; }

  TEST_STATUS=0
  xcodebuild test-without-building -project GrowingUp.xcodeproj -scheme GrowingUpUI \
    -destination "id=$SIM_UDID" -parallel-testing-enabled NO \
    -only-testing:GrowingUpUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots \
    -resultBundlePath "$LOCALE_DIR/UI.xcresult" \
    GROWINGUP_APP_STORE_CAPTURE=1 GROWINGUP_APP_STORE_PHOTOS="$GROWINGUP_APP_STORE_PHOTOS" \
    GROWINGUP_APP_STORE_LOCALE="$LOCALE" GROWINGUP_VISUAL_CHECKS=0 GROWINGUP_RECORD_SNAPSHOTS=0 \
    CODE_SIGNING_ALLOWED=NO | tee "$LOCALE_DIR/xcodebuild.log" || TEST_STATUS=$?

  # SIGINT finalizes the MP4 container even when an assertion failed.
  stop_recording
  test -s "$LOCALE_DIR/journeys.mp4"
  if [ "$TEST_STATUS" -ne 0 ] && [ "$CAPTURE_STATUS" -eq 0 ]; then
    CAPTURE_STATUS=$TEST_STATUS
  fi
done
exit "$CAPTURE_STATUS"
