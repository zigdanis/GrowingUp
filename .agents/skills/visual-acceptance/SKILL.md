---
name: visual-acceptance
description: Capture, inspect and attach iOS simulator screenshots or videos to pull requests. Use for user-visible features and UI fixes before merge or TestFlight deployment.
---

# Visual acceptance

Capture and inspect screenshots or video that show the requested UI change, then attach them to the PR. For non-UI changes, report functional checks instead.

Make the result easy for the developer to assess in the PR. Use the project's existing tools to capture and publish evidence.

- **Show:** capture the feature or fix described in the PR from its current code. Use a short video when screenshots aren't enough.
- **Limit:** use 1–3 screenshots by default. Skip duplicates and unrelated screens.
- **Check:** confirm that the media shows the requested behavior, attach it to the PR and check that it displays clearly.
- **Clean up:** remove temporary downloads, screenshots and video clips after publishing and checking the PR.

Once the feature is ready, attach its reviewed screenshots or demo to the PR body. TestFlight processing and later release steps do not need to finish first.
