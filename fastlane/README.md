# GrowingUp release lanes

Use `python3 scripts/testflight.py` to run the existing master-only workflow. Its `--help` lists the commands; do not invoke these lanes directly.

- `ios release_preflight`: check account, tester access and app/widget signing.
- `ios app_store`: archive/upload a new release, or resume its exact build.
- `ios release_status`: read processing and distribution without uploading.
- `ios release_notes`: update and verify notes on an existing build without uploading.

## Credentials and signing

- Keep credentials in the master-only `testflight` GitHub environment. The launcher's `ready` command lists required secret names; `scripts/testflight-secrets.py` securely imports Apple/match values without replacing the signing SSH key.
- For new signing credentials, use a team App Store Connect API key with Admin access.
- Preserve the configured signing branch and working certificates. Never use `match nuke` or revoke certificates to force a release through.
- The recorded `MATCH_PASSWORD` backup is in the Mac login Keychain: service `pro.ziganshin.GrowingUp.match`, account `growingup-ci-20261004`. Retrieve it locally without printing it or putting it in command arguments.
