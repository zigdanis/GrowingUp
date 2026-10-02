# GrowingUp TestFlight from Linux / T3 Code

Tell the deployment thread **“Deploy GrowingUp to TestFlight”**. Each new release
advances the marketing version; retries retain the exact version/build. No MacBook
steps or routine App Store Connect edits are required. Deployments are explicit:
the release workflow has only `workflow_dispatch`, never push/merge triggers.

## One-time credentials

Credentials never belong in this public repository. Use the GitHub **testflight**
environment's secret UI: [environment settings](https://github.com/zigdanis/GrowingUp/settings/environments).
Its deployment branch policy must allow only the `master` **branch**, with no tag
policy. Pull request branches therefore cannot access these environment secrets.
People able to modify the trusted master workflow can still access its secrets;
review release workflow changes before merging them.

Add environment secrets `ASC_PRIVATE_KEY` (downloaded `.p8` contents),
`ASC_KEY_ID`, `ASC_ISSUER_ID`, and the existing signing repository's `MATCH_PASSWORD`.
Use an App Store Connect **team** API key with Admin access: individual keys cannot
use provisioning endpoints, and signing renewal needs certificate permissions.
GitHub signing access uses `MATCH_GIT_PRIVATE_KEY`, a dedicated write deploy key
limited to the private `zigdanis/zigdanis-certificates` repository. Never use an
Apple account password or paste credentials into T3 conversation messages.

For a file-based transfer, put temporary input copies outside every checkout,
for example `~/.config/growingup-testflight/credentials.json` and `AuthKey.p8`.
Protect the directory with `chmod 700` and both files with `chmod 600`.

```json
{
  "ASC_KEY_ID": "",
  "ASC_ISSUER_ID": "",
  "ASC_PRIVATE_KEY_PATH": "/home/zigdanis/.config/growingup-testflight/AuthKey.p8",
  "MATCH_PASSWORD": ""
}
```

Run `python3 scripts/testflight-secrets.py`. It passes values to `gh secret set
--env testflight` over stdin without echoing them. It removes both input copies
only after all four secrets are saved; keep the original downloaded key in your
own secure storage. Direct GitHub secret entry needs no local input files.

Environment/repository variables: `APPLE_TEAM_ID=XMSU8WJG5R`,
`MATCH_GIT_URL=git@github.com:zigdanis/zigdanis-certificates.git`. Cloud preflight
discovers the App Store Connect app, groups, testers, versions and build numbers.
It prefers the existing `External` group and identifies Danis by tester name.
If ambiguous, set `BETA_GROUP_ID` / `BETA_TESTER_ID` to IDs from its inventory.
An existing tester can be added to the intended group through the API. If Danis
has no tester record, the deployment thread needs his TestFlight email to invite
him; it must not guess an email or create another Apple account.

## Commands

The workflow must first be reviewed and merged into `master` with Danis's approval.
Authenticated `gh` and Python 3 are sufficient on Linux:

```bash
python3 scripts/testflight.py ready
python3 scripts/testflight.py preflight
python3 scripts/testflight.py deploy next master /tmp/growingup-notes.json
python3 scripts/testflight.py status ORIGINAL_RUN_ID
python3 scripts/testflight.py resume ORIGINAL_RUN_ID
```

The notes file contains nonempty `en` and `ru` strings, at most 4000 UTF-8 bytes
each. It contains tester instructions, never credentials. `next` advances the
patch version above all Apple versions and the selected source's project version;
an explicit version must also exceed every existing version. Several builds per
marketing version are supported by Apple, but this project's new deployments
deliberately advance both version and build. The source ref resolves to a recorded
full SHA on master, and the latest CI run for that SHA must pass.

The command returns the exact Actions URL and a `gh run watch` command. It refuses
to dispatch over a pending release operation. The workflow serializes releases
across all sources. `preflight` checks account/tester access and app/widget signing
without uploading. `status` only reads Apple state; `resume` finishes processing,
metadata or distribution for the recorded build, without repeating an attempted
upload. If the first run stopped before attempting upload, resume can still
archive and perform that release's first upload.

## Release and recovery

The existing `app_store` lane uses `match` for both app and widget, reusing valid
certificates/profiles and renewing expired signing without revoking certificates.
If certificate slots are exhausted, stop and inspect the usable certificates;
never run `match nuke` or revoke a working certificate to make a retry pass.

Build numbers exceed all Apple builds/uploads and all reserved release receipts.
App/widget versions are overridden together and verified in the archive before
upload. Release receipts are annotated `testflight/releases/BUILD-RUN` tags
pointing to the source commit, plus nonsecret JSON artifacts and Actions summaries.
They record source SHA, version/build, workflow URL, group/tester IDs and actual
processing/distribution state. The release lane does not commit a version bump
or push a branch.

An upload intent is recorded before Transporter starts. After interruption, a
retry polls that exact build rather than uploading another binary. If Apple has
not exposed it after the bounded wait, inspect upload diagnostics and keep the
same release pending; do not dispatch duplicate uploads. Failed Apple processing
requires diagnosis and a corrected release, not repeated submission of the same
binary. A successful workflow can mean beta review is still pending.

The app declares no nonexempt encryption. The lane uses that declaration for
export compliance, sets EN/RU test notes, reuses review contact data, submits
external beta review and enables tester notifications. If existing contact data
is missing, provide only the reported fields through a `BETA_REVIEW_INFO` JSON
environment secret (`contact_first_name`, `contact_last_name`, `contact_email`,
`contact_phone`). A missing feedback address uses `BETA_FEEDBACK_EMAIL`.

Apple API access approval, legal agreement acceptance and Apple review decisions
cannot be bypassed by fastlane. The account holder must handle a concrete account
requirement when Apple reports it; processing/review is monitored on the same
release. Runner keys, temporary keychains, archives, logs and DerivedData are
removed after execution; only the nonsecret receipt is uploaded as an artifact.

The first-delivery goal remains open until **Danis explicitly confirms the new
version/build arrived in TestFlight on his phone**, even when Apple reports the
build available. While waiting for that confirmation, inspect status rather than
uploading another build.

References: [Apple API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api),
[Apple build uploads](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-builduploads),
[fastlane match](https://docs.fastlane.tools/actions/match/),
[fastlane pilot](https://docs.fastlane.tools/actions/pilot/),
[GitHub environment secrets](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).
