# Add automated Swift formatting

## Summary

GrowingUp already runs SwiftLint during local Xcode builds and in GitHub Actions, but it does not currently use a source-code formatter. Add the official `swift-format` tool so formatting is consistent locally and enforced in CI.

This plan was implemented in the repository. The configuration, shared scripts,
formatted baseline, optional hook, and CI gate now form the source of truth.

## Motivation

The project currently relies on editor settings and manual formatting. This allows tabs and spaces, import ordering, trailing commas, line wrapping, and other formatting choices to drift between files and contributors.

A formatter should provide one deterministic style while SwiftLint continues to enforce code-quality rules that require developer judgment.

## Implemented state

- `.swiftlint.yml` defines project lint rules.
- The `GrowingUp` target runs SwiftLint during Xcode builds, including `Cmd+R`.
- GitHub Actions runs `swiftlint lint --strict` for pull requests and pushes to `master`.
- GitHub Actions builds the app and runs tests with `xcodebuild test`.
- `.swift-format` defines the repository formatting policy.
- Shared scripts format, check formatting, and run SwiftLint consistently.
- CI enforces formatting without modifying source files.
- An optional repository-controlled pre-commit hook checks formatting and lint.
- The `xcbeautify` command used by CI formats build output only; it does not format Swift source code.

## Proposed tool

Use the official `swift-format` executable bundled with the active Xcode Swift toolchain:

```bash
xcrun swift-format
```

Prefer the Xcode-bundled executable over a separately installed formatter so local development and CI can select the formatter through their active Xcode version.

Pin the Xcode version used by CI, or otherwise verify formatter version compatibility. Formatting output can change between toolchain releases.

## Desired developer workflow

### While editing

Provide an optional Xcode Source Editor Extension or documented Xcode command for formatting the current file. If reliable format-on-save integration is selected, it should use the repository configuration.

Formatting on save is a developer convenience, not the enforcement boundary.

### During Xcode builds

Keep the existing SwiftLint build phase.

Do not run `swift-format format --in-place` from a build phase. Building or launching the app must not silently modify tracked source files.

A formatter check during every build is optional. Prefer fast local feedback without making `Cmd+R` unnecessarily slow.

### Before commit

Provide a shared, opt-in Git hook installation script. The pre-commit hook should:

1. Check formatting.
2. Run SwiftLint.
3. Block the commit when either check fails.
4. Print the command needed to fix formatting.

Do not run the complete simulator test suite in pre-commit. Tests remain available through `Cmd+U` and mandatory in CI.

Git hooks are only a convenience because contributors can bypass them with `--no-verify`.

### In CI

CI is the enforcement boundary. Pull requests and pushes to `master` should run:

```text
scripts/check-formatting.sh
swiftlint lint --strict
xcodebuild test
```

The formatter check must not rewrite files in CI. It should fail and show actionable diagnostics when committed code is not formatted.

Do not invoke `swift-format lint --strict` without paths: with no paths, the
tool reads standard input instead of checking the repository.

## Implementation plan

### 1. Define formatting policy

Create a repository-level `.swift-format` configuration. Decide and document at least:

- tabs versus spaces and indentation width;
- maximum line length;
- import ordering;
- trailing commas in multiline collections and argument lists;
- preservation of existing line breaks;
- formatting rules that overlap with SwiftLint;
- source directories and generated-code exclusions.

Align overlapping `.swift-format` and `.swiftlint.yml` rules so tools do not disagree.

### 2. Add project scripts

Add stable wrapper scripts so developers and CI use identical commands. Suggested interface:

```bash
scripts/format-swift.sh        # Rewrite project Swift files
scripts/check-formatting.sh    # Check only; never rewrite files
scripts/lint-swift.sh          # Run SwiftLint with project rules
scripts/install-git-hooks.sh   # Opt in to repository hooks
```

Scripts should target application, widget, core, and test source directories explicitly. They should exclude build output, dependency checkouts, generated files, and agent/plugin assets.

The shared formatting scripts should pass the repository configuration and the
same explicit first-party paths to `swift-format`, for example:

```bash
xcrun swift-format lint --strict --recursive --parallel \
  Core GrowingUp GrowingUpTests Widget
```

Scripts should fail with a clear installation or Xcode-selection message when a required executable is unavailable.

### 3. Establish formatted baseline

Run the formatter once across all project Swift sources:

```bash
scripts/format-swift.sh
```

Submit this baseline as a dedicated formatting-only commit. Avoid mixing behavior changes with the large mechanical diff.

Review representative files and confirm that no generated or third-party sources were changed.

### 4. Validate baseline

After the initial formatting pass, run:

```bash
scripts/check-formatting.sh
scripts/lint-swift.sh
xcodebuild test \
  -project GrowingUp.xcodeproj \
  -scheme GrowingUp \
  -destination '<available iOS Simulator>'
```

Resolve formatter and SwiftLint conflicts before enabling CI enforcement.

### 5. Add pre-commit support

Commit a shared hook under a repository-controlled directory such as `.githooks/pre-commit`. Add an installation script that configures:

```bash
git config core.hooksPath .githooks
```

Document that hook installation is optional and local to each clone.

Prefer checking only staged Swift files if implementation remains reliable. Fall back to a fast project-wide check if staged-file handling becomes fragile.

### 6. Add CI formatter gate

Add a formatter job or step to `.github/workflows/ci.yml`. It should:

1. Select the intended Xcode version.
2. Print `xcrun swift-format --version` for diagnostics.
3. Run the repository check script.
4. Fail on any formatting difference.

Keep SwiftLint and tests as separate checks so pull requests clearly show which gate failed.

### 7. Document Xcode integration

Document one supported way to format the current file from Xcode. Include setup steps, command location, and how it discovers `.swift-format`.

If format-on-save requires a third-party extension, keep it optional. Repository scripts and CI must work without the extension.

## Rollout strategy

Use separate commits or pull requests:

1. Add configuration and scripts without enabling CI enforcement.
2. Apply repository-wide formatting baseline.
3. Confirm lint, build, and tests pass.
4. Enable pre-commit support and CI formatter gate.
5. Document optional Xcode format-on-save workflow.

This order avoids introducing a permanently failing CI check before the existing source tree matches the chosen format.

## Acceptance criteria

- Repository contains reviewed `.swift-format` configuration.
- One documented command formats all first-party Swift source files.
- One documented command checks formatting without modifying files.
- Formatter and SwiftLint rules do not conflict.
- Existing SwiftLint Xcode build phase still works.
- Optional pre-commit hook checks formatting and linting.
- CI rejects unformatted Swift code.
- CI still runs SwiftLint and complete tests.
- Building or running the app never rewrites tracked source files.
- Generated files, dependencies, build output, and plugin assets are excluded.
- Clean checkout passes formatting, lint, build, and test checks.

## Non-goals

- Do not replace SwiftLint with a formatter.
- Do not run tests on every save or commit.
- Do not mutate source files during Xcode builds or CI.
- Do not combine the initial formatting diff with functional changes.
- Do not require every contributor to install an Xcode editor extension.

## Decisions

- Use two spaces for indentation.
- Use the same 160-column limit in swift-format and SwiftLint.
- Enable import ordering.
- Check formatting in CI and the optional pre-commit hook, not during Xcode builds.
- Use the `swift-format` bundled with the selected Xcode toolchain; CI's
  `/Applications/Xcode.app` is canonical and prints the formatter version.
- Check all first-party source directories in pre-commit for simple, reliable
  behavior.
