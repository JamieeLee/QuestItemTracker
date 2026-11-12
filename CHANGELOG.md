# Changelog

All notable changes to **Quest Item Tracker Forever (QIT)** are recorded **in this single file**, newest release first.

**Maintenance rule:** On every new release, add a section to **this existing `CHANGELOG.md`**. Do not create `CHANGELOG-vX.md`, `RELEASE_NOTES-vX.md`, `vX.md`, or per-version Markdown files. Keep `README.md` focused on what the addon does and how to use it. Every merged addon-code or `.toc` update must advance the `QuestItemTracker/QuestItemTracker.toc` version and add its notes to this same changelog. Pure documentation/build workflow PRs do not require a version bump. A versioned merge into `main` automatically publishes a GitHub release after passing CI. CurseForge publishing remains a separate explicit action.

## [0.5] - 2026-11-12

### Tooltip preferences
- Add a new **Hide IDs from other addons** option, **off by default**; only when enabled, suppress isolated technical ID rows like ItemID and IconID from other addons' shared item tooltips.
- Organize the ID display options together: external-addon suppression first, followed by independent **Show QIT quest IDs** and **Show QIT item IDs** toggles. Existing QIT ID preferences remain off by default.
- Leave normal item details, descriptions, and all quest matching/KEEP decisions unchanged. Do not modify other addons' SavedVariables or settings.
- Refresh the settings panel with compact ID and details sections; preserve one source-of-truth changelog and the automatic release pipeline.
- Remember the dragged settings-panel position in QIT's account-wide SavedVariables and restore it after `/reload` or restarting WoW. Fresh installs keep the original centered position, and **Reset defaults** recenters the panel.

## [0.4] - 2026-11-12

### Interface polish
- Display a subtle version label immediately after the **Quest Item Tracker Forever** settings title, reading the value dynamically from the TOC via the modern or legacy addon metadata API.
- Replace the default question-mark icon in WoW's AddOns list with a custom gold-and-blue quest-book icon.
- Use the same compact icon in the draggable minimap settings button without adding version text or clutter to the minimap tooltip.
- Keep the internal addon folder, SavedVariables, slash commands, and dependency setup unchanged.
- Group repeatable and low-level (grey) quest associations under one clean heading per category instead of repeating the same status beneath each quest; retain meaningful active/completion statuses, quest IDs, and item counts.
- Place city cloth donations under a concise **FACTION TURN-INS** heading and collapse matching quest-title/level/status rows into one counted line (e.g., **5 quests**), keeping every quest ID available when IDs are enabled. Different statuses or requirements remain separate.

## [0.3] - 2026-11-11

### Changed
- Publish the tested branding and source-audit changes as **v0.3** instead of leaving them under the previous v0.2 version.
- Show **Quest Item Tracker Forever** in the game's AddOns menu, settings panel, minimap tooltip, and item tooltip header. Addon folder, saved-variable keys, slash commands, and ZIP filename remain unchanged.
- Reuse the live active quest map when looking up item relationships during database warm-up.
- Cache the completed-quest list when the client does not support per-quest completion queries, invalidating it when the quest log changes.
- Match exact objective item names rather than substrings so similarly named items cannot inherit the wrong required count.
- Always merge native metadata for *all* active quests sharing an inventory item, even after another association was already recognized.
- Treat only numeric positive quest-frequency values as repeatable, and respect QuestieDB repeatable flags for active quests.
- Eliminate unused helpers and empty bag/bank event handlers.

### Tests
- Validate all Lua syntax and mocked gameplay regressions on the tagged commit before either GitHub Release or CurseForge publishing.
- Add a persistent mocked Forever regression test for early item lookup, multi-quest native metadata, objective-name collisions, completion caching, repeatable flags, and branding.

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
