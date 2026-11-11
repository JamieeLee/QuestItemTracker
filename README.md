# Quest Item Tracker

A lightweight World of Warcraft Forever addon that answers one question when you hover a quest item: **do I need to keep this?**

## Current development

- **Last known-good baseline:** v0.3.4 (`baseline/v0.3.4`)
- **Current proposal:** v0.4.2 (`feature/automatic-quest-sync`)
- **Game interface:** 16001
- **License:** GNU GPL-3.0
- **Required dependency:** standalone QuestieDB for Forever; enable both addons in WoW's AddOns list. The full Questie tracker is not required.

## v0.4.2 proposal

- Automatically imports the current quest log and completed quest IDs at login.
- Automatically refreshes quest state as quests are accepted, completed, abandoned, or the quest log changes.
- Builds the QuestieDB item-to-quest index automatically in small background batches.
- Only decorates items listed as actual quest item objectives or required source items; ordinary items are ignored.
- Shows all known quests that use an item, quest status, item counts, and the final keep/delete recommendation.
- Counts carried bags and the personal bank while it is open.
- Preserves v0.3.x SavedVariables and migrates records into per-character state.
- Provides a draggable minimap settings button with opt-in technical IDs and other tooltip preferences.

See [`QuestItemTracker/README.txt`](QuestItemTracker/README.txt) for installation, dependency, tooltip behavior, limitations, and developer diagnostics.

The v0.4.2 branch is a proposal for testing. `main` remains the v0.3.4 baseline until the pull request is reviewed and accepted.
## v0.4.2 tooltip compatibility update

Supports typed tooltip item data when a custom bag UI does not provide `GetItem()`, and registers legacy callbacks and secure item setters as supplementary paths. QuestieDB candidate relations may provide verified item uses before the incremental index is finished, but deletion guidance waits for full indexing.

## Minimap settings

Click the Quest Item Tracker minimap button (drag to reposition), or type `/qit options`. Quest and item IDs are hidden by default, while quest levels and bag/bank breakdown remain visible. Preferences save automatically; there are no setup commands required for normal tracking.
