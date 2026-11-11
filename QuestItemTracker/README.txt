Quest Item Tracker v0.1 — World of Warcraft Forever
Author: JamieeLee

PURPOSE
Hover an item used by a quest to see the quests that need it, whether they are
active, completed, future, or repeatable, and whether to keep the item.
QIT does not annotate ordinary items with no verified quest use.

DEPENDENCY AND INSTALLATION
QuestieDB (standalone data addon) is required. Full Questie is not required.
Install QuestieDB and QuestItemTracker in Interface/AddOns; enable both in WoW.
QIT synchronizes quest history and builds the QuestieDB item index automatically.
There is no required /qit import, setup, or initialization step.

QuestieDB Forever release:
https://www.curseforge.com/wow/addons/questiedb/files/9550834
QuestieDB public API:
https://github.com/Questie/QuestieDB/blob/master/docs/api.md

TOOLTIPS AND RETENTION
- Active consuming quest: NEEDED NOW or READY TO TURN IN.
- Uncompleted future quest use: KEEP.
- Repeatable quest use: KEEP, even after a previous completion.
- All known one-time consuming quests complete: SAFE TO DELETE.
- A source item only needed to start a quest no longer counts as a required
  item for that quest once it has been accepted, unless another quest needs it.
- Shows quest names and levels and item Have / Need counts.
- Counts carried bags and the personal bank while the bank window is open.
- Ordinary items without a verified quest objective/source-item relationship
  receive no extra QIT tooltip lines.
- Modern item-data callbacks, legacy tooltips, and item setter hooks are used
  for broader compatibility with inventory addons.

MINIMAP SETTINGS
Click the draggable book icon near your minimap, or type /qit options.
Preferences save automatically.
- Show quest IDs: OFF by default
- Show item IDs: OFF by default
- Show quest levels: ON by default
- Show bag / bank breakdown: ON by default
- Show future quest labels: OFF by default

Compact mode keeps all quest names and levels. Repeated FUTURE QUEST and FUTURE
USE labels are hidden. Trivial quests keep a GREY QUEST marker in either mode.
Turning on future quest labels restores detailed subtitles.

PERSISTENT CHARACTER DATA
The current quest log and completed quest IDs are imported automatically.
Quest accepts, turn-ins, removals, and quest log updates refresh the history.
Existing pre-release SavedVariables are retained and migrated into one
character's history on first login; history thereafter is separated by
character. Older completed quest timestamps cannot be reconstructed from
completed IDs alone.

OPTIONAL DIAGNOSTIC COMMANDS
/qit            Show/hide tooltip settings
/qit options    Show/hide tooltip settings
/qit db         Show QuestieDB availability and index/hook diagnostics
/qit quests     List current active quests
/qit completed  List completed quests
/qit history    Show recorded quest events
/qit items      List observed item IDs
/qit scan       Scan bag quest-item metadata
/qit import     Refresh the active and completed quest snapshot manually

LIMITATIONS AND SAFETY
- QIT never deletes, sells, or moves items.
- SAFE TO DELETE applies only to known QuestieDB item objectives and required
  source items. Server-specific or missing quest data and non-quest uses
  cannot be ruled out.
- The database item index is built incrementally. Verified relations can
  appear early, but QIT withholds SAFE TO DELETE until indexing is complete.
- Bank counts are available while the personal bank is open, not the account
  bank or remote storage.
- Older completion dates and past abandoned quest details may be unavailable.

RELEASE HISTORY
v0.1: Initial public release of Quest Item Tracker. Previous numbered ZIPs
were internal development iterations. GitHub PR #1 preserves their changes.
