Quest Item Tracker v0.4.0 — WoW: Forever

PURPOSE
Hover a quest item in your bags or personal bank and quickly see:
- Every known quest that consumes or requires the item.
- Whether each quest is active, a future use, completed, or repeatable.
- How many of the item you have across your bags and open bank, and how many the quest requires.
- Whether the remaining item is needed now, worth keeping for another quest, or safe to delete after all known uses are completed.

NO PLAYER SETUP OR DATABASE COMMANDS
QIT automatically imports the character's current quest log and completed quest IDs at login.
It updates its quest state automatically when quests are accepted, turned in, removed, or the quest log changes.
The QuestieDB item-to-quest index is built automatically in the background after login.
Players do not need to run /qit import, scan a database, initialize anything, or use Questie itself.

DEPENDENCY
Requires the standalone QuestieDB data addon for WoW Forever (Interface 16001).
The full Questie quest tracker, map, and navigation addon are NOT required.
Install QuestieDB once alongside Quest Item Tracker. QIT loads and uses its data automatically.
QuestieDB Forever release:
https://www.curseforge.com/wow/addons/questiedb/files/9550834
QuestieDB API documentation:
https://github.com/Questie/QuestieDB/blob/master/docs/api.md

TOOLTIP BEHAVIOR
- Items absent from QuestieDB's exact quest item-objective and required-source-item data are ignored. Ordinary items do not get QIT tooltip lines.
- Active quest use: NEEDED NOW / READY TO TURN IN.
- Not completed yet and not currently active: FUTURE QUEST / KEEP.
- Repeatable quest use: KEEP, even if it has been completed before.
- A source item used only to start a quest is no longer required by that quest after it is accepted; other quest uses are still checked.
- Every known consuming quest completed and no repeatable use remains: SAFE TO DELETE.
- Each associated quest is listed with its name, quest ID, level, and Have / Need information where the database provides a quantity.
- Quest item counts include backpack/carried bags and the personal bank while the bank window is open.

IMPORTANT SAFETY NOTES
- QIT never deletes, vendors, or moves items.
- SAFE TO DELETE means all quest uses represented in the installed QuestieDB data are completed and no repeatable use remains. It cannot account for missing/server-specific data or unrelated non-quest item uses.
- If the QuestieDB index is not ready yet, QIT does not show a premature status.
- Quest completion dates from before QIT was installed are not available; the game only exposes completed quest IDs. They are imported as completed without invented dates.
- v0.3.x SavedVariables are migrated automatically into a per-character record on first login. Existing quest/item/history data is preserved. New character data is kept separately to avoid one character's completions affecting another.
- The personal bank is only counted while it is open. Account bank storage is not included.

DEVELOPER COMMANDS
These are optional diagnostics, not part of normal player use:
/qit db          Show API/database/index status
/qit quests      List active quests
/qit completed   List completed quests
/qit history     Show tracked quest history
/qit items       List item IDs observed by QIT
/qit scan        Scan native bag quest-item metadata
/qit import      Manually refresh the active/completed snapshot (normally automatic)

VERSION 0.4.0
- Automatic character-scoped quest history sync and completed quest import.
- One-time migration of existing v0.3.x SavedVariables into character-scoped data.
- Exact QuestieDB item objective/source-item lookup; unrelated items are left alone.
- Per-item lifecycle assessment: needed now, keep for future/repeatable use, or safe to delete.
- Bag and open personal-bank item counts.
- Removed broad related-quest/reward associations from keep/delete decisions.
- Database indexing remains incremental and requires no player command.