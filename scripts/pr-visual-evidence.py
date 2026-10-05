#!/usr/bin/env python3
"""Attach agent-reviewed simulator evidence to the current PR description."""

import argparse
import json
import subprocess
import tempfile
from pathlib import Path


START = "<!-- visual-evidence:start -->"
END = "<!-- visual-evidence:end -->"
MAX_BYTES = 10 * 1024 * 1024


def gh(*arguments):
    return subprocess.check_output(["gh", *arguments], text=True)


def section(body, evidence):
    if START not in body and END not in body:
        return body.rstrip() + "\n\n" + evidence + "\n"
    if body.count(START) != 1 or body.count(END) != 1:
        raise ValueError("PR description has invalid visual evidence markers.")
    before, _, remaining = body.partition(START)
    _, separator, after = remaining.partition(END)
    if not separator or END in before:
        raise ValueError("PR description has invalid visual evidence markers.")
    return before + evidence + after


def media_file(directory, relative, suffix):
    path = (directory / relative).resolve()
    if not path.is_relative_to(directory) or path.suffix.lower() != suffix:
        raise ValueError(f"Expected a {suffix} file inside the evidence directory: {relative}")
    if not path.is_file() or not 0 < path.stat().st_size <= MAX_BYTES:
        raise ValueError(f"Media must be nonempty and at most 10 MiB: {relative}")
    if any(character in str(path) for character in "\n\r#()<>"):
        raise ValueError(f"Rename the media file without Markdown delimiters: {relative}")
    return path


def publish(number, directory, summary, images, videos):
    directory = directory.resolve()
    metadata = json.loads((directory / "metadata.json").read_text())
    if metadata.get("journey_outcome") != "success" or metadata.get("export_outcome") != "success":
        raise ValueError("Only successful, exported UI journeys can be published as acceptance evidence.")
    if not summary.strip():
        raise ValueError("Describe the behavior inspected and any limits in the summary file.")
    media = [media_file(directory, name, ".png") for name in images]
    media += [media_file(directory, name, ".mp4") for name in videos]
    if not 1 <= len(media) <= 50 or len(set(media)) != len(media):
        raise ValueError("Select 1–50 distinct screenshots or short videos.")
    if "--attach" not in gh("pr", "edit", "--help"):
        raise ValueError("Update GitHub CLI to 2.99.0 or newer for native --attach support.")

    repo = gh("repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner").strip()
    endpoint = f"repos/{repo}/pulls/{number}"
    pr = json.loads(gh("api", endpoint))
    sha = pr["head"]["sha"]
    if pr["state"] != "open" or metadata["head_sha"] != sha:
        raise ValueError("Evidence does not match the open PR's current head; retrieve fresh evidence.")
    runs = json.loads(gh(
        "run", "list", "--repo", repo, "--workflow", "ci.yml", "--event", "pull_request",
        "--commit", sha, "--limit", "1", "--json", "databaseId",
    ))
    if not runs or str(runs[0]["databaseId"]) != str(metadata["run_id"]):
        raise ValueError("Evidence is not from the latest PR CI run.")
    run = json.loads(gh("api", f"repos/{repo}/actions/runs/{metadata['run_id']}"))
    if (run["status"] != "completed" or run["conclusion"] != "success"
            or str(run["run_attempt"]) != str(metadata["run_attempt"])):
        raise ValueError("The latest CI attempt must pass and match the downloaded evidence.")

    evidence = (
        f"{START}\n## Visual acceptance\n\n"
        f"Reviewed commit: `{sha}` · [CI run]({run['html_url']}) · attempt {run['run_attempt']}\n\n"
        f"{metadata['device']} / iOS {metadata['runtime']} / Xcode {metadata['xcode']}\n\n"
        f"{summary.strip()}\n\n"
    )
    for path in media:
        label = "" if path.suffix.lower() == ".mp4" else "Simulator checkpoint"
        evidence += f"![{label}](<{path}>)\n\n"
    evidence += "TestFlight deployment awaits Danis's explicit approval.\n" + END
    body = section(pr["body"] or "", evidence)

    current = json.loads(gh("api", endpoint))
    if current["head"]["sha"] != sha or current["body"] != pr["body"]:
        raise ValueError("PR changed before publication; rerun to preserve the current description.")
    with tempfile.TemporaryDirectory(prefix="growingup-pr-body-") as temporary:
        body_file = Path(temporary) / "body.md"
        body_file.write_text(body)
        arguments = ["pr", "edit", str(number), "--repo", repo, "--body-file", str(body_file)]
        for path in media:
            arguments += ["--attach", str(path)]
        # gh can update the body even after a partial upload; inspect it before retrying a failure.
        subprocess.run(["gh", *arguments], check=True)
    updated = json.loads(gh("api", endpoint))
    if updated["head"]["sha"] != sha:
        raise ValueError("PR head changed during upload; the published evidence is stale. Retrieve fresh evidence.")
    published = (updated["body"] or "").partition(START)[2].partition(END)[0]
    if (f"Reviewed commit: `{sha}`" not in published
            or published.count("https://github.com/user-attachments/assets/") < len(media)
            or any(str(path) in updated["body"] for path in media)):
        raise ValueError("Some media references were not uploaded; inspect the PR before retrying.")
    print(f"Visual evidence published: {updated['html_url']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pr", type=int)
    parser.add_argument("directory", type=Path, help="one ui-* artifact directory with metadata.json")
    parser.add_argument("--summary-file", type=Path, required=True, help="agent's visual review in Markdown")
    parser.add_argument("--image", action="append", default=[], help="PNG path relative to the artifact directory")
    parser.add_argument("--video", action="append", default=[], help="short MP4 path relative to the artifact directory")
    args = parser.parse_args()
    try:
        publish(args.pr, args.directory, args.summary_file.read_text(), args.image, args.video)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
