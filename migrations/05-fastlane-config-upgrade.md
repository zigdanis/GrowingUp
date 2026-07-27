# Migration: Upgrade fastlane configuration

**Status:** Completed by `5535ec4`, `ccc8a09`, `6dcd16a`, `473c7e4`, and
`fbd024e`; verified after merging `master` into this branch.

> **Agent prompt — paste this to start the task.**
>
> You are upgrading and hardening GrowingUp's fastlane setup. First produce a
> concrete plan (post it for review), then implement it.
>
> **Current state**
> - `fastlane` **2.133.0** (2019-era) pinned via `Gemfile`/`Gemfile.lock`.
> - `fastlane/Fastfile` has an `app_store` lane using `match`, `gym`, `pilot`,
>   `increment_build_number`, `commit_version_bump`, `push_to_git_remote`, and a
>   Telegram notification.
> - `fastlane/Pluginfile` pulls `fastlane-plugin-telegram` from a personal fork.
> - `fastlane/Matchfile` uses git storage, `type("development")` only.
> - `fastlane/Appfile` holds `app_identifier`, `apple_id`, `team_id`,
>   `itc_team_id`.
> - **Security:** `fastlane/.env` is **committed** and contains
>   `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`. The Telegram lane also passes a
>   **hardcoded HTTP proxy with inline credentials**
>   (`proxy: "https://zigdanis:...@.../"`).
>
> **Goal**
> - Move to a current, supported fastlane; remove secrets from source; keep the
>   release lanes working with modern Apple tooling (App Store Connect API key
>   auth, `match`, current `gym`/`pilot`).
>
> **Plan must cover**
> 1. Bump `fastlane` to the latest in `Gemfile`/`Gemfile.lock`; resolve any
>    deprecated action/option warnings across the Fastfile.
> 2. **Secret hygiene (priority):** stop tracking `fastlane/.env`; add it to
>    `.gitignore`; provide a committed `.env.sample` with key names only;
>    **rotate** the leaked Telegram bot token and remove the hardcoded proxy
>    credentials (use env vars). Note that the leaked values must be treated as
>    compromised and scrubbed (consider history scrub / BFG as a follow-up).
> 3. Auth modernization: migrate from Apple-ID/2FA + `itc_provider` to an
>    **App Store Connect API key** (`app_store_connect_api_key`) for `pilot`/
>    `deliver`; keep `match` (consider `readonly` in CI, `api_key` for match).
> 4. Re-evaluate the Telegram fork plugin — pin a maintained version or replace
>    the notification mechanism.
> 5. Align with the CI direction: the lanes should be runnable from **GitHub
>    Actions** (see PR #4's CI sub-task) using secrets, not a local `.env`.
> 6. Coordinate the **bitcode** change with the separate bitcode-removal ticket
>    (that ticket owns `include_bitcode`); do not duplicate it here.
>
> **Acceptance criteria**
> - `bundle exec fastlane` runs on current fastlane with no deprecation errors.
> - No secrets in tracked files; `fastlane/.env` gitignored; `.env.sample` present.
> - Release lane authenticates via App Store Connect API key.
> - `fastlane/README.md` and root `Readme.md` tooling section updated.
>
> **Overlap note:** overlaps PR #4 sub-task D; per decision PR #4 stays as-is and
> this ticket is the source of truth for the fastlane upgrade.

## Implementation

- Fastlane was upgraded and the obsolete bitcode option was removed.
- TestFlight and `match` now authenticate with an App Store Connect API key.
- The tracked `.env`, Telegram plugin, and hardcoded proxy credentials were
  removed; `fastlane/.env.example` documents the required variable names.
- GitHub Actions CI and the Fastlane/root documentation were added or refreshed.
- The exposed Telegram token must still be considered compromised; rotation and
  any repository-history rewrite are external follow-up actions and cannot be
  verified from this repository.
