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

V0.7-BETA.9 NATIVE TOOLTIP SAFETY AND ID OWNERSHIP
- QITF never resizes or rewrites another addon's item/spell tooltip text.
- Known UI ID providers manage their own ID visibility. QITF disables
  its Show IDs control with a "Handled by UI" note when one is detected.
- Stock Forever still controls QITF's own optional item/quest IDs.
- Pinning and quest-row mouse interactions remain independent.
- Hearthstone clipping and custom-UI gap behavior need real-client checks.

V0.7-BETA.8 PIN AND IDENTIFIER POLISH
- The Show IDs checkbox supports WoW Forever's checked-state values.
- Pinned quest information follows the same Show IDs setting as native
  item tooltips, even if a setting was changed after the source was captured.
- Pinned panel uses a subtle aged-gold frame and the short label "Pinned".
- The working Shift capture, release and quest-row bubble stay unchanged.

V0.7-BETA.7 UI-INDEPENDENCE AUDIT
- Standard tooltips remain under the active UI's ownership.
- Technical ID lines collapse immediately and restore their native geometry
  on reuse; no visible interval-based ID suppression.
- Shift pin and hover bubble now use QITF-owned Frames, not GameTooltip.
- New tests simulate IDs being added after the first tooltip Show.

V0.7-BETA.6 PIN VISIBILITY + TOOLTIP SPACING
- Pinned quest information opens beside the ordinary tooltip, not on top.
- Its quest-row hover bubble does not steal mouse input.
- Removes the unwanted extra blank line ahead of QITF's quest details.
- /qit pin reports the last successful pin and release after Shift is let go.

V0.7-BETA.5 SAFE TOOLTIP + SIMPLIFIED MENU
- One Show IDs switch covers QITF identifiers and recognizable ID rows from
  standard tooltip frames, including IDs added by custom UI addons.
- ID hiding does not edit item tooltip text or layout.
- Independent Shift pinning uses QITF's own captured quest information.
- The future quest labels control was removed to simplify the menu.

V0.7-BETA.4 MODULAR REFACTOR
- Addon subsystems now live in Core, UI, TurnIns, and Tooltips folders.
- Main file only coordinates events and lifecycle; .toc defines load order.
- /qit pin displays pin diagnostics (Shift state, item, and last attempt)
  when testing WoW client behavior. It never modifies other addons.
- The Shift interaction remains experimental until confirmed in game.

V0.7-BETA.3 PIN FIX + CLEAN TURN-IN WRAPPING
- The Shift lock now uses its own update controller, independent of bag
  tooltip repaint/hide behavior. Holding Shift shows a clearly marked pinned
  information panel; release Shift to close it.
- Long quest-finisher destinations break after the NPC name and show the
  complete zone on the next line. The Barrens is no longer shortened.
- The rest of the existing turn-in, grouping and navigation behavior remains.

V0.7-BETA.2 SHIFT LOCK + OPTIONAL GPS HINT
- Hold Shift while hovering an item to pin QITF's information so you can move
  onto quest names and get their turn-in bubble. Releasing Shift unpins it.
- A compatible TomTom geographic-position API can optionally show the nearest
  *known, comparable* faction turn-in NPC and city beneath grouped donations.
  No GPS addon is required, and QITF never creates or changes waypoints.
- If the location data is incomplete or on a different continent, omit the
  nearest suggestion instead of guessing.

V0.7 BETA TURN-IN DETAILS
- When an item matches 1-2 quests, show the known quest finisher's name
  and zone below the quest. This is on by default.
- When it matches 3 or more, hover the quest row to show turn-ins in a small
  side bubble instead of cluttering the bag tooltip. Shift-hover the item
  if your bag UI closes the tooltip when you move the cursor off the item.
- Optional coordinates are OFF by default. No map pins or navigation.
- If QuestieDB doesn't know the turn-in, QITF doesn't guess.
- Grouped faction rows keep their compact (5 quests) label; the hover bubble
  lists distinct turn-in destinations rather than assigning one NPC to all.
- Development beta. Existing SavedVariables and filters are unchanged.

TOOLTIP PREFERENCES
Click the draggable minimap button, or type /qit options.
- Hover over a setting for an explanation.
- Only show my faction quests (ON by default).
- Show IDs (OFF by default): unified technical identifier visibility setting.
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
