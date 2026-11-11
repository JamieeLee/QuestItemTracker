# Quest Item Tracker — proposed v0.2

This is the **next test PR** based on the released **v0.1**. `main` and `stable/v0.1` stay unchanged until in-game verification.

## Faction and supplied-item fixes

- **Only show my faction quests** in the minimap settings (on by default). Excludes explicit opposite-faction quests from tooltip lines **and KEEP/SAFE decisions**, but keeps unrestricted, unknown-mask and active quests visible. Supports Forever's high-bit Skyborne race masks.
- **Crate of Ghost Magnets (15848):** registers its quest-giver-supplied relation to **Ghost-o-plasm Round Up (6134)** through `QuestDB.sourceItemId`.
- QuestieDB item lookup is **incremental and automatic**, requiring no user setup. First-hover lookups inspect only related quest candidates and active quests, not the entire database.

## All QuestieDB item paths audited

| Association | QIT behavior |
| --- | --- |
| `QuestDB.objectives()[3]` | Collect / turn-in item objective with required count |
| `QuestDB.objectives()[6][n][3]` | Item used to cast an objective spell |
| `QuestDB.requiredSourceItems()` | Item needed for a quest, including while active |
| `QuestDB.sourceItemId()` | Quest-giver-provided tool or item |
| `QuestDB.startedBy()[3]` | Item that starts a quest |
| `ItemDB.startQuest()` | Item-start reverse lookup, even if the quest side is absent |
| `QuestDB.extraObjectives()[n][5]` item references | Related event item shown as **REVIEW** only; not proof it must be kept |
| Native active item bag questID and exact active objective text | Fallback when QuestieDB has no server-custom quest relation |
| `QuestDB.specialFlags` repeatable flag | KEEP applies even after a prior completion |
| `ItemDB.questRewards()` | A reward alone does not mean the item is needed by a quest |
| `ItemDB.relatedQuests()` | Only a candidate list to verify exact fields; never proof by itself |
| NPC/object/automatic quest starters | Tracked by live quest-log synchronization once accepted; no inventory item is implied |

**Important distinction:** An item used *only to start* a quest may stop being required once the quest is accepted. Items in `requiredSourceItems`, spell objectives, or provided by a quest giver can remain needed during an active quest. Those paths are no longer conflated.

## Retention and safety

QIT never deletes or vendors items. **SAFE TO DELETE** means no remaining consuming use was found in the installed QuestieDB dataset, which can be incomplete; it does not guarantee the item has no server-specific or non-quest use. That recommendation is withheld until the full index finishes. Event-only links are shown as REVIEW, not NEEDED/SAFE.

## Testing and dependency

- Automated tests cover both factions, repeatable flags, item starters, spell-use items, required source items, provided quest tools, event references, ordinary/reward-only items, and minimap settings.
- Existing custom tooltip and SavedVariables migration tests have also been checked locally.
- **Please test in the WoW Forever client before merging.**

Standalone **QuestieDB** remains required. Full Questie is not.
