import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
STUB = '''#!/usr/bin/env python3
import os
import signal
import sys
import time
from pathlib import Path

directory = Path(os.environ["ARTIFACT_DIR"])
if Path(sys.argv[0]).name == "xcodebuild":
    if sys.argv[1] == "build-for-testing":
        sys.exit(int(os.environ.get("MOCK_BUILD_STATUS", "0")))
    if not (directory / "recording-started").exists():
        sys.exit(99)
    sys.exit(int(os.environ.get("MOCK_TEST_STATUS", "0")))
else:
    if os.environ.get("MOCK_RECORD_STATUS") == "1":
        sys.exit(1)
    def finish(signum, frame):
        Path(sys.argv[-1]).write_bytes(b"finalized-mp4")
        sys.exit(0)
    signal.signal(signal.SIGINT, finish)
    time.sleep(0.1)
    (directory / "recording-started").touch()
    print("Recording started", flush=True)
    while True:
        time.sleep(0.01)
'''

GH_STUB = '''#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

arguments = sys.argv[1:]
if arguments[:2] == ["api", "repos/{owner}/{repo}"]:
    print("owner/repository")
elif arguments[:2] == ["api", "repos/owner/repository/pulls/42"]:
    if arguments[-1] == ".head.sha":
        print("new-head" if os.environ.get("MOCK_STALE") == "1" else "abc123")
    else:
        print(json.dumps({"number": 42, "head": {"sha": "abc123"}}))
elif arguments[:2] == ["run", "list"]:
    print(json.dumps([{"databaseId": 123, "url": "https://example.com/run/123"}]))
elif arguments[:2] == ["run", "watch"]:
    sys.exit(int(os.environ.get("MOCK_CI_STATUS", "0")))
elif arguments[:2] == ["run", "download"]:
    directory = Path(arguments[arguments.index("--dir") + 1]) / "ui-device-runtime"
    directory.mkdir()
    (directory / "metadata.json").write_text(json.dumps({
        "head_sha": os.environ.get("MOCK_METADATA_SHA", "abc123"), "run_id": "123",
    }))
    (directory / "index.html").write_text("report")
else:
    sys.exit(99)
'''


class EvidenceTests(unittest.TestCase):
    def run_pr_evidence(self, directory, stale=False, ci_status=0, metadata_sha="abc123"):
        gh = directory / "gh"
        gh.write_text(GH_STUB)
        gh.chmod(0o755)
        return subprocess.run(
            ["bash", str(SCRIPTS / "pr-evidence.sh"), "42"],
            env=dict(
                os.environ,
                PATH=f"{directory}:{os.environ['PATH']}",
                TMPDIR=str(directory),
                MOCK_STALE="1" if stale else "0",
                MOCK_CI_STATUS=str(ci_status),
                MOCK_METADATA_SHA=metadata_sha,
            ),
            capture_output=True, timeout=10,
        )

    def test_stale_pr_head_rejects_evidence(self):
        with tempfile.TemporaryDirectory(prefix="growingup-pr-test-") as temporary:
            directory = Path(temporary)
            result = self.run_pr_evidence(directory, stale=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"PR head changed", result.stderr)
            self.assertEqual(list(directory.glob("growingup-pr-*")), [])

    def test_failed_ci_still_downloads_evidence_and_returns_failure(self):
        with tempfile.TemporaryDirectory(prefix="growingup-pr-test-") as temporary:
            directory = Path(temporary)
            result = self.run_pr_evidence(directory, ci_status=1)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn(b"Report:", result.stdout)
            self.assertEqual(len(list(directory.glob("growingup-pr-*/ui-*/index.html"))), 1)

    def test_rejected_artifact_is_removed(self):
        with tempfile.TemporaryDirectory(prefix="growingup-pr-test-") as temporary:
            directory = Path(temporary)
            result = self.run_pr_evidence(directory, metadata_sha="wrong-commit")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(directory.glob("growingup-pr-*")), [])

    def run_journeys(self, build_status=0, test_status=0, record_status=0):
        with tempfile.TemporaryDirectory(prefix="growingup-evidence-test-") as temporary:
            directory = Path(temporary)
            for command in ["xcodebuild", "xcrun"]:
                path = directory / command
                path.write_text(STUB)
                path.chmod(0o755)
            environment = dict(
                os.environ,
                PATH=f"{directory}:{os.environ['PATH']}",
                ARTIFACT_DIR=str(directory),
                SIM_UDID="existing-simulator",
                GROWINGUP_VISUAL_CHECKS="1",
                MOCK_BUILD_STATUS=str(build_status),
                MOCK_TEST_STATUS=str(test_status),
                MOCK_RECORD_STATUS=str(record_status),
            )
            result = subprocess.run(
                ["bash", str(SCRIPTS / "run-ui-journeys.sh")],
                env=environment, capture_output=True, timeout=10,
            )
            video = directory / "journeys.mp4"
            return result.returncode, video.read_bytes() if video.exists() else None

    def test_success_finalizes_video(self):
        self.assertEqual(self.run_journeys(), (0, b"finalized-mp4"))

    def test_failed_journey_finalizes_video_and_preserves_failure(self):
        self.assertEqual(self.run_journeys(test_status=65), (65, b"finalized-mp4"))

    def test_failed_build_does_not_record(self):
        self.assertEqual(self.run_journeys(build_status=65), (65, None))

    def test_failed_recorder_does_not_start_journeys(self):
        self.assertEqual(self.run_journeys(record_status=1), (1, None))

    def test_report_links_exported_images_and_escapes_labels(self):
        with tempfile.TemporaryDirectory(prefix="growingup-report-test-") as temporary:
            directory = Path(temporary)
            (directory / "metadata.json").write_text(json.dumps({"head_sha": "abc123"}))
            (directory / "test-summary.json").write_text(json.dumps({"passedTests": 6}))
            (directory / "journeys.mp4").touch()
            attachments = directory / "attachments"
            attachments.mkdir()
            (attachments / "image with spaces.png").touch()
            (attachments / "manifest.json").write_text(json.dumps([{
                "attachments": [{
                    "exportedFileName": "image with spaces.png",
                    "suggestedHumanReadableName": '<photo & "crop">',
                }],
            }]))
            subprocess.run(
                ["python3", str(SCRIPTS / "ui-evidence-report.py"), str(directory)], check=True,
            )
            report = (directory / "index.html").read_text()
            self.assertIn("abc123", report)
            self.assertIn("attachments/image%20with%20spaces.png", report)
            self.assertIn("&lt;photo &amp; &quot;crop&quot;&gt;", report)
            self.assertNotIn('<photo & "crop">', report)
            self.assertIn('src="journeys.mp4"', report)


if __name__ == "__main__":
    unittest.main()
