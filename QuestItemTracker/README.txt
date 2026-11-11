Quest Item Tracker v0.3.4 — WoW: Forever

THIS BUILD ADDS CHARACTER SNAPSHOT IMPORT + CONSERVATIVE ITEM RETENTION STATUS.

INSTALL
1. Exit WoW.
2. Replace ONLY the QuestItemTracker addon folder.
3. Keep your existing WTF\Account\...\SavedVariables\QuestItemTracker.lua file.
4. QuestieDB is optional for live tracking, but required for broad future quest/item associations.
5. Do not delete the SavedVariables file; this build retains old QIT history.

NO ONE IS "F**KED" STARTING MID-RUN
On login, the addon reads the current quest log and imports all completed quest IDs returned by C_QuestLog.GetAllCompletedQuestIDs.
Use /qit import at any time to take that snapshot again.
It records quest names/IDs and completed status. For quests completed before installing QIT, original completion dates and accept/abandon event history are not available from the client; the addon marks those records as imported with unknown dates rather than inventing timestamps.
Active quests are imported from the quest log with their current status and objective data.
New accepts, turn-ins, and removals are recorded with local timestamps from the time QIT is installed.

ITEM RETENTION ASSESSMENT
The item tooltip now gives one of three conservative recommendations:
- KEEP: there is an active quest, a known future quest use, or a repeatable use.
- LIKELY SAFE TO DELETE: all known non-repeatable consuming quest uses are completed and there are no uncertain associations.
- REVIEW: only generic/ambiguous associations are known, or no confirmed consuming use exists.

"Likely safe" is not a guarantee. Quest databases can be incomplete, server-specific quests may be missing, and an item may have a non-quest use. QIT never deletes or vendors anything.

QUEST LOOKUP
- Preserves original native bag quest metadata and active objective-text matching.
- Optional QuestieDB adds database quest-objective relationships, quest levels, future associations and Have/Need counts.
- QuestieDB is data-only; the full Questie tracker/map addon is not required.
- DB index is built incrementally in small batches.

COMMANDS
/qit             Help
/qit import      Import current active and completed quest snapshot from the client
/qit db          API/database status and index progress
/qit quests      List current active quests
/qit completed   List completed quests imported from Forever
/qit completed word  Filter completed quest names
/qit history     Show local event history + imported completed snapshot count
/qit history word  Filter local event history
/qit scan        Scan bag quest-item metadata
/qit items       List item IDs observed by QIT

DATABASE DEPENDENCY
QuestieDB standalone Forever release (Interface 16001):
https://www.curseforge.com/wow/addons/questiedb/files/9550834
Full Questie addon is not required.

IMPORTANT LIMITATIONS
- Bulk completed import requires C_QuestLog.GetAllCompletedQuestIDs.
- Imported older completions have unknown historical completion dates.
- Earlier abandoned quests cannot generally be recovered unless they exist in QIT's prior SavedVariables.
- Inventory count is bags only, not bank.
- Grey/trivial and repeatable classification are best-effort.
- "Not in quest log" is not proof that a quest is available now; prerequisites, faction, class and level gates still apply.
- A database miss is not proof that an item has no use.

DATA PRESERVATION
QuestItemTrackerDB.quests, .events, and .items are retained. This build adds import metadata; it does not wipe existing SavedVariables.

PATCH 0.3.3 — COMPLETED QUEST SNAPSHOT
- /qit import refreshes active and completed quest snapshots from the game.
- /qit completed lists completed quest IDs, including older completions imported mid-run.
- Imported completion dates are labeled unknown; locally recorded turn-in dates are preserved.
- Item assessment distinguishes active/future/repeatable uses from completed non-repeatable uses.


PATCH 0.3.4 — TOOLTIP NIL-FUNCTION FIX
- Fixed repeatable-quest status lookups to call the correctly named helper.
- Fixes the repeated tooltip error reported in v0.3.3.