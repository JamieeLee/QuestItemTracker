# Quest Item Tracker Forever (QITF)

**Know what to keep.**

Quest Item Tracker Forever is a lightweight addon for **World of Warcraft: Forever** that adds useful quest information directly to item tooltips. Hover an item in your bags to see which quests use it, how many you have, and whether you should keep it.

QIT uses the standalone **QuestieDB** data addon for quest information. **You do not need to install full Questie.**

## What it does

- **Quest-aware tooltips:** See associated quest names, levels, item requirements, and current quest status.
- **Item guidance:** Identify items **NEEDED** for active quests or worth **KEEPING** for later or repeatable quests. Where the available data permits, QIT can mark an item **SAFE TO DELETE**.
- **More than collection quests:** Recognizes quest starter items, items supplied by quest givers, required source items, spell-use items, and other verified item associations.
- **Quest reward origins:** For select miscellaneous and quest-category rewards, shows which quest rewarded the item without treating the reward itself as a requirement.
- **Faction-aware:** Hides quests restricted to the opposite faction by default. Neutral quests and quests already in your log remain visible.
- **Live item totals:** Counts carried items and includes the personal bank while its window is open.
- **Automatic quest history:** Tracks active and completed quests separately for each character without manual database imports.
- **Quiet on ordinary items:** Does not fill tooltips with unrelated information.
- **Minimap settings:** Open preferences with the movable minimap button or `/qit options`. Hover over settings for explanations; changes save automatically. The settings window remembers where you moved it.
- **QuestieDB status:** A small green/red light in settings shows whether the separate database addon is ready; hover over red for help.

## How the tooltip works

When QIT identifies a relevant item, it adds a section showing the associated quests and an item recommendation. The recommendation depends on your **current quest log**, **completed quest history**, **faction**, and **QuestieDB's known requirements**.

| Label | Meaning |
| --- | --- |
| **NEEDED** | A currently active quest uses the item. |
| **KEEP** | A known future or repeatable quest can use the item. |
| **SAFE TO DELETE** | No remaining item requirement was found among the known covered quests, after indexing completes. |
| **REVIEW** | A quest/event relationship exists, but a required item use could not be confirmed. |
| **QUEST REWARD** | Shows where an item was obtained; this does not prove it must be kept or discarded. |

QITF **never deletes, sells, or moves your items**. Its guidance is based on the installed QuestieDB data and what the game client exposes, so custom or missing server data and non-quest item uses may not be covered. When unsure, keep the item.

## Requirements

- **World of Warcraft: Forever** (interface `16001`)
- **[QuestieDB](https://www.curseforge.com/wow/addons/questiedb)** — the standalone data addon, enabled alongside QITF
- **No full Questie installation required**

## Installation

1. Install Quest Item Tracker Forever through CurseForge (which should also install QuestieDB), or download the ZIP from GitHub.
2. Extract the **`QuestItemTracker`** folder to your WoW `Interface/AddOns` directory.
3. If installing the ZIP manually, also install **`QuestieDB`** in the same directory.
4. Verify both addons are enabled in WoW's AddOns screen.
5. Log in and hover a quest item. QITF automatically synchronizes your quest history and builds its item index.

**Updating from an older QITF version?** Replace the addon files, but keep your existing SavedVariables; QIT preserves and migrates older quest records.

## Settings

Click the book icon near the minimap (drag it to reposition) or enter **`/qit options`**.

| Setting | Default |
| --- | --- |
| Only show my faction quests | On |
| Hide IDs from other addons | Off |
| Show QITF quest IDs | Off |
| Show QITF item IDs | Off |
| Show quest levels | On |
| Show bag / bank breakdown | On |
| Show future quest labels | Off |

Quest names stay visible when extra future-quest labels are hidden, and trivial quests keep their **GREY QUEST** marker. Preferences are saved across logins.

## Optional commands

- `/qit options` — open settings
- `/qit db` — database, index, and tooltip diagnostic information
- `/qit quests` — currently active quests
- `/qit completed` — completed quest records
- `/qit history` — recorded quest history
- `/qit import` — manually refresh quest data (normally unnecessary)

## Known limitations

- Personal bank counts are available only while the bank is open; remote/account storage is not included.
- Imported older completed quests do not contain reconstructable original completion dates.
- Some server-specific quest data may be unavailable or incomplete in QuestieDB.
- **SAFE TO DELETE** is a database-based recommendation, not a guarantee of no other uses.

## Releases and project

- **[Changelog](CHANGELOG.md)** — the **one** maintained file for all version history and release changes
- **[GitHub releases](https://github.com/JamieeLee/QuestItemTracker/releases)** — downloadable releases
- **[Issues and suggestions](https://github.com/JamieeLee/QuestItemTracker/issues)** — report bugs or propose features

Created and maintained by **JamieeLee**. Licensed under **GPL-3.0**.
