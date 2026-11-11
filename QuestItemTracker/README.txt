Quest Item Tracker v0.2 TEST BUILD — World of Warcraft Forever
Author: JamieeLee

CHANGES FROM v0.1
- Recognizes quest-giver-provided items via QuestDB.sourceItemId.
- Fixes Crate of Ghost Magnets (item 15848) for Ghost-o-plasm Round Up (quest 6134).
- While indexing, verifies source items against the current active quest log.
- Keeps provided items needed during an active quest, not as start-only requirements.
- Added a faction-filter checkbox to minimap settings (enabled by default).
- Shows quests for your current Horde or Alliance faction plus unrestricted quests.
- Hides quests explicitly restricted to the opposing faction using QuestieDB's
  requiredRaces field and provider-supplied factionRaceMasks.
- Applies the same filter to KEEP / SAFE TO DELETE decisions, not just names.
- Always shows active quests, even if database restrictions disagree.
- Supports Forever Skyborne race bits without 32-bit truncation.
- Can toggle the filter off to see every quest association as in v0.1.
- Unknown or unrestricted faction data remains visible rather than risking
  hiding neutral quests. QuestieDB data can be incomplete.

INSTALL
Requires standalone QuestieDB (not the full Questie addon).
Replace the QuestItemTracker folder in Interface/AddOns.
Do not delete saved variables. Your current v0.1 release remains unchanged.

SETTINGS
Click the draggable minimap book icon, or type /qit options.
Only show my faction quests: ON by default.
Other settings and tooltip features work as in v0.1.

CAUTION
QIT never sells, deletes, or moves items. SAFE TO DELETE only refers to
known item/quest associations within the installed QuestieDB data.