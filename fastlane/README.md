# TestFlight release commands

Use `scripts/testflight` from the repository root. Choose `local` (this Mac) or
`cloud` (GitHub Actions) explicitly; both use the same Fastlane release engine.

```sh
scripts/testflight notes                         # local LLM generates and prints EN/RU notes
scripts/testflight check local                   # read-only Apple/signing/numbering checks
scripts/testflight deploy local --version 2.2.0  # archive, upload, notes and tester distribution
```

Replace `local` with `cloud` for the hosted executor. Notes generation always runs
on the invoking computer using its signed-in Codex CLI and configured model; no
OpenAI login or token is sent to GitHub Actions. Generated notes and source metadata
are kept in ignored `build/testflight/`, with no filename to invent. Deployment
refreshes missing/stale notes automatically. `--notes FILE` uses an explicit EN/RU
JSON file instead. The selected source must belong to `master`. Cloud deployment is
queued immediately and returns its live Actions URL; a Linux job waits for that exact
source's CI before starting the signing/build runner. Failed CI blocks upload with a
link to the failed job. Local deployment still requires CI to have passed before launch.

Both executors reserve the next unused build number from Apple and shared private
receipts, then apply the same version/build to the app and Widget. `--version` can
select an existing beta train above the approved App Store version; omitted, it
chooses the next patch above all known versions. Neither executor edits version
numbers in the developer's working copy.

## One-time setup

- Local: install Xcode, Ruby/Bundler, GitHub CLI (`gh auth login`) and Codex CLI.
  Run `scripts/testflight setup local --api-key /path/to/asc_api_key.json` with an
  existing owner-only API JSON key outside Git. It contains `key_id`, `issuer_id`
  and `key` (PEM content), optionally `is_key_content_base64`.
- Local setup saves only the key file path in owner-only
  `~/.config/growingup-testflight/local.json` and installs the locked gems in
  `~/.local/share/growingup/bundle`. The existing Apple Distribution identity and
  its private key must be available in the Mac login Keychain.
- The existing Match password backup is read from the Mac login Keychain: service
  `pro.ziganshin.GrowingUp.match`, account `growingup-ci-20261004`. Local signing
  syncs existing material read-only; it does not create or revoke certificates.
- Cloud: `scripts/testflight setup cloud` checks the existing master-only
  `testflight` GitHub environment. Keep Apple/Match credentials in that environment;
  `scripts/testflight-secrets.py` securely imports them when setup is needed.

## Continue or inspect a release

```sh
python3 scripts/testflight.py progress RUN_ID # read-only jobs/phase/build/Apple receipt; no workflow dispatch
scripts/testflight status local        # latest local release; or: status cloud
scripts/testflight resume local        # continue its exact version/build; or: resume cloud
scripts/testflight status local ID     # inspect a particular original release
scripts/testflight archive local       # reserve and archive/export without uploading
scripts/testflight update-notes local ID --notes /path/to/notes.json
```

Local logs, receipts, archives and IPAs are in
`~/Library/Application Support/GrowingUp/releases/`. Cloud archive-only output is
attached to its Actions run. Receipts are shared across executors so a release can
be resumed on the other executor with its original ID. After upload starts, resume
checks Apple visibility rather than sending the IPA again. Apple processing/Beta
App Review may delay tester access; a successful upload is not phone delivery.

Number allocation and upload claims use a short shared GitHub lock. An interrupted
lock fails with recovery instructions; verify its owner has stopped before removing
it. Never use `match nuke` or revoke certificates to force a release through.

Legacy `python3 scripts/testflight.py ready`, `preflight`,
`deploy VERSION SHA NOTES_JSON`, `status RUN_ID`, `resume RUN_ID` and
`notes RUN_ID NOTES_JSON` remain cloud-compatible for existing automation.
