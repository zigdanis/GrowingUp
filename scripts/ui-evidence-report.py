#!/usr/bin/env python3
"""Render exported Xcode evidence as a portable, offline HTML report."""

import html
import json
import sys
from pathlib import Path
from urllib.parse import quote


def render(directory):
    metadata = json.loads((directory / "metadata.json").read_text())
    summary_path = directory / "test-summary.json"
    summary = json.loads(summary_path.read_text()) if summary_path.exists() else None
    attachments = directory / "attachments"
    names = {}
    manifest = attachments / "manifest.json"
    if manifest.exists():
        for test in json.loads(manifest.read_text()):
            for attachment in test["attachments"]:
                names[attachment["exportedFileName"]] = attachment["suggestedHumanReadableName"]

    def link(path):
        return quote(path.relative_to(directory).as_posix())

    parts = [
        '<!doctype html><html lang="en"><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        '<title>GrowingUp simulator evidence</title>',
        '<style>body{font:16px/1.5 system-ui;margin:24px auto;max-width:1100px;padding:0 16px}',
        'pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f2f2f2;padding:16px}',
        '.images{display:flex;flex-wrap:wrap;gap:24px}figure{margin:0;width:320px}',
        'img,video{max-width:100%;max-height:720px}figcaption{overflow-wrap:anywhere}</style>',
        '<h1>GrowingUp simulator evidence</h1>',
        '<p>Automated assertions and visual comparisons report their own results below. '
        'Inspect the screenshots and recording before accepting the change.</p>',
        '<h2>Source and environment</h2>',
        f'<pre>{html.escape(json.dumps(metadata, indent=2))}</pre>',
        '<h2>Test results</h2>',
        f'<pre>{html.escape(json.dumps(summary, indent=2)) if summary else "No test summary exported; inspect the logs."}</pre>',
    ]
    video = directory / "journeys.mp4"
    if video.exists():
        parts += ['<h2>Journey recording</h2>', f'<video controls preload="metadata" src="{link(video)}"></video>']
    parts += ['<h2>Screenshots and visual differences</h2><div class="images">']
    images = sorted(attachments.glob("*.png"))
    for path in images:
        label = html.escape(names.get(path.name, path.name))
        parts.append(
            f'<figure><a href="{link(path)}"><img loading="lazy" src="{link(path)}" alt="{label}"></a>'
            f'<figcaption>{label}</figcaption></figure>'
        )
    if not images:
        parts.append('<p>No screenshots exported; inspect the logs.</p>')
    parts += ['</div><h2>Raw evidence</h2><ul>']
    for path in sorted(directory.iterdir()):
        if path.is_file() and path.name != "index.html":
            parts.append(f'<li><a href="{link(path)}">{html.escape(path.name)}</a></li>')
    if manifest.exists():
        parts.append(f'<li><a href="{link(manifest)}">Attachment manifest (test-to-image mapping)</a></li>')
    parts.append('</ul></html>')
    (directory / "index.html").write_text("\n".join(parts))


if __name__ == "__main__":
    render(Path(sys.argv[1]))
