#!/usr/bin/env python3
"""Skip iOS checks only for changes confined to known standalone tooling and docs."""

import argparse
from pathlib import PurePosixPath
import re
import subprocess


NON_IOS_FILES = {
    "AGENTS.md", "CLAUDE.md", "README.md",
    "scripts/app-store-metadata.py", "scripts/tests/test_app_store_metadata.py",
}


def non_ios_file(path):
    file = PurePosixPath(path)
    if path in NON_IOS_FILES:
        return True
    if path.startswith("docs/"):
        return file.suffix in {".md", ".html"} or (path.startswith("docs/releases/") and file.suffix == ".json")
    if path.startswith("marketing/app-store/screenshots/"):
        return file.suffix == ".png" or path == "marketing/app-store/screenshots/source.json"
    return False


def ios_required(event, base, head):
    if event not in {"pull_request", "push"} or not all(re.fullmatch(r"[0-9a-f]{40}", sha) for sha in (base, head)):
        return True
    if base == "0" * 40:
        return True
    revisions = [f"{base}...{head}"] if event == "pull_request" else [base, head]
    try:
        # Both sides of a rename must be checked, including deleted app inputs.
        result = subprocess.run(["git", "diff", "--name-only", "--no-renames", "-z", *revisions, "--"],
                                check=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        files = result.stdout.decode("utf-8").rstrip("\0").split("\0")
    except (OSError, subprocess.CalledProcessError, UnicodeDecodeError):
        return True
    return not all(non_ios_file(path) for path in files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event", required=True)
    parser.add_argument("--base", default="")
    parser.add_argument("--head", default="")
    args = parser.parse_args()
    print(f"ios_required={str(ios_required(args.event, args.base, args.head)).lower()}")


if __name__ == "__main__":
    main()
