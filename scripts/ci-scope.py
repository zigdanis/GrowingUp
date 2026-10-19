#!/usr/bin/env python3
"""Skip iOS checks only for changes confined to known standalone tooling and docs.

PRs run simulator UI journeys only when they touch what the journeys exercise.
Pushes to master, manual runs and anything unreadable run them in full.
"""

import argparse
from pathlib import PurePosixPath
import re
import subprocess


NON_IOS_FILES = {
    "AGENTS.md", "CLAUDE.md", "README.md", ".coderabbit.yaml",
    "scripts/app-store-metadata.py", "scripts/tests/test_app_store_metadata.py",
}


UI_INPUTS = ("GrowingUp/", "Core/", "Widget/", "GrowingUpUITests/", "GrowingUp.xcodeproj/",
             "scripts/run-ui-journeys.sh", "scripts/ui-evidence-report.py")


def non_ios_file(path):
    file = PurePosixPath(path)
    if path in NON_IOS_FILES:
        return True
    if path.startswith((".agents/", ".macroscope/")):
        return file.suffix in {".md", ".yaml"}
    if path.startswith("docs/"):
        return file.suffix in {".md", ".html"} or (path.startswith("docs/releases/") and file.suffix == ".json")
    if path.startswith("marketing/app-store/screenshots/"):
        return file.suffix == ".png" or path == "marketing/app-store/screenshots/source.json"
    return False


def changed_files(event, base, head):
    """Return the changed paths, or None when the change set cannot be trusted."""
    if event not in {"pull_request", "push"} or not all(re.fullmatch(r"[0-9a-f]{40}", sha) for sha in (base, head)):
        return None
    if base == "0" * 40:
        return None
    revisions = [f"{base}...{head}"] if event == "pull_request" else [base, head]
    try:
        # Both sides of a rename must be checked, including deleted app inputs.
        result = subprocess.run(["git", "diff", "--name-only", "--no-renames", "-z", *revisions, "--"],
                                check=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        return result.stdout.decode("utf-8").rstrip("\0").split("\0")
    except (OSError, subprocess.CalledProcessError, UnicodeDecodeError):
        return None


def ios_required(files):
    return files is None or not all(non_ios_file(path) for path in files)


def ui_required(event, files):
    if not ios_required(files):
        return False
    if files is None or event != "pull_request":
        return True
    return any(path.startswith(UI_INPUTS) for path in files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event", required=True)
    parser.add_argument("--base", default="")
    parser.add_argument("--head", default="")
    args = parser.parse_args()
    files = changed_files(args.event, args.base, args.head)
    print(f"ios_required={str(ios_required(files)).lower()}")
    print(f"ui_required={str(ui_required(args.event, files)).lower()}")


if __name__ == "__main__":
    main()
