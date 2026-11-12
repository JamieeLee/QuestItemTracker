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
        self.assertIn("Quest Item Tracker Forever (QITF)", body)
        self.assertIn("CurseForge should install QuestieDB automatically", body)
        self.assertIn("**Manual ZIP:**", body)
        self.assertIn("**CurseForge app:**", body)
        self.assertNotIn("Assets section below", body)
        self.assertNotIn("BigWigs", body)
        self.assertNotIn("LibDBIcon", body)

    def test_tag_mismatch_fails(self):
        with self.assertRaises(ValueError):
            rb.check_tag("0.2", "v0.3")

    def test_missing_changelog_version_fails(self):
        with self.assertRaises(ValueError):
            rb.current_changes(self.root, "0.3")

    def test_public_release_notes_reject_development_only_addon_names(self):
        # Player-facing changelogs describe QITF changes without exposing
        # the implementation research behind a minimap alignment fix.
        for name in ("BigWigs", "LibDBIcon"):
            (self.root / "CHANGELOG.md").write_text(
                f"# Changelog\\n\\n## [0.2] - 2026-11-11\\n\\n"
                f"- Fixed ring alignment by copying {name} positioning.\\n"
            )
            with self.assertRaisesRegex(ValueError, "development-only reference"):
                rb.current_changes(self.root, "0.2")

    def test_nested_zip_rejected(self):
        (self.root / "QuestItemTracker" / "other.zip").write_bytes(b"x")
        with self.assertRaisesRegex(ValueError, "Nested archive"):
            rb.create_package(self.root, self.root, "0.2")

    def test_real_addon_icon_is_included_in_installable_zip(self):
        # The character-select AddOns icon and minimap button share this
        # tiny native TGA. A forgotten art asset would yield WoW's red '?'.
        project = Path(__file__).resolve().parents[1]
        toc = (project / "QuestItemTracker/QuestItemTracker.toc").read_text()
        self.assertIn(
            r"## IconTexture: Interface\AddOns\QuestItemTracker\Media\QITIcon", toc
        )
        icon = project / "QuestItemTracker/Media/QITIcon.tga"
        data = icon.read_bytes()
        self.assertEqual(data[:3], b"\x00\x00\x02")
        self.assertEqual(int.from_bytes(data[12:14], "little"), 64)
        self.assertEqual(int.from_bytes(data[14:16], "little"), 64)
        self.assertEqual(data[16], 32)  # 32-bit BGRA incl. transparency
        # The FOREVER ribbon is near the bottom of the icon, not a separate asset.
        self.assertGreater(data[18 + ((52 * 64 + 32) * 4) + 3], 100)
        with tempfile.TemporaryDirectory() as folder:
            archive = rb.create_package(project, Path(folder), rb.project_version(project))
            with zipfile.ZipFile(archive) as z:
                self.assertEqual(
                    z.read("QuestItemTracker/Media/QITIcon.tga"), data
                )

    def test_status_circle_is_round_and_ships_in_zip(self):
        # Native transparent TGA rather than a font glyph, which Forever
        # renders as an empty square when the font lacks that character.
        project = Path(__file__).resolve().parents[1]
        path = project / "QuestItemTracker/Media/StatusCircle.tga"
        data = path.read_bytes()
        self.assertEqual(data[:3], bytes([0, 0, 2]))
        self.assertEqual(int.from_bytes(data[12:14], "little"), 32)
        self.assertEqual(int.from_bytes(data[14:16], "little"), 32)
        self.assertEqual(data[16], 32)
        pixels = data[18:]
        def alpha(x, y):
            return pixels[(y * 32 + x) * 4 + 3]
        self.assertEqual(alpha(0, 0), 0)
        self.assertEqual(alpha(31, 31), 0)
        self.assertGreater(alpha(15, 15), 200)
        with tempfile.TemporaryDirectory() as folder:
            archive = rb.create_package(project, Path(folder), rb.project_version(project))
            with zipfile.ZipFile(archive) as z:
                self.assertEqual(z.read("QuestItemTracker/Media/StatusCircle.tga"), data)

    def test_approved_minimap_badge_is_included_in_release_zip(self):
        project = Path(__file__).resolve().parents[1]
        badge = project / "QuestItemTracker/Media/QITForeverBadge.tga"
        data = badge.read_bytes()
        self.assertEqual(data[:3], bytes([0, 0, 2]))
        self.assertEqual(int.from_bytes(data[12:14], "little"), 32)
        self.assertEqual(int.from_bytes(data[14:16], "little"), 32)
        self.assertEqual(data[16], 32)
        self.assertGreater(data[18 + ((16 * 32 + 16) * 4) + 3], 0)
        with tempfile.TemporaryDirectory() as folder:
            archive = rb.create_package(project, Path(folder), rb.project_version(project))
            with zipfile.ZipFile(archive) as z:
                self.assertEqual(z.read("QuestItemTracker/Media/QITForeverBadge.tga"), data)
                lua = z.read("QuestItemTracker/QuestItemTracker.lua").decode()
                self.assertIn("QIT_BADGE_TEXTURE", lua)
                self.assertIn("0.96, 0.79, 0.40", lua)  # gold tooltip header

    def test_missing_approved_minimap_badge_blocks_release(self):
        addon = self.root / "QuestItemTracker"
        (addon / "QuestItemTracker.lua").write_text("-- QIT_BADGE_TEXTURE")
        with self.assertRaisesRegex(ValueError, "Required UI artwork missing"):
            rb.create_package(self.root, self.root, "0.2")

    def test_curseforge_dependency_relation(self):
        metadata = rb.make_curseforge_metadata("0.2", "- Update")
        self.assertIn({"slug": "questiedb", "type": "requiredDependency"}, metadata["relations"]["projects"])
        self.assertEqual(metadata["releaseType"], "release")
        self.assertEqual(metadata["gameVersions"], [17053])  # Forever 1.60.1 only

    def test_curseforge_never_defaults_to_latest_retail(self):
        # QIT targets Forever, regardless of any old CI variable values.
        import os
        from unittest.mock import patch
        with patch.dict(os.environ, {"CF_GAME_VERSION_IDS": "999999"}):
            metadata = rb.make_curseforge_metadata("0.4", "- New release")
        self.assertEqual(metadata["gameVersions"], [17053])
        self.assertEqual(metadata["displayName"], "QITF-v0.4 (WoW Forever)")


if __name__ == "__main__":
    unittest.main()