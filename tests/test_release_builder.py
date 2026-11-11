import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "release_builder.py"
spec = importlib.util.spec_from_file_location("qit_release_builder", SCRIPT)
rb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rb)


class ReleaseBuilderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        addon = self.root / "QuestItemTracker"
        addon.mkdir()
        (addon / "QuestItemTracker.toc").write_text("## Version: 0.2\nQuestItemTracker.lua\n")
        (addon / "QuestItemTracker.lua").write_text("-- main addon\n")
        (addon / "README.txt").write_text("Installation\n")
        (self.root / "LICENSE").write_text("GPL-3.0\n")
        (self.root / "CHANGELOG.md").write_text("# Changelog\n\n## [0.2] - 2026-11-11\n\n- Improved faction filtering.\n\n## [0.1] - 2026-11-11\n\n- Initial release.\n")

    def tearDown(self):
        self.temp.cleanup()

    def test_package_one_zip_one_folder_no_nested_archive(self):
        out = self.root / "dist"
        out.mkdir()
        path = rb.create_package(self.root, out, rb.project_version(self.root))
        self.assertEqual(path.name, "QITForeverV0.2.zip")
        with zipfile.ZipFile(path) as z:
            names = z.namelist()
            self.assertTrue(names)
            self.assertTrue(all(n.startswith("QuestItemTracker/") for n in names))
            self.assertIn("QuestItemTracker/LICENSE", names)
            self.assertIn("QuestItemTracker/QuestItemTracker.toc", names)
            self.assertFalse(any(n.endswith(".zip") for n in names))
        self.assertTrue((out / "staging/QuestItemTracker/QuestItemTracker.toc").is_file())

    def test_release_notes_always_contain_dependency(self):
        changes = rb.current_changes(self.root, "0.2")
        body = rb.release_notes("0.2", changes)
        self.assertIn("QuestieDB is REQUIRED", body)
        self.assertIn("Full Questie is NOT required", body)
        self.assertIn("QITForeverV0.2.zip", body)
        self.assertNotIn("Initial release.", body)

    def test_tag_mismatch_fails(self):
        with self.assertRaises(ValueError):
            rb.check_tag("0.2", "v0.3")

    def test_missing_changelog_version_fails(self):
        with self.assertRaises(ValueError):
            rb.current_changes(self.root, "0.3")

    def test_nested_zip_rejected(self):
        (self.root / "QuestItemTracker" / "other.zip").write_bytes(b"x")
        with self.assertRaisesRegex(ValueError, "Nested archive"):
            rb.create_package(self.root, self.root, "0.2")

    def test_curseforge_dependency_relation(self):
        metadata = rb.make_curseforge_metadata("0.2", "- Update")
        self.assertIn({"slug": "questiedb", "type": "requiredDependency"}, metadata["relations"]["projects"])
        self.assertEqual(metadata["releaseType"], "release")


if __name__ == "__main__":
    unittest.main()