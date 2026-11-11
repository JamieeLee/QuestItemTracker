# Quest Item Tracker

A lightweight World of Warcraft Forever addon that helps answer one question when you hover a quest item: **do I still need to keep this?**

## Version

**v0.1 — first public release candidate.** Development and in-game testing took place on PR #1. The internal test ZIP numbers used during development are not the public addon version.

- **Author:** JamieeLee
- **Game interface:** 16001 (WoW Forever)
- **License:** GNU GPL-3.0
- **Required dependency:** standalone [QuestieDB](https://github.com/Questie/QuestieDB). The full Questie addon is **not** required.
- **Last known-good pre-release backup:** `baseline/v0.3.4`

## Features

- Automatically imports active and completed quest information for each character at login, and updates it as quests change.
- Uses QuestieDB to find known item objectives and required source items for current, future, completed, and repeatable quests.
- Tells you when an item is **NEEDED**, should be **KEPT** for another quest, or is **SAFE TO DELETE** based on all known database quest uses.
- Shows item **Have / Need** counts, including your carried bags and the personal bank while open.
- Adds no QIT tooltip lines to ordinary items with no verified quest use.
- Supports WoW tooltip APIs and item tooltips created by custom inventory addons.
- Adds a movable **minimap button** to open saved tooltip preferences. Also available with `/qit options`.
- Hides technical quest/item IDs and repetitive future-quest status subtitles by default. Quest names and levels remain, and the **GREY QUEST** marker stays visible for trivial quests.

## Installation

Install both `QuestieDB` and `QuestItemTracker` as separate folders under `Interface/AddOns`. Enable both addons in WoW's addon list. No import or initialization command is required.

**Do not delete your existing QIT SavedVariables.** Older data is migrated into per-character history automatically.

See [addon documentation](QuestItemTracker/README.txt) for the detailed behavior, limitations, and optional developer commands.

## Safety

QIT never sells, deletes, or moves an item. **SAFE TO DELETE** means no remaining use was found in the installed QuestieDB's covered quest-objective/source-item data; server-specific quests, incomplete records, or non-quest uses can still exist.

The v0.3.4 baseline remains recoverable in the separate `baseline/v0.3.4` branch, and PR #1 retains the development commits.
