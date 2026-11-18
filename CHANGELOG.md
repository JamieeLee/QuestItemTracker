# Changelog

All notable changes to **Quest Item Tracker Forever (QIT)** are recorded **in this single file**, newest release first.

**Maintenance rule:** On every new release, add a section to **this existing `CHANGELOG.md`**. Do not create `CHANGELOG-vX.md`, `RELEASE_NOTES-vX.md`, `vX.md`, or per-version Markdown files. Keep `README.md` focused on what the addon does and how to use it. Every merged addon-code or `.toc` update must advance the `QuestItemTracker/QuestItemTracker.toc` version and add its notes to this same changelog. Pure documentation/build workflow PRs do not require a version bump. A versioned merge into `main` automatically publishes the tested ZIP and notes to GitHub and CurseForge after CI passes (using the configured CurseForge credentials).

## [0.7-beta.10] - 2026-11-18

- **Stock Forever Show IDs:** The existing Show IDs setting now also adds ordinary item IDs and spell IDs through standard typed tooltip callbacks, including items with no QITF quest associations. QITF retains its own quest IDs, uses no native font rewriting, and deduplicates rows on repeated tooltip callbacks.
- **Custom UI ownership unchanged:** When EllesmereUI provides its own ID controls, QITF leaves all item/spell ID rendering to the UI and shows "Handled by UI" on the disabled option.
- **Distinct tooltip palette:** QITF's section heading uses weathered copper (#C88B73), and REPEATABLE QUESTS uses soft lavender (#BD9CDE). No changes to item rarity/type, bag counts, quest difficulty, action status or UI border colors.
- **Regression tests:** Check ordinary item/spell ID visibility, duplicated typed callbacks, provider handoff, reset defaults, and native-text safety.
- **Still a draft:** No main merge or release without stock and custom Forever client verification.

## [0.7-beta.9] - 2026-11-18

- **Stop modifying shared tooltip fonts:** Remove QITF's external ID interception entirely. QITF no longer clears another addon's `ItemID`, `IconID`, or `SpellID` rows or alters native tooltip FontString text, height, width or alpha. This addresses the source of clipped/truncated Hearthstone and spell tooltips and remaining ID gaps; verify the actual in-game result before claiming a fix.
- **Let a UI own its own identifiers:** Recognize EllesmereUI's publicly exposed ID-handling capability. When detected, QITF suppresses only its **own** item/quest ID additions, greys out `Show IDs` in QITF options, and labels it `Handled by UI`. The external UI continues to control all ID visibility; the user's QITF preference remains saved for stock WoW.
- **Stock WoW compatibility:** Without a known external ID provider, QITF's Show IDs option still controls the item and quest IDs added by QITF itself. No third-party font strings are touched.
- **Regression harness:** Simulate reused native FontStrings and assert that ordinary Hearthstone/SpellID text and line heights are untouched. Verify provider on/off handoff, disabled UI option, saved settings and that Shift pin remains independent.
- **Safety:** Draft beta only. Game-client validation still required; do not merge to main or publish.

## [0.7-beta.8] - 2026-11-18

- **Forever Show IDs fix:** Checkbox handling accepts both 1/nil and true/false return values, persisting real booleans; legacy numeric settings are read safely.
- **Unified pinned IDs:** The independent pinned panel follows the same Show IDs preference, including when it uses a QITF snapshot captured before the setting changed. Mixed status/ID lines retain status text, and quest-row hit targets retain correct indices.
- **Pinned panel polish:** Rename the header from SHIFT PINNED to Pinned and add a quiet aged-gold frame border matching the QITF options style. No Blizzard-tooltip ownership changes.
- **Tests:** Exercise the WoW Forever checkbox result shape, both ID toggle states on pinned information, snapshot reuse, grouped quest-row hover and border rendering.
- **Still in draft:** Real-client verification is required for the Show IDs toggle, Hearthstone truncation, external-ID spacing and UI skin compatibility; no stable release or merge yet.

## [0.7-beta.7] - 2026-11-18

- **UI-agnostic tooltip lifecycle:** Handle recognizable ItemID, IconID, SpellID and related technical rows immediately when standard tooltip lines are appended. Collapse the full row rather than making it transparent; restore original line height on clear, hide or reuse. Remove the timer that repeatedly hid ID text.
- **No forced native tooltip Show():** Item tooltips remain owned and shown by WoW or the active inventory UI. QITF only adds its quest information when there is a matching quest use.
- **Independent pin:** Replace the second GameTooltip with a QITF-owned Frame and real interactive quest-row hit targets. The independent turn-in bubble is also an ordinary noninteractive Frame, so UI skins do not control either panel.
- **Stronger regressions:** Test ID rows added while the original tooltip is already visible, entire row compaction, normal Hearthstone text following row reuse, native Show ownership, pinned frame type and row hover behavior.
- **Scope:** QuestieDB, retention rules, faction filtering, saved history and existing settings remain unchanged. These fixes remain unverified in the actual Forever client and are not approved for merge.

## [0.7-beta.6] - 2026-11-18

- **Distinct pinned panel:** Shift-pinned QITF information appears alongside the source tooltip instead of directly covering it, with a screen-center fallback and screen clamping for difficult edges.
- **Hover interaction:** Keep the pinned information mouse-interactive and its turn-in destination bubble mouse-transparent so the two tooltips do not compete for mouse focus.
- **Compact spacing:** Remove QITF's extra blank separator line from both ordinary tooltips and pinned information.
- **Useful Shift diagnostics:** `/qit pin` retains successful capture, positioning, and release details after Shift has been released. Count only real pin captures, not hundreds of failed background polls; remove the redundant tooltip OnUpdate pin attempt.
- **Test build:** Mock checks cover positioning, mouse behavior, and diagnostics after release; actual WoW Forever validation remains required. No release or main merge.

## [0.7-beta.5] - 2026-11-18

- **One ID switch:** Consolidate three overlapping ID settings into one Show IDs toggle. It covers QITF-generated identifiers and recognized technical ID rows from the standard GameTooltip.
- **Normal item safety:** Never alter, blank, or resize Blizzard's shared tooltip font strings to hide IDs. Restore original font-string alpha when tooltips are recycled. Add Hearthstone regression coverage.
- **Shift ownership:** Copy only QITF-authored quest information to the independent pinned panel. Move the Shift watcher out of the bootstrap and allow mouse-hover over pinned quest rows.
- **Simplified settings:** Faction, IDs, tooltip presentation, and turn-in details each have an appropriate section. Remove the redundant future-status label switch.
- **Testing only:** Shift and EllesmereUI compatibility still require verification in the actual WoW Forever client. Do not merge yet.

## [0.7-beta.4] - 2026-11-17

- **Architectural cleanup:** Split the monolithic addon into ordered Core, UI, TurnIns, and Tooltips modules. The main Lua file is now a small bootstrap and event coordinator, not a feature dumping ground.
- **Shared state and functions:** Cross-module dependencies use the explicitly owned addon namespace, with one shared API for reusable operations. Keep quest history/retention logic, tooltip decoration, location decisions, and UI presentation in their respective modules.
- **Load order is tested:** Standalone mock tests load the .toc files in actual WoW order, and CI syntax checks every referenced Lua file. The release builder validates declared module files.
- **Shift investigation:** Added `/qit pin` to report Shift state, selected item, pin attempts and the last capture status. Shift remains the default; no unverified alternate modifier. Pinning still requires confirmation in the actual client before release.
- **Stable UI preserved:** No global width overrides for the stock UI. EllesmereUI-specific clipping remains a separate compatibility investigation.
- **Test build only:** `0.7-beta.4`; no merge or public release.

## [0.7-beta.3] - 2026-11-17

- **Shift pin reliability:** Move Shift-pinned information management onto an independent always-active controller; do not rely on the bag tooltip's own OnUpdate script or a pinned GameTooltip's OnUpdate. Capture immediately if Shift is already held during an item hover, and release the saved panel when Shift is lifted.
- **Readability for long NPC/zone names:** Wrap lengthy turn-in destinations at the NPC / zone boundary so a full zone like The Barrens displays on its own line rather than truncating to an ellipsis.
- **Pinned visual feedback:** Show a subdued SHIFT PINNED indicator on the separate QITF panel. Keep the core tooltip unchanged unless the player holds Shift.
- **Beta test revision:** `0.7-beta.3`; retains optional read-only navigation integration, turn-in settings, quest grouping and faction filtering.

## [0.7-beta.2] - 2026-11-17

- **Shift pins item context:** Holding Shift while hovering a quest item opens a persistent copy of QITF's information. Moving over quest text or another bag slot does not switch the pinned item; releasing Shift closes it. Row-hover bubbles on busy items still show the individual turn-in NPCs and cities.
- **Optional closest faction turn-in:** When a compatible TomTom + read-only geographic position API is available, grouped faction donation quests can show one quiet `Closest: NPC — City` line. The calculation compares known QuestieDB finisher spawn positions on the player's current continent; incomplete or incomparable locations are omitted. No waypoint is created or changed.
- **No new requirements:** Normal NPC/zone turn-in lines, grouping, and optional coordinate settings remain unchanged without navigation integration.
- **Version increment:** Next tester carries `0.7-beta.2` in the TOC, in-game menu, changelog, and test artifact.

## [0.7-beta.1] - 2026-11-17

- **Turn-in guidance (beta):** Show the known QuestieDB quest-finisher NPC/object and zone beneath a quest when the item matches one or two quests. For three or more matches, keep the main tooltip clean and expose turn-ins in a side bubble when hovering the quest row, with a Shift-hover fallback for bag UIs that dismiss the tooltip on mouse-leave. No waypoints, quest tracking, or guessed locations.
- **Optional coordinates:** Add a checkbox for one known turn-in coordinate, OFF by default. The NPC/zone detail is ON by default and can be disabled.
- **Faction quest compaction:** Retain the compact `(5 quests)` row and preserve all distinct turn-in destinations in its hover bubble, without implying they share one NPC.
- **Prerelease versioning:** Display `0.7-beta.1` in the game and beta build name, preserving a clean upgrade path to `0.7`. This is a test build only, not a public release.

## [0.6] - 2026-11-14

- **Clearer item guidance:** Highlight the KEEP / NEEDED / SAFE TO DELETE decision while displaying its explanation in quieter, readable ivory.
- **Seasonal quest labels:** Show an orange **SEASONAL QUEST** heading for known holiday categories in QuestieDB's WoW Forever data, including Winter Veil. Seasonal repeatables retain their repeatable status, with no date or event-availability assumptions.
- **Native quest difficulty colors:** Color quest names using WoW Forever's own difficulty-color API relative to the character's level, with a neutral fallback if unavailable.
- **Faction turn-in styling:** Use subdued Horde crimson or Alliance blue-violet headings, with a neutral parchment fallback. Existing faction filtering remains enabled by default and is unchanged.
- **Same quest decisions and data source:** Keep QuestieDB as the only required data addon, without changing item-retention decisions or claiming seasonal quests are currently available.

## [0.5] - 2026-11-12

- **Cleaner item tooltips:** Optionally hide extra ItemID and IconID lines added by other addons. This is off by default; QITF's own quest and item IDs remain separate options.
- **Settings that explain themselves:** Hover over any setting for a plain-English description of what it changes.
- **A more polished look:** The settings window now uses a warm charcoal-and-gold theme, with standard WoW checkboxes and buttons for UI skin compatibility.
- **QuestieDB status at a glance:** A small green or red indicator in settings shows whether QuestieDB is ready. Hover over it to see what's working or what needs to be fixed.
- **Better positioning:** The settings window remembers where you moved it, including after a reload. Reset defaults returns it to the center.
- **Improved minimap button:** The QITF badge sits neatly on the minimap edge, follows the rim while dragging, and adapts to different minimap sizes and layouts. Fixed its position resetting after `/reload` or restarting the game.
- **Forever branding:** The AddOns-list quest-book icon includes a subtle FOREVER stamp, while the minimap has its own gold QIT / FOREVER badge and matching gold tooltip heading.

## [0.4] - 2026-11-12

### Interface polish
- Display a subtle version label immediately after the **Quest Item Tracker Forever** settings title, reading the value dynamically from the TOC via the modern or legacy addon metadata API.
- Replace the default question-mark icon in WoW's AddOns list with a custom gold-and-blue quest-book icon.
- Use the same compact icon in the draggable minimap settings button without adding version text or clutter to the minimap tooltip.
- Keep the internal addon folder, SavedVariables, slash commands, and dependency setup unchanged.
- Group repeatable and low-level (grey) quest associations under one clean heading per category instead of repeating the same status beneath each quest; retain meaningful active/completion statuses, quest IDs, and item counts.
- Place city cloth donations under a concise **FACTION TURN-INS** heading and collapse matching quest-title/level/status rows into one counted line (e.g., **5 quests**), keeping every quest ID available when IDs are enabled. Different statuses or requirements remain separate.

## [0.3] - 2026-11-11

### Changed
- Publish the tested branding and source-audit changes as **v0.3** instead of leaving them under the previous v0.2 version.
- Show **Quest Item Tracker Forever** in the game's AddOns menu, settings panel, minimap tooltip, and item tooltip header. Addon folder, saved-variable keys, slash commands, and ZIP filename remain unchanged.
- Reuse the live active quest map when looking up item relationships during database warm-up.
- Cache the completed-quest list when the client does not support per-quest completion queries, invalidating it when the quest log changes.
- Match exact objective item names rather than substrings so similarly named items cannot inherit the wrong required count.
- Always merge native metadata for *all* active quests sharing an inventory item, even after another association was already recognized.
- Treat only numeric positive quest-frequency values as repeatable, and respect QuestieDB repeatable flags for active quests.
- Eliminate unused helpers and empty bag/bank event handlers.

### Tests
- Validate all Lua syntax and mocked gameplay regressions on the tagged commit before either GitHub Release or CurseForge publishing.
- Add a persistent mocked Forever regression test for early item lookup, multi-quest native metadata, objective-name collisions, completion caching, repeatable flags, and branding.

## [0.2] - 2026-11-11

### Added
- Faction-aware quest filtering, on by default, with a minimap preference to show both factions.
- Detection for quest-giver-supplied items, quest-starting items, spell-use items, and other QuestieDB item relationships beyond ordinary collection objectives.
- QuestieDB handling for repeatable quests and cautious **REVIEW** treatment of uncertain event-linked items.
- Source-quest information for miscellaneous/quest-category rewards, including **Bloody Map** from **Open the Maw**.

### Improved
- Improved matching for **Crate of Ghost Magnets** and other items supplied for an active quest.
- Applied faction filtering to both displayed quests and item KEEP / SAFE TO DELETE decisions.
- Avoided false requirements for quest rewards and other loosely related items.
- Added automated Lua checks and an installable test ZIP artifact to the GitHub workflow.

## [0.1] - 2026-11-11

### Initial release
- Automatic active/completed quest tracking and character-specific history.
- QuestieDB-backed quest item detection, quest names, levels, item counts, and NEEDED / KEEP / SAFE TO DELETE guidance.
- Bag and open-personal-bank inventory counts.
- Tooltip compatibility for custom inventory interfaces.
- Draggable minimap settings button and customizable tooltip details.
- Compact future-quest labels, with GREY QUEST markers preserved.
- Standalone QuestieDB dependency; full Questie is not required.
