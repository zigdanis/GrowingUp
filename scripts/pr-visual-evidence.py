#!/usr/bin/env python3
"""Attach agent-reviewed simulator evidence to the current PR description."""

import argparse
import json
import re
import shutil
import subprocess
import tempfile
from fractions import Fraction
from pathlib import Path
from urllib.parse import urlencode


START = "<!-- visual-evidence:start -->"
END = "<!-- visual-evidence:end -->"
MAX_BYTES = 10 * 1024 * 1024
MAX_WIDTH = 320
MAX_HEIGHT = 640


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
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"Media must be a nonempty file: {relative}")
    with path.open("rb") as stream:
        header = stream.read(12)
    if suffix == ".png" and not header.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Screenshot is not a PNG file")
    if suffix == ".mp4" and header[4:8] != b"ftyp":
        raise ValueError("Recording is not an MP4 file")
    return path


def compact_media(directory, images, videos, temporary):
    sources = ([media_file(directory, name, ".png") for name in images]
               + [media_file(directory, name, ".mp4") for name in videos])
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise ValueError("ffmpeg is required to create compact PR evidence; install it with `brew install ffmpeg` or `sudo apt install ffmpeg`.")
    ffprobe = shutil.which("ffprobe") if videos else None
    if videos and not ffprobe:
        raise ValueError("ffprobe is required for video timing; install the ffmpeg package with `brew install ffmpeg` or `sudo apt install ffmpeg`.")

    compacted = []
    for index, source in enumerate(sources):
        output_directory = temporary / f"{index:02d}"
        output_directory.mkdir()
        output = output_directory / source.name
        if source.suffix.lower() == ".png":
            command = [ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
                       "-i", str(source), "-frames:v", "1", "-vf",
                       f"scale=w='min({MAX_WIDTH},iw)':h='min({MAX_HEIGHT},ih)':force_original_aspect_ratio=decrease",
                       "-compression_level", "9", str(output)]
        else:
            # Passthrough preserves PTS; the final source packet fixes the encoder's trailing frame duration.
            timing = json.loads(subprocess.check_output([
                ffprobe, "-v", "error", "-select_streams", "v:0", "-show_entries",
                "stream=time_base:packet=pts,duration", "-show_packets", "-show_streams", "-of", "json", str(source),
            ], text=True))
            packets = timing.get("packets", [])
            if not packets or not timing.get("streams"):
                raise ValueError(f"Recording has no video timing: {source.name}")
            # Packet order follows decoding, so select the last presented frame even with B-frames.
            final_packet = max(packets, key=lambda packet: int(packet["pts"]))
            duration = Fraction(timing["streams"][0]["time_base"]) * int(final_packet.get("duration", 0))
            if duration <= 0:
                raise ValueError(f"Recording has no final frame duration: {source.name}")
            command = [ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
                       "-i", str(source), "-map", "0:v:0", "-map", "0:a?", "-vf",
                       f"scale=w='min({MAX_WIDTH},iw)':h='min({MAX_HEIGHT},ih)':force_original_aspect_ratio=decrease:force_divisible_by=2",
                       "-c:v", "libx264", "-preset", "veryfast", "-crf", "28", "-pix_fmt", "yuv420p",
                       "-c:a", "aac", "-b:a", "96k",
                       "-fps_mode", "passthrough", "-enc_time_base", "-1", "-r", str(1 / duration),
                       "-movflags", "+faststart", str(output)]
        try:
            subprocess.run(command, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as error:
            detail = error.stderr.strip() or "unknown conversion error"
            raise ValueError(f"Could not create compact evidence for {source.name}: {detail}") from error
        media_file(output_directory, output.name, source.suffix.lower())
        if output.stat().st_size > MAX_BYTES:
            raise ValueError(f"Compact media must be at most 10 MiB: {source.name}")
        compacted.append(output)
    return compacted


def image_label(path):
    label = " ".join(word.capitalize() for word in re.findall(r"[A-Za-z0-9]+", path.stem))
    return label or "Screenshot"


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
    sources = [media_file(directory, name, ".png") for name in images]
    sources += [media_file(directory, name, ".mp4") for name in videos]
    if not 1 <= len(sources) <= 50 or len(set(sources)) != len(sources):
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

    # Derive and validate every attachment before uploading; remove temporary copies on every exit.
    with tempfile.TemporaryDirectory(prefix="growingup-compact-evidence-") as temporary_directory:
        media = compact_media(directory, images, videos, Path(temporary_directory))

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
    image_attachments = [(path, url) for path, url in attachments if path.suffix.lower() == ".png"]
    for index in range(0, len(image_attachments), 2):
        row = image_attachments[index:index + 2]
        evidence += " ".join(f"![{image_label(path)}]({url})" for path, url in row) + "\n\n"
    for path, url in attachments:
        if path.suffix.lower() == ".mp4":
            evidence += url + "\n\n"
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
