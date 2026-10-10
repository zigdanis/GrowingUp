import importlib.util
import hashlib
import json
import re
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
        self.video = self.directory / "demo.mp4"
        self.ffmpeg("-f", "lavfi", "-i", "testsrc=size=640x1280:rate=5", "-frames:v", "1", str(self.image))
        self.ffmpeg("-f", "lavfi", "-i", "testsrc=size=640x360:rate=5:duration=2", "-f", "lavfi", "-i",
                    "sine=frequency=1000:duration=2", "-map", "0:v:0", "-map", "1:a:0", "-c:v", "libx264",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", "-movflags", "+faststart", str(self.video))
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
        self.upload_paths = []
        self.queried_workflows = []

    def ffmpeg(self, *arguments):
        subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", *arguments],
                       check=True, capture_output=True, text=True)

    def probe(self, path):
        result = subprocess.run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-show_frames",
                                 "-of", "json", str(path)], check=True, capture_output=True, text=True)
        return json.loads(result.stdout)

    def gh(self, *args):
        if args == ("api", "repos/{owner}/{repo}"):
            return json.dumps({"full_name": "owner/repo", "id": 1234})
        if args[:2] == ("run", "list"):
            self.queried_workflows.append(args[args.index("--workflow") + 1])
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
        upload_path = Path(args[args.index("--input") + 1])
        self.assertTrue(upload_path.is_file())
        self.upload_paths.append(upload_path)
        asset_name = re.sub(r"[^A-Za-z0-9-]", "-", query["name"][0])
        return json.dumps({"url": "https://github.com/user-attachments/assets/" + asset_name})

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
        self.assertIn("user-attachments/assets/checkpoint-png", body)
        self.assertIn("user-attachments/assets/demo-mp4", body)
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

    def capture_metadata(self):
        self.metadata.pop("journey_outcome")
        self.metadata.update(
            workflow="app-store-screenshots.yml", capture_outcome="success",
            verification_outcome="success", composition_outcome="success",
        )

    def test_capture_publication_checks_the_capture_workflow(self):
        self.capture_metadata()
        self.publish("Inspected both native locale captures, widget crops and birthday animation.")
        self.assertEqual(self.queried_workflows, ["app-store-screenshots.yml"] * 2)
        self.assertEqual(len(self.uploads), 2)
        self.assertIn("current-head", self.pr["body"])

    def test_ci_publication_keeps_the_existing_workflow(self):
        self.publish()
        self.assertEqual(self.queried_workflows, ["ci.yml"] * 2)

    def test_capture_requires_every_stage_before_upload(self):
        self.capture_metadata()
        for outcome in ("capture_outcome", "export_outcome", "verification_outcome", "composition_outcome"):
            for value in ("failure", "skipped", None):
                with self.subTest(outcome=outcome, value=value):
                    if value is None:
                        self.metadata.pop(outcome)
                    else:
                        self.metadata[outcome] = value
                    with self.assertRaises(ValueError):
                        self.publish()
                    self.metadata[outcome] = "success"
        self.assertEqual(self.edits, [])
        self.assertEqual(self.uploads, [])

    def test_capture_rejects_stale_source_and_attempt(self):
        self.capture_metadata()
        for field, value in (("head_sha", "old-head"), ("run_attempt", "1"), ("run_id", "122")):
            with self.subTest(field=field):
                original = self.metadata[field]
                self.metadata[field] = value
                with self.assertRaises(ValueError):
                    self.publish()
                self.metadata[field] = original
        self.assertEqual(self.edits, [])
        self.assertEqual(self.uploads, [])

    def test_unsupported_workflow_is_rejected_before_upload(self):
        self.metadata["workflow"] = "unrelated-release.yml"
        with self.assertRaisesRegex(ValueError, "CI or App Store"):
            self.publish()
        self.assertEqual(self.edits, [])
        self.assertEqual(self.uploads, [])

    def test_capture_metadata_needs_an_explicit_workflow(self):
        self.capture_metadata()
        self.metadata.pop("workflow")
        with self.assertRaises(ValueError):
            self.publish()
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
        self.assertTrue(all(not path.exists() for path in self.upload_paths))

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

    def test_media_rejects_external_files_and_invalid_signatures(self):
        with tempfile.TemporaryDirectory(prefix="growingup-external-") as other:
            external = Path(other) / "image.png"
            external.write_bytes(b"image")
            with self.assertRaises(ValueError):
                MODULE.media_file(self.directory, str(external), ".png")
        for path, invalid in ((self.image, b"not a PNG"), (self.video, b"not an MP4")):
            with self.subTest(path=path):
                original = path.read_bytes()
                path.write_bytes(invalid)
                with self.assertRaises(ValueError):
                    self.publish()
                path.write_bytes(original)
        self.assertEqual(self.edits, [])
        self.assertEqual(self.uploads, [])

    def test_compact_derivatives_preserve_bounds_ratio_timing_and_originals(self):
        originals = [self.image.read_bytes(), self.video.read_bytes()]
        with tempfile.TemporaryDirectory(prefix="compact-output-") as temporary:
            outputs = MODULE.compact_media(self.directory, ["checkpoint.png"], ["demo.mp4"], Path(temporary))
            self.assertEqual([self.image.read_bytes(), self.video.read_bytes()], originals)
            for output, ratio in zip(outputs, (0.5, 640 / 360)):
                info = self.probe(output)
                video = next(stream for stream in info["streams"] if stream["codec_type"] == "video")
                self.assertLessEqual(video["width"], 320)
                self.assertLessEqual(video["height"], 640)
                self.assertAlmostEqual(video["width"] / video["height"], ratio, places=2)
                self.assertLessEqual(output.stat().st_size, MODULE.MAX_BYTES)
                subprocess.run(["ffmpeg", "-v", "error", "-i", str(output), "-f", "null", "-"],
                               check=True, capture_output=True)
            info = self.probe(outputs[1])
            video = next(stream for stream in info["streams"] if stream["codec_type"] == "video")
            self.assertEqual(video["codec_name"], "h264")
            self.assertEqual(video["pix_fmt"], "yuv420p")
            self.assertEqual(video["width"] % 2, 0)
            self.assertEqual(video["height"] % 2, 0)
            self.assertAlmostEqual(float(info["format"]["duration"]), 2, delta=0.15)
            self.assertIn("audio", [stream["codec_type"] for stream in info["streams"]])
            data = outputs[1].read_bytes()
            self.assertLess(data.index(b"moov"), data.index(b"mdat"))

    def test_small_media_is_not_upscaled_and_variable_frame_timing_is_preserved(self):
        image = self.directory / "small.png"
        video = self.directory / "variable.mp4"
        self.ffmpeg("-f", "lavfi", "-i", "testsrc=size=100x50:rate=1", "-frames:v", "1", str(image))
        for selection in ("not(mod(n,3))", "eq(n,0)+eq(n,2)+eq(n,5)+eq(n,9)+eq(n,13)+eq(n,17)+eq(n,19)"):
            with self.subTest(selection=selection):
                self.ffmpeg("-f", "lavfi", "-i", "testsrc=size=100x50:rate=10:duration=2",
                            "-vf", f"select='{selection}'", "-fps_mode", "vfr", "-c:v", "libx264",
                            "-pix_fmt", "yuv420p", str(video))
                with tempfile.TemporaryDirectory(prefix="compact-output-") as temporary:
                    outputs = MODULE.compact_media(self.directory, [image.name], [video.name], Path(temporary))
                    for output in outputs:
                        stream = self.probe(output)["streams"][0]
                        self.assertEqual((stream["width"], stream["height"]), (100, 50))
                    original = self.probe(video)
                    compact = self.probe(outputs[1])
                    self.assertAlmostEqual(float(compact["format"]["duration"]), float(original["format"]["duration"]), delta=0.05)
                    self.assertEqual([frame["best_effort_timestamp_time"] for frame in original["frames"]],
                                     [frame["best_effort_timestamp_time"] for frame in compact["frames"]])

    def test_oversized_png_source_is_compacted_and_preserved(self):
        source = self.directory / "large.png"
        self.ffmpeg("-f", "lavfi", "-i", "nullsrc=s=4800x2400:d=1,noise=alls=100:allf=t+u",
                    "-frames:v", "1", str(source))
        self.assertGreater(source.stat().st_size, MODULE.MAX_BYTES)
        digest = hashlib.sha256(source.read_bytes()).digest()
        with tempfile.TemporaryDirectory(prefix="compact-output-") as temporary:
            output = MODULE.compact_media(self.directory, [source.name], [], Path(temporary))[0]
            self.assertLessEqual(output.stat().st_size, MODULE.MAX_BYTES)
            self.assertEqual(hashlib.sha256(source.read_bytes()).digest(), digest)

    def test_derivative_names_cannot_collide_with_other_sources(self):
        sources = [("a/02-frame.png", "red"), ("b/frame.png", "blue"), ("c/frame.png", "green")]
        for relative, color in sources:
            source = self.directory / relative
            source.parent.mkdir(parents=True, exist_ok=True)
            self.ffmpeg("-f", "lavfi", "-i", f"color=c={color}:s=320x640", "-frames:v", "1", str(source))
        with tempfile.TemporaryDirectory(prefix="compact-output-") as temporary:
            outputs = MODULE.compact_media(self.directory, [relative for relative, _ in sources], [], Path(temporary))
            self.assertEqual(len({path.resolve() for path in outputs}), 3)
            self.assertEqual([path.name for path in outputs], ["02-frame.png", "frame.png", "frame.png"])
            self.assertEqual(len({hashlib.sha256(path.read_bytes()).digest() for path in outputs}), 3)

    def test_failed_preflight_never_uploads_and_cleans_derivatives(self):
        with patch.object(MODULE.shutil, "which", return_value=None), self.assertRaisesRegex(ValueError, "ffmpeg is required"):
            self.publish()
        ffmpeg = MODULE.shutil.which("ffmpeg")
        with patch.object(MODULE.shutil, "which", side_effect=lambda tool: ffmpeg if tool == "ffmpeg" else None), \
                self.assertRaisesRegex(ValueError, "ffprobe is required"):
            self.publish()
        with patch.object(MODULE, "MAX_BYTES", 1), self.assertRaisesRegex(ValueError, "at most 10 MiB"):
            self.publish()
        self.video.write_bytes(b"\x00\x00\x00\x20ftypisomnot really an mp4")
        outputs = []
        original = MODULE.compact_media
        def tracked(*args):
            outputs.append(args[-1])
            return original(*args)
        with patch.object(MODULE, "compact_media", side_effect=tracked), self.assertRaises(subprocess.CalledProcessError):
            self.publish()
        self.assertTrue(all(not path.exists() for path in outputs))
        self.assertEqual(self.uploads, [])
        self.assertEqual(self.edits, [])

    def test_publisher_groups_pairs_with_checkpoint_labels_and_separate_video(self):
        images = ["checkpoint.png", "people-list.png", "birthday-details.png", "person [edit]\\ draft.png", "saved.png"]
        for name in images[1:]:
            (self.directory / name).write_bytes(self.image.read_bytes())
        (self.directory / "metadata.json").write_text(json.dumps(self.metadata))
        with patch.object(MODULE, "gh", side_effect=self.gh):
            MODULE.publish(42, self.directory, "Inspected evidence.", images, ["demo.mp4"])
        body = self.pr["body"]
        self.assertRegex(body, r"!\[Checkpoint\]\([^\n]+\) !\[People List\]\([^\n]+\)\n\n"
                              r"!\[Birthday Details\]\([^\n]+\) !\[Person Edit Draft\]\([^\n]+\)\n\n"
                              r"!\[Saved\]\([^\n]+\)\n\nhttps://github.com/user-attachments/assets/demo-mp4\n\n")
        self.assertTrue(all(not path.exists() for path in self.upload_paths))

    def test_image_or_video_alone_still_suffices(self):
        (self.directory / "metadata.json").write_text(json.dumps(self.metadata))
        with patch.object(MODULE, "gh", side_effect=self.gh):
            MODULE.publish(42, self.directory, "Inspected checkpoint.", ["checkpoint.png"], [])
            MODULE.publish(42, self.directory, "Inspected interaction.", [], ["demo.mp4"])
        self.assertEqual(len(self.uploads), 2)

    def test_malformed_markers_do_not_destroy_body(self):
        for body in [MODULE.START, MODULE.END, MODULE.END + MODULE.START, MODULE.START * 2 + MODULE.END]:
            with self.subTest(body=body), self.assertRaises(ValueError):
                MODULE.section(body, "replacement")


if __name__ == "__main__":
    unittest.main()
