# Changelog

All notable changes to **Quest Item Tracker (QIT)** are recorded **in this single file**, newest release first.

**Maintenance rule:** On every new release, add a section to **this existing `CHANGELOG.md`**. Do not create `CHANGELOG-vX.md`, `RELEASE_NOTES-vX.md`, `vX.md`, or per-version Markdown files. Keep `README.md` focused on what the addon does and how to use it. The addon version in `QuestItemTracker/QuestItemTracker.toc` must have a matching heading here.

## [Unreleased]

### Changed
- Show **Quest Item Tracker Forever** in the game's AddOns menu, settings panel, minimap tooltip, and item tooltip header. Addon folder, saved-variable keys, slash commands, and ZIP filename remain unchanged.
- Reuse the live active quest map when looking up item relationships during database warm-up.
- Cache the completed-quest list when the client does not support per-quest completion queries, invalidating it when the quest log changes.
- Match exact objective item names rather than substrings so similarly named items cannot inherit the wrong required count.
- Always merge native metadata for *all* active quests sharing an inventory item, even after another association was already recognized.
- Treat only numeric positive quest-frequency values as repeatable, and respect QuestieDB repeatable flags for active quests.
- Eliminate unused helpers and empty bag/bank event handlers.

### Tests
- Validate all Lua syntax and mocked gameplay regressions on the tagged commit before either GitHub Release or CurseForge publishing.\n- Add a persistent mocked Forever regression test for early item lookup, multi-quest native metadata, objective-name collisions, completion caching, repeatable flags, and branding.

## [0.2] - 2026-11-11

### Added
- Faction-aware quest filtering, on by default, with a minimap preference to show both factions.
- Detection for quest-giver-supplied items, quest-starting items, spell-use items, and other QuestieDB item relationships beyond ordinary collection objectives.
- QuestieDB handling for repeatable quests and cautious **REVIEW** treatment of uncertain event-linked items.
- Source-quest information for miscellaneous/quest-category rewards, including **Bloody Map** from **Open the Maw**.

### Improved
- Improved matching for **Crate of Ghost Magnets** and other items supplied for an active quest.
- Applied faction filtering to both displayed quests and item KEEP / SAFE TO DELETE decisions.
- Avoided false requirements for quest rewards and other loosely related items.
- Added automated Lua checks and an installable test ZIP artifact to the GitHub workflow.

## [0.1] - 2026-11-11

### Initial release
- Automatic active/completed quest tracking and character-specific history.
- QuestieDB-backed quest item detection, quest names, levels, item counts, and NEEDED / KEEP / SAFE TO DELETE guidance.
- Bag and open-personal-bank inventory counts.
- Tooltip compatibility for custom inventory interfaces.
- Draggable minimap settings button and customizable tooltip details.
- Compact future-quest labels, with GREY QUEST markers preserved.
- Standalone QuestieDB dependency; full Questie is not required.
