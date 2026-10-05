import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlparse
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
        self.uploads = []

    def gh(self, *args):
        if args == ("api", "repos/{owner}/{repo}"):
            return json.dumps({"full_name": "owner/repo", "id": 1234})
        if args[:2] == ("run", "list"):
            return json.dumps([{"databaseId": 123}])
        if args == ("api", "repos/owner/repo/pulls/42"):
            return json.dumps(self.pr)
        if args == ("api", "repos/owner/repo/actions/runs/123"):
            return json.dumps(self.run)
        if args[:2] == ("api", "repos/owner/repo/pulls/42") and "PATCH" in args:
            return self.edit(args)
        if args[0] == "api" and args[1].startswith("https://uploads.github.com/"):
            return self.upload(args)
        self.fail(f"Unexpected gh call: {args}")

    def upload(self, args):
        self.uploads.append(args)
        query = parse_qs(urlparse(args[1]).query)
        self.assertEqual(query["repository_id"], ["1234"])
        self.assertIn(query["content_type"][0], ["image/png", "video/mp4"])
        self.assertTrue(Path(args[args.index("--input") + 1]).is_file())
        return json.dumps({"url": "https://github.com/user-attachments/assets/" + query["name"][0]})

    def edit(self, args):
        self.edits.append(args)
        self.pr["body"] = json.loads(Path(args[args.index("--input") + 1]).read_text())["body"]
        return json.dumps(self.pr)

    def publish(self, summary="Inspected the save and relaunch journey."):
        (self.directory / "metadata.json").write_text(json.dumps(self.metadata))
        with patch.object(MODULE, "gh", side_effect=self.gh):
            MODULE.publish(42, self.directory, summary, ["checkpoint.png"], ["demo.mp4"])

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
        self.assertEqual(self.uploads, [])

    def test_failed_ci_or_export_never_uploads(self):
        self.run["conclusion"] = "failure"
        with self.assertRaises(ValueError):
            self.publish()
        self.run["conclusion"] = "success"
        self.metadata["export_outcome"] = "failure"
        with self.assertRaises(ValueError):
            self.publish()
        self.assertEqual(self.edits, [])
        self.assertEqual(self.uploads, [])

    def test_concurrent_body_edit_is_preserved(self):
        original = self.upload
        def changed(args):
            self.pr["body"] = "Danis added review notes"
            return original(args)

        self.upload = changed
        self.publish()
        self.assertTrue(self.pr["body"].startswith("Danis added review notes"))
        self.assertEqual(len(self.edits), 1)

    def test_partial_upload_failure_is_reported_without_retry(self):
        original = self.upload
        def partial(args):
            if self.uploads:
                raise subprocess.CalledProcessError(1, args)
            return original(args)

        self.upload = partial
        with self.assertRaises(subprocess.CalledProcessError):
            self.publish()
        self.assertEqual(len(self.uploads), 1)
        self.assertEqual(self.edits, [])
        self.assertEqual(self.pr["body"], "Original description\n")

    def test_missing_published_section_is_not_reported_as_success(self):
        def missing(args):
            self.pr["body"] = "Another writer replaced the evidence"
            return json.dumps(self.pr)

        self.edit = missing
        with self.assertRaisesRegex(ValueError, "evidence was changed"):
            self.publish()

    def test_push_during_upload_does_not_publish_stale_media(self):
        original = self.upload
        def pushed(args):
            self.pr["head"]["sha"] = "new-head"
            return original(args)

        self.upload = pushed
        with self.assertRaisesRegex(ValueError, "PR changed during upload"):
            self.publish()
        self.assertEqual(self.edits, [])

    def test_push_during_publication_invalidates_only_our_section(self):
        original = self.edit
        def pushed(args):
            result = original(args)
            if len(self.edits) == 1:
                self.pr["head"]["sha"] = "new-head"
                self.pr["body"] += "\nDanis added concurrent notes\n"
            return result

        self.edit = pushed
        with self.assertRaisesRegex(ValueError, "head changed"):
            self.publish()
        self.assertIn("Evidence is stale", self.pr["body"])
        self.assertNotIn("Reviewed commit", self.pr["body"])
        self.assertNotIn("user-attachments", self.pr["body"])
        self.assertIn("Danis added concurrent notes", self.pr["body"])
        self.assertEqual(len(self.edits), 2)

    def test_invalidation_does_not_remove_another_publishers_evidence(self):
        original = self.edit
        def replaced(args):
            result = original(args)
            self.pr["head"]["sha"] = "new-head"
            self.pr["body"] = f"{MODULE.START}\nEvidence from a newer publisher\n{MODULE.END}"
            return result

        self.edit = replaced
        with self.assertRaisesRegex(ValueError, "head changed"):
            self.publish()
        self.assertIn("Evidence from a newer publisher", self.pr["body"])
        self.assertEqual(len(self.edits), 1)

    def test_summary_markers_are_rejected_before_upload(self):
        for marker in [MODULE.START, MODULE.END]:
            with self.subTest(marker=marker), self.assertRaisesRegex(ValueError, "Summary"):
                self.publish("Copied section: " + marker)
        self.assertEqual(self.uploads, [])
        self.assertEqual(self.edits, [])

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
