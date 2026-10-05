import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "visual_evidence", Path(__file__).resolve().parents[1] / "pr-visual-evidence.py",
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="growingup-publication-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.metadata = dict(
            head_sha="current-head", run_id="123", run_attempt="2",
            journey_outcome="success", export_outcome="success",
            device="iPhone-17-Pro", runtime="26-5", xcode="26.6",
        )
        self.image = self.directory / "checkpoint.png"
        self.image.write_bytes(b"simulator screenshot")
        (self.directory / "demo.mp4").write_bytes(b"trimmed simulator recording")
        self.pr = dict(
            state="open", head={"sha": "current-head"}, body="Original description\n",
            html_url="https://github.com/owner/repo/pull/42",
        )
        self.run = dict(
            status="completed", conclusion="success", run_attempt=2,
            html_url="https://github.com/owner/repo/actions/runs/123",
        )
        self.edits = []

    def gh(self, *args):
        if args == ("pr", "edit", "--help"):
            return "--attach"
        if args[:2] == ("repo", "view"):
            return "owner/repo"
        if args[:2] == ("run", "list"):
            return json.dumps([{"databaseId": 123}])
        if args == ("api", "repos/owner/repo/pulls/42"):
            return json.dumps(self.pr)
        if args == ("api", "repos/owner/repo/actions/runs/123"):
            return json.dumps(self.run)
        self.fail(f"Unexpected gh call: {args}")

    def edit(self, args, **kwargs):
        self.edits.append(args)
        self.assertIn("--repo", args)
        self.assertIn("owner/repo", args)
        body = Path(args[args.index("--body-file") + 1]).read_text()
        for index, argument in enumerate(args):
            if argument == "--attach":
                path = args[index + 1]
                body = body.replace(path, "https://github.com/user-attachments/assets/" + Path(path).name)
        self.pr["body"] = body
        return subprocess.CompletedProcess(args, 0)

    def publish(self):
        (self.directory / "metadata.json").write_text(json.dumps(self.metadata))
        with patch.object(MODULE, "gh", side_effect=self.gh), patch.object(
            MODULE.subprocess, "run", side_effect=self.edit,
        ):
            MODULE.publish(42, self.directory, "Inspected the save and relaunch journey.", ["checkpoint.png"], ["demo.mp4"])

    def test_publication_embeds_media_and_preserves_other_sections_on_repeat(self):
        self.pr["body"] = f"Original\n\n{MODULE.START}\nOld evidence\n{MODULE.END}\n\nReviewer notes\n"
        self.publish()
        self.publish()
        body = self.pr["body"]
        self.assertTrue(body.startswith("Original\n\n"))
        self.assertTrue(body.endswith("\n\nReviewer notes\n"))
        self.assertEqual(body.count(MODULE.START), 1)
        self.assertNotIn("Old evidence", body)
        self.assertIn("current-head", body)
        self.assertIn(self.run["html_url"], body)
        self.assertIn("user-attachments/assets/checkpoint.png", body)
        self.assertIn("user-attachments/assets/demo.mp4", body)
        self.assertNotIn(self.temporary.name, body)

    def test_stale_head_or_attempt_never_uploads(self):
        for field, value in [("head_sha", "old-head"), ("run_attempt", "1"), ("run_id", "122")]:
            with self.subTest(field=field):
                original = self.metadata[field]
                self.metadata[field] = value
                with self.assertRaises(ValueError):
                    self.publish()
                self.metadata[field] = original
        self.assertEqual(self.edits, [])

    def test_failed_ci_or_export_never_uploads(self):
        self.run["conclusion"] = "failure"
        with self.assertRaises(ValueError):
            self.publish()
        self.run["conclusion"] = "success"
        self.metadata["export_outcome"] = "failure"
        with self.assertRaises(ValueError):
            self.publish()
        self.assertEqual(self.edits, [])

    def test_concurrent_body_edit_is_preserved(self):
        original = self.gh
        reads = 0

        def changed(*args):
            nonlocal reads
            if args == ("api", "repos/owner/repo/pulls/42"):
                reads += 1
                if reads == 2:
                    self.pr["body"] = "Danis added review notes"
            return original(*args)

        self.gh = changed
        with self.assertRaisesRegex(ValueError, "PR changed"):
            self.publish()
        self.assertEqual(self.pr["body"], "Danis added review notes")
        self.assertEqual(self.edits, [])

    def test_partial_upload_failure_is_reported_without_retry(self):
        def partial(args, **kwargs):
            self.edits.append(args)
            self.pr["body"] = "Partially uploaded"
            raise subprocess.CalledProcessError(1, args)

        self.edit = partial
        with self.assertRaises(subprocess.CalledProcessError):
            self.publish()
        self.assertEqual(len(self.edits), 1)

    def test_missing_published_section_is_not_reported_as_success(self):
        def missing(args, **kwargs):
            self.pr["body"] = "Another writer replaced the evidence"
            return subprocess.CompletedProcess(args, 0)

        self.edit = missing
        with self.assertRaisesRegex(ValueError, "media references"):
            self.publish()

    def test_media_rejects_external_files_and_oversize_uploads(self):
        with tempfile.TemporaryDirectory(prefix="growingup-external-") as other:
            external = Path(other) / "image.png"
            external.write_bytes(b"image")
            with self.assertRaises(ValueError):
                MODULE.media_file(self.directory, str(external), ".png")
        with self.image.open("wb") as image:
            image.truncate(MODULE.MAX_BYTES + 1)
        with self.assertRaises(ValueError):
            self.publish()
        self.assertEqual(self.edits, [])

    def test_malformed_markers_do_not_destroy_body(self):
        for body in [MODULE.START, MODULE.END, MODULE.END + MODULE.START, MODULE.START * 2 + MODULE.END]:
            with self.subTest(body=body), self.assertRaises(ValueError):
                MODULE.section(body, "replacement")


if __name__ == "__main__":
    unittest.main()
