#!/usr/bin/env python3
"""Attach agent-reviewed simulator evidence to the current PR description."""

import argparse
import json
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlencode


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
    return path


def checked_run(repo, sha, metadata):
    workflow = metadata.get("workflow", "ci.yml")
    if workflow not in ("ci.yml", "app-store-screenshots.yml"):
        raise ValueError("Evidence must come from CI or App Store Screenshots.")
    runs = json.loads(gh(
        "run", "list", "--repo", repo, "--workflow", workflow, "--event", "pull_request",
        "--commit", sha, "--limit", "1", "--json", "databaseId",
    ))
    if not runs or str(runs[0]["databaseId"]) != str(metadata["run_id"]):
        raise ValueError("Evidence is not from the latest PR CI run.")
    run = json.loads(gh("api", f"repos/{repo}/actions/runs/{metadata['run_id']}"))
    if (run["status"] != "completed" or run["conclusion"] != "success"
            or str(run["run_attempt"]) != str(metadata["run_attempt"])):
        raise ValueError("The latest CI attempt must pass and match the downloaded evidence.")
    return run


def update_body(endpoint, body):
    with tempfile.TemporaryDirectory(prefix="growingup-pr-body-") as temporary:
        payload = Path(temporary) / "body.json"
        payload.write_text(json.dumps({"body": body}))
        gh("api", endpoint, "--method", "PATCH", "--input", str(payload))


def invalidate(endpoint, evidence):
    current = json.loads(gh("api", endpoint))
    body = current["body"] or ""
    block = START + body.partition(START)[2].partition(END)[0] + END
    # Replace only our exact section, preserving fresh surrounding text and other publishers' evidence.
    if block == evidence:
        pending = f"{START}\n## Visual acceptance\n\nEvidence is stale. Retrieve and review current-head CI before acceptance.\n{END}"
        update_body(endpoint, section(body, pending))


def publish(number, directory, summary, images, videos):
    directory = directory.resolve()
    metadata = json.loads((directory / "metadata.json").read_text())
    workflow = metadata.get("workflow", "ci.yml")
    if workflow == "ci.yml":
        outcomes = ("journey_outcome", "export_outcome")
    elif workflow == "app-store-screenshots.yml":
        outcomes = ("capture_outcome", "export_outcome", "verification_outcome", "composition_outcome")
    else:
        raise ValueError("Evidence must come from CI or App Store Screenshots.")
    if any(metadata.get(outcome) != "success" for outcome in outcomes):
        raise ValueError("Only successful, exported and verified workflow evidence can be published.")
    if not summary.strip():
        raise ValueError("Describe the behavior inspected and any limits in the summary file.")
    if START in summary or END in summary:
        raise ValueError("Summary must not contain visual evidence markers.")
    media = [media_file(directory, name, ".png") for name in images]
    media += [media_file(directory, name, ".mp4") for name in videos]
    if not 1 <= len(media) <= 50 or len(set(media)) != len(media):
        raise ValueError("Select 1–50 distinct screenshots or short videos.")
    repository = json.loads(gh("api", "repos/{owner}/{repo}"))
    repo = repository["full_name"]
    endpoint = f"repos/{repo}/pulls/{number}"
    pr = json.loads(gh("api", endpoint))
    sha = pr["head"]["sha"]
    if pr["state"] != "open" or metadata["head_sha"] != sha:
        raise ValueError("Evidence does not match the open PR's current head; retrieve fresh evidence.")
    checked_run(repo, sha, metadata)
    section(pr["body"] or "", "")  # Reject malformed existing markers before uploading.

    # Same native attachment endpoint used by gh --attach, without editing the PR during uploads.
    attachments = []
    for path in media:
        content_type = "video/mp4" if path.suffix.lower() == ".mp4" else "image/png"
        query = urlencode({"repository_id": repository["id"], "name": path.name, "content_type": content_type})
        asset = json.loads(gh(
            "api", f"https://uploads.github.com/user-attachments/assets?{query}",
            "--method", "POST", "--header", "Content-Type: application/octet-stream", "--input", str(path),
        ))
        url = asset.get("url", "")
        if not url.startswith("https://github.com/user-attachments/assets/"):
            raise ValueError("GitHub did not return a native attachment URL.")
        attachments.append((path, url))

    run = checked_run(repo, sha, metadata)

    evidence = (
        f"{START}\n## Visual acceptance\n\n"
        f"Reviewed commit: `{sha}` · [CI run]({run['html_url']}) · attempt {run['run_attempt']}\n\n"
        f"{metadata['device']} / iOS {metadata['runtime']} / Xcode {metadata['xcode']}\n\n"
        f"{summary.strip()}\n\n"
    )
    for path, url in attachments:
        evidence += url + "\n\n" if path.suffix.lower() == ".mp4" else f"![Simulator checkpoint]({url})\n\n"
    evidence += "TestFlight deployment awaits Danis's explicit approval.\n" + END
    # GitHub does not support conditional PR writes. Re-read after the slow uploads, immediately before PATCH.
    current = json.loads(gh("api", endpoint))
    if current["state"] != "open" or current["head"]["sha"] != sha:
        raise ValueError("PR changed during upload; retrieve fresh evidence before publication.")
    update_body(endpoint, section(current["body"] or "", evidence))
    updated = json.loads(gh("api", endpoint))
    if updated["head"]["sha"] != sha:
        invalidate(endpoint, evidence)
        raise ValueError("PR head changed during publication; retrieve fresh evidence. Inspect the PR before retrying.")
    body = updated["body"] or ""
    if START + body.partition(START)[2].partition(END)[0] + END != evidence:
        raise ValueError("Published evidence was changed; inspect the PR before retrying.")
    print(f"Visual evidence published: {updated['html_url']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pr", type=int)
    parser.add_argument("directory", type=Path,
                        help="one ui-* or app-store-capture-* artifact directory with metadata.json")
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
