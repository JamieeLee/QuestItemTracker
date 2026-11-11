# Quest Item Tracker

A lightweight World of Warcraft Forever addon that answers one question when you hover a quest item: **do I need to keep this?**

## Current development

- **Last known-good baseline:** v0.3.4 (`baseline/v0.3.4`)
- **Current proposal:** v0.4.0 (`feature/automatic-quest-sync`)
- **Game interface:** 16001
- **License:** GNU GPL-3.0
- **Data dependency:** standalone QuestieDB for Forever; the full Questie tracker is not required.

## v0.4.0 proposal

- Automatically imports the current quest log and completed quest IDs at login.
- Automatically refreshes quest state as quests are accepted, completed, abandoned, or the quest log changes.
- Builds the QuestieDB item-to-quest index automatically in small background batches.
- Only decorates items listed as actual quest item objectives or required source items; ordinary items are ignored.
- Shows all known quests that use an item, quest status, item counts, and the final keep/delete recommendation.
- Counts carried bags and the personal bank while it is open.
- Preserves v0.3.x SavedVariables and migrates records into per-character state.

See [`QuestItemTracker/README.txt`](QuestItemTracker/README.txt) for installation, dependency, tooltip behavior, limitations, and developer diagnostics.

The v0.4.0 branch is a proposal for testing. `main` remains the v0.3.4 baseline until the pull request is reviewed and accepted.