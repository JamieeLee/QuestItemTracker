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

TOOLTIP PRESENTATION
- Quest names use the game's level-based difficulty colors.
- NEEDED / KEEP / SAFE TO DELETE decisions emphasize the action while keeping
  the explanation readable. These are suggestions, not item-management actions.
- Known seasonal quests have a separate orange heading.
- Repeatable quests have a soft lavender heading; low-level quests are grouped.
- Matching city cloth quests share a compact FACTION TURN-INS row without
  losing their individual quest IDs or their distinct NPC destinations.
- The Quest Item Tracker Forever tooltip heading uses weathered copper.
- Horde / Alliance faction headings retain their own subdued accents.

V0.7 TURN-IN INFORMATION
- For quest items with one or two matching quests, show known QuestieDB
  quest-finisher NPC/object names and zones beneath the quest.
- With three or more matching quests, hover a quest row to see known turn-ins
  in an unobtrusive side bubble, rather than filling the main item tooltip.
- Holding Shift while hovering a quest item opens a separate Pinned panel
  beside the original tooltip. Its quest rows remain interactive as you move
  the cursor away from the item; releasing Shift closes the panel.
- Long NPC / zone names wrap onto readable lines.
- Show turn-in NPC and zone is ON by default. Show coordinates is OFF.
- If a compatible TomTom position API is available, QITF may show the closest
  known comparable faction turn-in as an optional read-only hint.
  This does not create, move, clear, or replace waypoints.
- Missing QuestieDB finisher data is omitted instead of guessed.

V0.7 IDENTIFIERS AND UI COMPATIBILITY
- Show IDs is OFF by default.
- With stock WoW Forever tooltips, enabling it adds QITF-owned item and spell
  identifiers and relevant QITF quest IDs. Disabling it removes those additions;
  QITF does not suppress unrelated rows contributed by other addons.
- When EllesmereUI's known ID handler is detected, QITF disables its own
  Show IDs setting and displays "Handled by UI". Use that UI's own controls.
- Other custom UIs are not automatically detected. QITF does not rewrite,
  clear, hide, or resize native or external tooltip text to suppress IDs.
- Pinning, quest details, and normal tooltip formatting stay independent.

TOOLTIP PREFERENCES
Click the draggable minimap button, or type /qit options.
- Hover over a setting for an explanation.
- Only show my faction quests (ON by default).
- Show IDs (OFF by default): QITF item/spell/quest identifiers in stock UI;
  handled by EllesmereUI when that UI's ID provider is detected.
- Show quest levels and bag/bank breakdown (ON by default).
- Show turn-in NPC and zone (ON by default).
- Show turn-in coordinates (OFF by default).
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
