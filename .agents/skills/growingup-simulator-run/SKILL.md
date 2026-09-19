---
name: growingup-simulator-run
description: Build, test, install, or launch the GrowingUp iOS project on an iOS Simulator. Use only when working in the GrowingUp repository or one of its Git worktrees and a task requires xcodebuild, simulator tests, simctl installation, app launch, or simulator smoke testing.
---

# GrowingUp Simulator Run

Keep signing enabled. GrowingUp requires the `group.pro.ziganshin.aging` App Group; using `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, or equivalent overrides prevents Simulator App Group access and makes the app or test host crash with `Failed to get App Group URL`.

## Workflow

1. Confirm the checkout belongs to GrowingUp and inspect `git status`.
2. Select an available simulator with `xcrun simctl list devices available`.
3. Run formatting and lint when validating a PR:

   ```sh
   scripts/check-formatting.sh
   scripts/lint-swift.sh
   ```

4. Build and test without any signing-disabling overrides:

   ```sh
   xcodebuild \
     -project GrowingUp.xcodeproj \
     -scheme GrowingUp \
     -configuration Debug \
     -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
     -derivedDataPath <DERIVED_DATA_PATH> \
     clean test
   ```

5. Before launch, verify the resolved build settings keep signing enabled and point to the entitlement file:

   ```sh
   xcodebuild -project GrowingUp.xcodeproj -scheme GrowingUp -configuration Debug \
     -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' -showBuildSettings \
     | grep -E 'CODE_SIGNING_ALLOWED|CODE_SIGN_ENTITLEMENTS'
   grep -A2 com.apple.security.application-groups 'GrowingUp/Supporting Files/GrowingUp.entitlements'
   ```

   Require `CODE_SIGNING_ALLOWED = YES`, the GrowingUp entitlement path, and `group.pro.ziganshin.aging`. Do not reject a Simulator build solely because `codesign -d --entitlements` prints an empty dictionary; Xcode may omit embedded entitlements for Simulator while still provisioning App Group access during a signed run.

6. Install and launch the same signed build:

   ```sh
   xcrun simctl install <SIMULATOR_UDID> <DERIVED_DATA_PATH>/Build/Products/Debug-iphonesimulator/GrowingUp.app
   xcrun simctl launch --terminate-running-process <SIMULATOR_UDID> pro.ziganshin.GrowingUp
   ```

7. Treat a successful build as insufficient. Confirm the process remains alive, inspect crash/system logs when it does not, and visually smoke-test the requested flows.

Never use an unsigned simulator run as evidence that GrowingUp is broken.
