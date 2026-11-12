#!/usr/bin/env python3
"""Create a single installable QIT ZIP, release notes, and optional CurseForge metadata.

Source of truth: QuestItemTracker/QuestItemTracker.toc + one CHANGELOG.md.
Output ZIP always contains exactly one top-level QuestItemTracker/ folder.
"""

import argparse
import json
import os
import re
import shutil
import sys
import zipfile
from pathlib import Path

ADDON = "QuestItemTracker"
PREFIX = "QITForeverV"
VERSIONS = re.compile(r"^## \[([^\]]+)\] - (\d{4}-\d\d-\d\d)\s*$", re.M)
VERSION = re.compile(r"^[0-9]+\.[0-9]+(?:\.[0-9]+)?$")
INVALID_IN_PACKAGE = {".zip", ".rar", ".7z", ".tar", ".gz", ".tgz"}
DEPENDENCY_URL = "https://www.curseforge.com/wow/addons/questiedb"


def project_version(root: Path) -> str:
    toc = (root / ADDON / f"{ADDON}.toc").read_text(encoding="utf-8")
    matches = re.findall(r"^## Version:\s*(\S+)\s*$", toc, re.M)
    if len(matches) != 1 or not VERSION.fullmatch(matches[0]):
        raise ValueError("Expected exactly one numeric '## Version: X.Y[.Z]' in QuestItemTracker.toc")
    return matches[0]


def current_changes(root: Path, version: str) -> str:
    text = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    headers = list(VERSIONS.finditer(text))
    matching = [i for i, h in enumerate(headers) if h.group(1) == version]
    if len(matching) != 1:
        raise ValueError(f"CHANGELOG.md must contain exactly one ## [{version}] - YYYY-MM-DD entry")
    i = matching[0]
    start, stop = headers[i].end(), headers[i + 1].start() if i + 1 < len(headers) else len(text)
    changes = text[start:stop].strip()
    if not changes:
        raise ValueError(f"CHANGELOG.md entry for {version} has no release notes")
    return changes


def release_notes(version: str, changes: str) -> str:
    # Dependency block is intentionally unconditional: can't forget it on a release.
    return (f"# QIT-v{version} — Quest Item Tracker Forever\n\n"
            "Quest Item Tracker Forever adds quest associations, inventory counts, and item guidance directly to tooltips.\n\n"
            "## Required Dependency — QuestieDB\n\n"
            "**QuestieDB is REQUIRED.** Install and enable the standalone "
            f"[QuestieDB addon]({DEPENDENCY_URL}) alongside Quest Item Tracker Forever.\n\n"
            "**Full Questie is NOT required.** Only QuestieDB is needed.\n\n"
            "## Changes in this version\n\n"
            f"{changes}\n\n"
            "## Installation\n\n"
            f"1. Download **`{PREFIX}{version}.zip`** from the Assets section below.\n"
            "2. Extract it into your WoW Forever `Interface/AddOns` folder.\n"
            "3. Verify the path is `Interface/AddOns/QuestItemTracker/QuestItemTracker.toc`.\n"
            "4. Install and enable standalone **QuestieDB**, then enable **Quest Item Tracker Forever**.\n"
            "5. Log in; QIT initializes automatically. Use `/qit options` for settings.\n\n"
            "## Important\n\n"
            "QIT never deletes, sells, or moves items. Item recommendations depend on available QuestieDB "
            "and game-client information, which may be incomplete for custom server quests or non-quest uses.\n\n"
            "**Author:** JamieeLee · **License:** GPL-3.0\n")


def check_tag(version: str, tag: str | None):
    if tag and tag != f"v{version}":
        raise ValueError(f"Git tag {tag!r} does not match TOC version v{version}")


def create_package(root: Path, output: Path, version: str):
    addon_dir = root / ADDON
    if not addon_dir.is_dir():
        raise ValueError("QuestItemTracker addon directory not found")
    required = [addon_dir / f"{ADDON}.toc", addon_dir / f"{ADDON}.lua", addon_dir / "README.txt"]
    if any(not p.is_file() for p in required):
        raise ValueError("Required addon file missing (TOC, Lua, README.txt)")
    license_file = root / "LICENSE"
    if not license_file.is_file():
        raise ValueError("Root LICENSE file is required for the installable package")

    entries = []
    for path in addon_dir.rglob("*"):
        if not path.is_file():
            continue
        if path.is_symlink():
            raise ValueError(f"Symlinks are not permitted in addon ZIP: {path}")
        if path.suffix.lower() in INVALID_IN_PACKAGE:
            raise ValueError(f"Nested archive prohibited: {path}")
        if "__pycache__" in path.parts or path.name in {".DS_Store", "Thumbs.db"}:
            continue
        relative = path.relative_to(root).as_posix()
        if relative == f"{ADDON}/LICENSE":
            continue  # Always use repository's root GPL license
        entries.append((relative, path))
    entries.append((f"{ADDON}/LICENSE", license_file))
    entries.sort(key=lambda pair: pair[0])
    package = output / f"{PREFIX}{version}.zip"
    with zipfile.ZipFile(package, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for arcname, path in entries:
            z.write(path, arcname)
    with zipfile.ZipFile(package) as z:
        names = z.namelist()
        if z.testzip() or not names or any(not n.startswith(f"{ADDON}/") for n in names):
            raise ValueError("Invalid ZIP structure")
        if any(Path(n).suffix.lower() in INVALID_IN_PACKAGE for n in names):
            raise ValueError("Nested archive detected")
        if not all(f"{ADDON}/{name}" in names for name in (f"{ADDON}.toc", f"{ADDON}.lua", "README.txt", "LICENSE")):
            raise ValueError("Missing required file in ZIP")
    # Actions artifacts add one wrapper ZIP. Upload the *unpacked* staging directory
    # in CI to avoid ZIP-in-ZIP for test artifact downloads.
    staging = output / "staging" / ADDON
    staging.mkdir(parents=True, exist_ok=True)
    for arcname, path in entries:
        target = output / "staging" / arcname
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
    return package


def make_curseforge_metadata(version: str, changes: str) -> dict:
    data = {
        "changelog": release_notes(version, changes),
        "changelogType": "markdown",
        "displayName": f"QIT-v{version} (WoW Forever)",
        "releaseType": "release",
        "relations": {"projects": [{"slug": "questiedb", "type": "requiredDependency"}]},
    }
    # CurseForge game version 17053 = WoW Forever 1.60.1 (Interface 16001).
    # Never let the upload API default to the newest retail WoW version.
    # This addon is exclusive to Forever; changes require an intentional code
    # update and regression test, not a repo variable that can drift.
    data["gameVersions"] = [17053]
    return data


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "validate"))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path("dist"))
    parser.add_argument("--tag", default="", help="Optional expected tag, e.g. v0.2")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    version = project_version(root)
    check_tag(version, args.tag)
    changes = current_changes(root, version)
    if args.command == "build":
        output = args.output.resolve()
        output.mkdir(parents=True, exist_ok=True)
        package = create_package(root, output, version)
        (output / "release-notes.md").write_text(release_notes(version, changes), encoding="utf-8")
        (output / "curseforge-metadata.json").write_text(json.dumps(make_curseforge_metadata(version, changes), indent=2) + "\n", encoding="utf-8")
        print(f"PACKAGE={package}")
        print(f"VERSION={version}")
    else:
        print(f"Validated addon version {version} and matching CHANGELOG.md entry")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        print(f"Release validation failed: {exc}", file=sys.stderr)
        sys.exit(1)