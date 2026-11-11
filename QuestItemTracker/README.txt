Quest Item Tracker v0.2 TEST BUILD — WoW Forever
Author: JamieeLee

This build is proposed in draft PR #2. v0.1 is still the public release.
Requires standalone QuestieDB; full Questie is NOT required.

NEW QUEST ITEM COVERAGE
- Quest objective items: QuestDB.objectives()[3]
- Quest spell-use items: QuestDB.objectives()[6][n][3]
- Quest-required source items: QuestDB.requiredSourceItems()
- Quest-giver-provided tools: QuestDB.sourceItemId()
- Items that START quests: QuestDB.startedBy()[3] and ItemDB.startQuest()
- Event/extra-objective item references: shown as REVIEW, not proof of need.
- Native current-quest bag metadata and exact objective text supplement missing
  server-specific database links.
- Repeatable quests also use QuestDB.specialFlags.

Miscellaneous/quest-class reward items now show the quest they came from
(ItemDB.questRewards) as provenance only. Bloody Map (271745) is rewarded by
Open the Maw (95682) for Horde. This does NOT establish that the reward must
be kept or can be safely deleted; its future use is unconfirmed.
Ordinary equipment rewards remain silent; generic related-quest metadata is
never proof of need. NPC/object/automatic quest starters are tracked live.

FACTION FILTER
The minimap option "Only show my faction quests" is enabled by default.
Horde characters don't see explicit Alliance-only quests, and vice versa.
Unknown, neutral and already-active quests remain shown. Filtering also applies
to KEEP/SAFE decisions. You can turn the filter off in minimap settings.

ITEM RETENTION
An item required to START a quest may no longer be needed after acceptance.
Quest-required items and quest-giver-provided tools can still be needed DURING
the active quest; they are not confused with starter items. Items for completed
repeatable quests may be needed again.
QIT never deletes or sells an item. SAFE TO DELETE applies only to the uses
known to the installed QuestieDB and is withheld until indexing is finished.
Event-reference-only matches show REVIEW rather than a false KEEP/SAFE verdict.

No manual import, initialization or database scan is required.
Quest states and character history are updated automatically on login.
Older QIT SavedVariables remain preserved.

/qit options  - tooltip preferences
/qit db       - API and index diagnostics
/qit import   - manually refresh the quest log (normally automatic)
