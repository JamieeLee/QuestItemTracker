Quest Item Tracker Forever (QITF) — WoW Forever
Created by JamieeLee | GPL-3.0

WHAT IS QITF?
Quest Item Tracker Forever adds useful quest information to item tooltips.
It identifies quest items, shows related quest names and levels, and gives
NEEDED / KEEP / SAFE TO DELETE guidance based on your character's quests
and the installed QuestieDB quest data.

INSTALLATION
1. Install through CurseForge (which should include QuestieDB), or extract
   the QuestItemTracker folder into Interface/AddOns from the GitHub ZIP.
2. For manual ZIP installs, install the standalone QuestieDB addon separately.
3. Enable both addons, then log in. No initial setup is necessary.
Full Questie is NOT required.

WHAT QITF RECOGNIZES
- Items needed for quest objectives or to cast quest-related spells.
- Items supplied by quest givers, required source items, and item-started quests.
- Quest-related event references (marked REVIEW if actual need is uncertain).
- Select miscellaneous quest rewards: shows where you earned them, without
  falsely labeling them required or disposable.
- Faction-appropriate future/repeatable quests, and your active quests.
- Inventory quantities in bags and the personal bank while it is open.

V0.6 TOOLTIP PRESENTATION
- Seasonal quest associations show an orange SEASONAL QUEST heading.
- Quest names use the game's level-based difficulty colors.
- KEEP / NEEDED guidance emphasizes the action without bright explanation text.
- FACTION TURN-INS uses your character's Horde/Alliance-inspired heading color.
- Existing faction filtering and retention decisions are unchanged.

V0.7 BETA TURN-IN DETAILS
- When QuestieDB identifies the quest finisher, show the NPC or object's name
  and the zone below the quest. This is on by default.
- Optional coordinates are OFF by default. No map pins or navigation.
- If QuestieDB doesn't know the turn-in, QITF doesn't guess.
- Different turn-in destinations are never falsely collapsed together.
- Test build 0.7-beta.1. SavedVariables and existing filters are unchanged.

TOOLTIP PREFERENCES
Click the draggable minimap button, or type /qit options.
- Hover over a setting for an explanation.
- Only show my faction quests (ON by default).
- Hide technical IDs added by other addons (OFF by default).
- Show QITF quest IDs and item IDs (OFF by default).
- Show quest levels and bag/bank breakdown (ON by default).
- Show turn-in NPC and zone (ON by default).
- Show turn-in coordinates (OFF by default).
- Show future quest labels (OFF by default): names and GREY QUEST markers
  stay visible when the repeated future-status lines are hidden.
Settings save automatically. The settings window remembers its position.
A green/red light indicates whether QuestieDB is ready; hover for details.

OPTIONAL DIAGNOSTIC COMMANDS
/qit db          Database/index diagnostics
/qit quests      Active quests
/qit completed   Completed quest history
/qit history     Recorded quest events
/qit items       Seen item IDs
/qit scan        Native bag quest-item metadata
/qit import      Manual data refresh (normally automatic)

IMPORTANT
QITF never deletes, sells, or moves items.
SAFE TO DELETE is based only on currently known quest uses. Missing,
server-specific, or non-quest uses cannot be ruled out. When uncertain,
keep the item. QITF does not show SAFE TO DELETE until the full quest item
index is ready. Personal bank quantities are visible while the bank is open.
Quest history is character-specific; older completed quest dates may be
unknown when imported.

DOCUMENTATION / CHANGE HISTORY
https://github.com/JamieeLee/QuestItemTracker
All release changes belong in the repository's single CHANGELOG.md.
The README explains what QITF does; it is not the release history.
