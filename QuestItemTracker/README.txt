Quest Item Tracker (QIT) — WoW Forever
Created by JamieeLee | GPL-3.0

WHAT IS QIT?
Quest Item Tracker adds useful quest information to item tooltips.
It identifies quest items, shows related quest names and levels, and gives
NEEDED / KEEP / SAFE TO DELETE guidance based on your character's quests
and the installed QuestieDB quest data.

INSTALLATION
1. Extract QuestItemTracker into Interface/AddOns.
2. Install and enable the standalone QuestieDB addon.
3. Enable QuestItemTracker, then log in. No initial setup is necessary.
Full Questie is NOT required.

WHAT QIT RECOGNIZES
- Items needed for quest objectives or to cast quest-related spells.
- Items supplied by quest givers, required source items, and item-started quests.
- Quest-related event references (marked REVIEW if actual need is uncertain).
- Select miscellaneous quest rewards: shows where you earned them, without
  falsely labeling them required or disposable.
- Faction-appropriate future/repeatable quests, and your active quests.
- Inventory quantities in bags and the personal bank while it is open.

TOOLTIP PREFERENCES
Click the draggable minimap button, or type /qit options.
- Only show my faction quests (ON by default).
- Show quest IDs and item IDs (OFF by default).
- Show quest levels and bag/bank breakdown (ON by default).
- Show future quest labels (OFF by default): names and GREY QUEST markers
  stay visible when the repeated future-status lines are hidden.
Settings save automatically.

OPTIONAL DIAGNOSTIC COMMANDS
/qit db          Database/index diagnostics
/qit quests      Active quests
/qit completed   Completed quest history
/qit history     Recorded quest events
/qit items       Seen item IDs
/qit scan        Native bag quest-item metadata
/qit import      Manual data refresh (normally automatic)

IMPORTANT
QIT never deletes, sells, or moves items.
SAFE TO DELETE is based only on currently known quest uses. Missing,
server-specific, or non-quest uses cannot be ruled out. When uncertain,
keep the item. QIT does not show SAFE TO DELETE until the full quest item
index is ready. Personal bank quantities are visible while the bank is open.
Quest history is character-specific; older completed quest dates may be
unknown when imported.

DOCUMENTATION / CHANGE HISTORY
https://github.com/JamieeLee/QuestItemTracker
All release changes belong in the repository's single CHANGELOG.md.
The README explains what QIT does; it is not the release history.
