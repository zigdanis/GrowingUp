from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "ci-scope.py"


class CIScopeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="growingup-ci-scope-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git("init", "-q")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "user.name", "Fixture")
        for path in ("scripts/app-store-metadata.py", "scripts/tests/test_app_store_metadata.py",
                     "GrowingUp/App.swift", "docs/guide.md"):
            self.write(path, "base\n")
        self.base = self.commit()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, check=True, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE).stdout.decode().strip()

    def write(self, path, content="changed\n"):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(content)

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")
        return self.git("rev-parse", "HEAD")

    def classify(self, event="pull_request", base=None, head=None):
        result = subprocess.run([sys.executable, str(SCRIPT), "--event", event,
                                 "--base", self.base if base is None else base,
                                 "--head", self.git("rev-parse", "HEAD") if head is None else head],
                                cwd=self.root, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return result.stdout.decode().strip()

    def test_uploader_tests_docs_and_committed_screenshots_need_only_tool_checks(self):
        for path in ("scripts/app-store-metadata.py", "scripts/tests/test_app_store_metadata.py",
                     "docs/guide.md", "docs/app-store-screenshots-preview.html", "docs/releases/notes.json",
                     "marketing/app-store/screenshots/ru/01-mia.png", "marketing/app-store/screenshots/source.json"):
            self.write(path)
        self.commit()
        for event in ("pull_request", "push"):
            with self.subTest(event=event):
                self.assertEqual(self.classify(event), "ios_required=false")

    def test_app_assets_project_packages_tests_harness_workflows_and_unknown_paths_need_ios(self):
        for path in ("Core/Person.swift", "GrowingUp/Assets.xcassets/icon.png", "GrowingUp.xcodeproj/project.pbxproj",
                     "GrowingUp.xcodeproj/xcshareddata/swiftpm/Package.resolved", "GrowingUpTests/PersonTests.swift",
                     "GrowingUpUITests/Baselines/glass.png", "scripts/run-ui-journeys.sh",
                     "scripts/run-app-store-screenshots.sh", "scripts/ci-scope.py", "scripts/tests/test_ci_scope.py",
                     ".github/workflows/ci.yml", "docs/app-store-demo-photos/baby-girl.png", "unknown/tool.py",
                     "marketing/app-store/screenshots/new.swift", "Gemfile", ".swiftlint.yml"):
            with self.subTest(path=path):
                self.git("reset", "--hard", self.base)
                self.write(path)
                self.commit()
                self.assertEqual(self.classify(), "ios_required=true")

    def test_mixed_tool_and_app_changes_need_ios(self):
        self.write("scripts/app-store-metadata.py")
        self.write("GrowingUp/App.swift")
        self.commit()
        self.assertEqual(self.classify(), "ios_required=true")

    def test_deleting_app_input_needs_ios(self):
        (self.root / "GrowingUp/App.swift").unlink()
        self.commit()
        self.assertEqual(self.classify(), "ios_required=true")

    def test_both_sides_of_renames_are_classified(self):
        for old, new in (("GrowingUp/App.swift", "docs/archived.md"), ("docs/guide.md", "GrowingUp/New.swift")):
            with self.subTest(old=old, new=new):
                self.git("reset", "--hard", self.base)
                self.git("mv", old, new)
                self.commit()
                self.assertEqual(self.classify(), "ios_required=true")

    def test_docs_rename_stays_on_tool_checks(self):
        self.git("mv", "docs/guide.md", "docs/renamed guide.md")
        self.commit()
        self.assertEqual(self.classify(), "ios_required=false")

    def test_manual_unknown_events_missing_or_zero_base_and_unreadable_refs_need_ios(self):
        self.write("scripts/app-store-metadata.py")
        self.commit()
        for event, base in (("workflow_dispatch", self.base), ("unknown", self.base),
                            ("push", ""), ("push", "0" * 40), ("push", "f" * 40)):
            with self.subTest(event=event, base=base):
                self.assertEqual(self.classify(event, base), "ios_required=true")

    def test_pr_compares_branch_changes_and_push_compares_exact_commits(self):
        self.git("checkout", "-qb", "tooling")
        self.write("scripts/app-store-metadata.py")
        head = self.commit()
        self.git("checkout", "--detach", self.base)
        self.write("GrowingUp/App.swift")
        base_tip = self.commit()
        self.assertEqual(self.classify("pull_request", base_tip, head), "ios_required=false")
        self.assertEqual(self.classify("push", base_tip, head), "ios_required=true")

    def test_empty_diff_fails_closed(self):
        self.assertEqual(self.classify(), "ios_required=true")


if __name__ == "__main__":
    unittest.main()
