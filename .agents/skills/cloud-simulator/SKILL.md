---
name: cloud-simulator
description: Drive a GrowingUp CI build on an Expo EAS cloud iOS Simulator from any Fleet machine, including Linux. Use for a short interactive check of a PR head or master: install, tap, read frames, take screenshots, stop.
---

# Cloud simulator

The generic `eas-simulator` skill has the command syntax. This page adds what GrowingUp needs. The Expo trial gives 60 minutes in total for simulators and workflows, one session at a time, until 1 November 2026. Keep each session to a few minutes.

## Before the session

- Download the build first, so the paid session doesn't wait on GitHub: `TMPDIR=$HOME/.cache/growingup-sim scripts/simulator-app.sh [PR]` (create the directory first). Retry on `TLS handshake timeout`.
- Warm the npx cache: `npx --yes eas-cli@latest simulator:availability --json --non-interactive` and `npx --yes agent-device@latest --version`.
- Run every `eas simulator:*` command from `~/myai/fleet/services/expo-simulators/growingup`, which holds the EAS project link. Never run `eas init` in this repo. Its `.env.eas-simulator` should name no live session.

## Session

```sh
e() { npx --yes eas-cli@latest "$@"; }; x() { e simulator:exec npx agent-device@latest "$@"; }   # bash and zsh
e simulator:start --platform ios --type agent-device --name "PR 103 photo Back check" \
  --max-duration-minutes 6 --max-idle-time-minutes 2 --non-interactive --json
e simulator:get --json --non-interactive    # status IN_PROGRESS, remoteConfig.webPreviewUrl
x install pro.ziganshin.GrowingUp PATH/GrowingUp.app --platform ios
x open pro.ziganshin.GrowingUp --platform ios
x press 'label="Add person"' --settle        # prints the UI diff; 'id="..."' matches identifiers
x snapshot -i --json                         # rects of interactive elements; --raw keeps unclipped frames
x screenshot $HOME/.cache/growingup-sim/step.png
e simulator:stop --non-interactive && printf '# managed by eas-cli\n' > .env.eas-simulator
```

- Send the developer the `webPreviewUrl` as soon as the session starts. They watch it in a browser signed in to Expo. T3's Device panel can't open sessions on the trial plan, because T3 sends `corsOrigins`, so the browser preview is the only way to watch.
- If `open` prints nothing and `snapshot` then reports `SESSION_NOT_FOUND`, run `open` again.
- An element hidden behind the keyboard can't be tapped. Run `keyboard enter` first.
- If the remote daemon drops (`Remote daemon is unavailable`), stop the session, reset the dotenv and retry once.
- Confirm `simulator:get --id ID` shows `STOPPED`, then delete the downloaded `.app`.

## What the fresh simulator shows

- The app starts at the empty state with an **Add person** button. The editor's photo control is **Add a photo**, which opens a menu with Camera and Photos.
- Photos first asks for library access: press **Allow Full Access**. The simulator includes sample photos.
- The simulator has no camera, so Camera shows **Camera access needed**.
- The photo sheet's controls render about 4% smaller than their nominal size: a 44-point glass button measures 42.25 points.
