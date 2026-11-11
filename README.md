# Quest Item Tracker — proposed v0.2 faction filter

This is a test PR based on the released **v0.1**. The published release,
`main`, and `stable/v0.1` are not modified by this proposal.

## New in v0.2

- Fix quest-giver-provided items using QuestDB.sourceItemId, including **Crate of Ghost Magnets (15848)** for **Ghost-o-plasm Round Up (6134)**.
- Active-quest fallback finds those items even before the full database index has finished.

- **Only show my faction quests** option in minimap settings (on by default).
- Horde characters see Horde-compatible and unrestricted quests; Alliance
  characters see Alliance-compatible and unrestricted quests.
- Items linked *only* to opposite-faction quests no longer gain QIT lines.
- KEEP/NEEDED/SAFE TO DELETE decisions use the filtered quest set, so the
  other faction's quest does not make your character hold an item.
- You can turn off the checkbox to see every known quest.
- Existing tooltip preferences, player history and functionality are preserved.

## How it works

QuestieDB provides `QuestDB.requiredRaces(questID)` and
`LibQuestieDB.Enum.factionRaceMasks`. The filter excludes a quest only when
its explicit race mask does not overlap the player's faction mask. Missing or
unrestricted race masks are treated as neutral/unknown and remain visible.
Active quests are never hidden by the filter. The mask comparison handles the
high bits used by Forever's Skyborne races without 32-bit bitwise operations.

Full Questie is not required; standalone QuestieDB is. No automatic item
removal is performed.

## Testing

Run the automated faction-logic tests and confirm in WoW Forever on Horde and
Alliance characters before merging. The released v0.1 remains unchanged.