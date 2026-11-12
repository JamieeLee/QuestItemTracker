-- Quest Item Tracker Forever (version comes from the TOC metadata)
-- Automatic per-character quest sync + tooltip compatibility and index warm-up.
-- Requires the standalone QuestieDB data addon; the full Questie tracker/map addon is not required.

QuestItemTrackerDB = QuestItemTrackerDB or {}

local DB = QuestItemTrackerDB
DB.version = 4
DB.quests = DB.quests or {} -- v0.3.x legacy bucket, migrated on first login for this character.
DB.events = DB.events or {}
DB.items = DB.items or {}
DB.characters = DB.characters or {}
-- Tooltip preferences are shared across the account; quest history stays character-scoped.
DB.settings = type(DB.settings) == "table" and DB.settings or {}
local CHARACTER_DATA
local completedQuestSnapshot -- fallback when IsQuestFlaggedCompleted is unavailable

local MAX_EVENTS = 500
local MAX_HISTORY_LINES = 35
local REQUIRED_DB_CONTRACT = 4

local itemQuestIndex = {}
local dbIndexReady = false
local dbIndexRunning = false
local dbIndexProcessed = 0
local dbIndexTotal = 0
local tooltipHooked = false
local tooltipErrorReported = false
-- Modern data hooks and older client scripts can both run for one hover.
-- Remember only tooltips actually decorated; OnHide/Cleared resets this state.
local decoratedTooltips = setmetatable({}, { __mode = "k" })
local hookStats = { typed = false, legacy = false, setters = 0 }

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffQIT:|r " .. tostring(message))
    end
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
    return nil
end

-- Read the addon's public version from its TOC; never hardcode it in the UI.
local function AddonVersion()
    local version = SafeCall(C_AddOns and C_AddOns.GetAddOnMetadata, "QuestItemTracker", "Version")
    if type(version) ~= "string" or version == "" then
        version = SafeCall(GetAddOnMetadata, "QuestItemTracker", "Version")
    end
    return type(version) == "string" and version ~= "" and version or nil
end

local function Now()
    if type(date) == "function" then return date("%Y-%m-%d %H:%M:%S") end
    return tostring(time and time() or 0)
end

local function InitializeCharacterData()
    local playerName = UnitName and UnitName("player") or nil
    local realmName = GetRealmName and GetRealmName() or nil
    if not playerName or playerName == "" then playerName = "UnknownCharacter" end
    if not realmName or realmName == "" then realmName = "UnknownRealm" end

    local key = realmName .. "::" .. playerName
    local character = DB.characters[key]
    if type(character) ~= "table" then
        character = { quests = {}, events = {}, items = {} }
        DB.characters[key] = character
    end

    character.quests = character.quests or {}
    character.events = character.events or {}
    character.items = character.items or {}

    -- Preserve data created by v0.3.x. The old SavedVariables layout was shared,
    -- so migrate it once to the first character that loads the new version.
    if not DB.legacyCharacterDataMigrated then
        for id, record in pairs(DB.quests) do
            if character.quests[id] == nil then character.quests[id] = record end
        end
        for index, event in ipairs(DB.events) do
            character.events[#character.events + 1] = event
        end
        for id, item in pairs(DB.items) do
            if character.items[id] == nil then character.items[id] = item end
        end
        DB.legacyCharacterDataMigrated = true
    end

    CHARACTER_DATA = character
    completedQuestSnapshot = nil
    DB.activeCharacterKey = key
    DB.quests = character.quests
    DB.events = character.events
    DB.items = character.items
end

local function AddEvent(kind, questID, title, extra)
    table.insert(DB.events, 1, {
        time = Now(),
        kind = kind,
        questID = tonumber(questID),
        title = title or (questID and ("Quest " .. tostring(questID))) or "Unknown quest",
        extra = extra,
    })
    while #DB.events > MAX_EVENTS do
        table.remove(DB.events)
    end
end

local function QuestTitle(questID, fallback)
    local title = SafeCall(C_QuestLog and C_QuestLog.GetTitleForQuestID, questID)
    if type(title) == "string" and title ~= "" then return title end
    if type(QuestDB) == "table" and type(QuestDB.name) == "function" then
        title = SafeCall(QuestDB.name, questID)
        if type(title) == "string" and title ~= "" then return title end
    end
    return fallback or ("Quest " .. tostring(questID))
end

local function GetActiveQuestMap()
    local result = {}
    if not C_QuestLog or type(C_QuestLog.GetNumQuestLogEntries) ~= "function"
        or type(C_QuestLog.GetInfo) ~= "function" then
        return result
    end

    local count = SafeCall(C_QuestLog.GetNumQuestLogEntries) or 0
    for index = 1, count do
        local info = SafeCall(C_QuestLog.GetInfo, index)
        if info and not info.isHeader and tonumber(info.questID) then
            local id = tonumber(info.questID)
            local entry = {
                questID = id,
                title = info.title or QuestTitle(id),
                level = info.level,
                isComplete = info.isComplete,
                isTrivial = info.isTrivial,
                frequency = info.frequency,
                isTask = info.isTask,
                objectives = {},
            }
            local objectives = SafeCall(C_QuestLog.GetQuestObjectives, id)
            if type(objectives) == "table" then
                for _, objective in ipairs(objectives) do
                    if type(objective) == "table" then
                        entry.objectives[#entry.objectives + 1] = objective
                    end
                end
            end
            result[id] = entry
        end
    end
    return result
end

local function IsQuestCompleted(questID)
    local completed = SafeCall(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, questID)
    if completed ~= nil then return completed == true end

    if not completedQuestSnapshot then
        local all = SafeCall(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
        if type(all) == "table" then
            completedQuestSnapshot = {}
            for _, id in ipairs(all) do
                local key = tonumber(id)
                if key then completedQuestSnapshot[key] = true end
            end
        end
    end
    return completedQuestSnapshot ~= nil
        and completedQuestSnapshot[tonumber(questID)] == true
end

local function IsTrivialQuest(quest)
    if quest and quest.isTrivial ~= nil then return quest.isTrivial == true end
    if quest and quest.questID and C_QuestLog and type(C_QuestLog.IsQuestTrivial) == "function" then
        local value = SafeCall(C_QuestLog.IsQuestTrivial, quest.questID)
        if value ~= nil then return value == true end
    end
    if quest and quest.level and type(GetQuestDifficultyColor) == "function" then
        local color = SafeCall(GetQuestDifficultyColor, quest.level)
        if color and color.r and color.g and color.b then
            return color.r > 0.45 and color.g > 0.45 and color.b > 0.45
                and math.abs(color.r - color.g) < 0.18
                and math.abs(color.g - color.b) < 0.18
        end
    end
    return false
end

local function IsRepeatableQuest(quest)
    if quest and type(quest.frequency) == "number" and quest.frequency > 0 then return true end
    if quest and quest.questID then
        local value = SafeCall(C_QuestLog and C_QuestLog.IsRepeatableQuest, quest.questID)
        if value == nil then
            value = SafeCall(C_QuestLog and C_QuestLog.IsQuestReplayable, quest.questID)
        end
        return value == true
    end
    return false
end

local function SyncActiveQuestLog()
    local active = GetActiveQuestMap()
    local count = 0
    for id, quest in pairs(active) do
        count = count + 1
        local record = DB.quests[id] or {}
        record.questID = id
        record.title = quest.title
        record.firstSeen = record.firstSeen or "Imported from current quest log"
        record.lastSeen = Now()
        record.status = "active"
        record.level = quest.level
        record.isTrivial = IsTrivialQuest(quest)
        record.isRepeatable = IsRepeatableQuest(quest)
        record.importedFromQuestLog = true
        DB.quests[id] = record
    end
    return count, active
end

local function ImportCompletedQuestList(activeMap)
    local completed = SafeCall(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
    if type(completed) ~= "table" then
        completedQuestSnapshot = nil
        return 0, 0, false
    end

    local total = 0
    local newlyImported = 0
    local snapshot = {}
    for _, rawID in ipairs(completed) do
        local id = tonumber(rawID)
        if id then
            total = total + 1
            snapshot[id] = true
            local record = DB.quests[id] or {}
            if not record.importedCompleted then newlyImported = newlyImported + 1 end

            record.questID = id
            record.title = QuestTitle(id, record.title)
            record.importedCompleted = true
            record.completionDateUnknown = not record.completedAt
            record.firstSeen = record.firstSeen or "Imported from completed quest list (original date unavailable)"
            -- A repeatable quest can be both in the completed history and active now.
            if not (activeMap and activeMap[id]) then record.status = "completed" end
            DB.quests[id] = record
        end
    end

    completedQuestSnapshot = snapshot
    CHARACTER_DATA.completedQuestImportAt = Now()
    CHARACTER_DATA.completedQuestImportCount = total
    return total, newlyImported, true
end

local function ReconcileMissingActiveQuests(activeMap)
    -- Catch a quest removal that happened while the addon was reloading or offline.
    -- Never invent a completion: only the completed-ID snapshot can do that.
    for id, record in pairs(DB.quests) do
        if record.status == "active" and not activeMap[id] then
            if IsQuestCompleted(id) then
                record.status = "completed"
                record.completedAt = record.completedAt or nil
                record.importedCompleted = true
                record.completionDateUnknown = not record.completedAt
            else
                record.status = "abandoned"
                record.abandonedAt = record.abandonedAt or "Status reconciled from current quest log"
            end
        end
    end
end

local function SyncQuestHistory(importCompleted)
    if not CHARACTER_DATA then return 0, 0 end
    local activeCount, activeMap = SyncActiveQuestLog()
    if importCompleted then
        local completedCount, newlyImported, supported = ImportCompletedQuestList(activeMap)
        if supported then ReconcileMissingActiveQuests(activeMap) end
        return activeCount, completedCount, newlyImported, supported
    end
    return activeCount, CHARACTER_DATA.completedQuestImportCount or 0, 0, nil
end

local function GetItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    local id = string.match(link, "item:(%d+)")
    return id and tonumber(id) or nil
end

local function GetItemName(itemID, tooltipName)
    if type(tooltipName) == "string" and tooltipName ~= "" then return tooltipName end
    local name = SafeCall(C_Item and C_Item.GetItemName, itemID)
    if type(name) == "string" and name ~= "" then return name end
    name = SafeCall(GetItemInfo, itemID)
    return name or ("Item " .. tostring(itemID))
end

local function IsBankOpen()
    if BankFrame and type(BankFrame.IsShown) == "function" then
        return BankFrame:IsShown()
    end
    return false
end

local function CountItemInContainer(itemID, bagID)
    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemID) ~= "function" then
        return 0
    end
    local total = 0
    local slots = SafeCall(C_Container.GetContainerNumSlots, bagID) or 0
    for slot = 1, slots do
        local slotItemID = SafeCall(C_Container.GetContainerItemID, bagID, slot)
        if tonumber(slotItemID) == tonumber(itemID) then
            local info = SafeCall(C_Container.GetContainerItemInfo, bagID, slot)
            total = total + (info and tonumber(info.stackCount) or 1)
        end
    end
    return total
end

local function CountItemInventory(itemID)
    local bags, bank = 0, 0
    if not C_Container then return bags, bank end

    for bag = 0, (NUM_BAG_SLOTS or 4) do
        bags = bags + CountItemInContainer(itemID, bag)
    end

    -- The personal bank is only readable while the bank window is open.
    -- Classic/Forever uses container -1 for the main bank and bag IDs after
    -- the player's normal bags for purchased bank bags.
    if IsBankOpen() then
        bank = bank + CountItemInContainer(itemID, BANK_CONTAINER or -1)
        local firstBankBag = (NUM_BAG_SLOTS or 4) + 1
        local bankBagCount = NUM_BANKBAGSLOTS or 7
        for bag = firstBankBag, firstBankBag + bankBagCount - 1 do
            bank = bank + CountItemInContainer(itemID, bag)
        end
    end
    return bags, bank
end

local function AddAssociation(matches, questID, source, required)
    questID = tonumber(questID)
    if not questID or questID <= 0 then return end
    local entry = matches[questID]
    if not entry then
        entry = { questID = questID, sources = {}, required = nil }
        matches[questID] = entry
    end
    entry.sources[source] = true
    if type(required) == "number" and required > 0 then
        entry.required = math.max(entry.required or 0, required)
    end
end

local function IndexQuestItem(itemID, questID, source, required)
    itemID = tonumber(itemID)
    questID = tonumber(questID)
    if not itemID or itemID <= 0 or not questID or questID <= 0 then return end
    local row = itemQuestIndex[itemID]
    if not row then
        row = {}
        itemQuestIndex[itemID] = row
    end
    local entry = row[questID]
    if not entry then
        entry = { sources = {}, required = nil }
        row[questID] = entry
    end
    entry.sources[source] = true
    if type(required) == "number" and required > 0 then
        entry.required = math.max(entry.required or 0, required)
    end
end

local function QuestieDBReady()
    if type(LibQuestieDB) ~= "table" or type(LibQuestieDB.RequireContract) ~= "function" then
        return false, "QuestieDB data addon is not loaded"
    end
    local ok, message = SafeCall(LibQuestieDB.RequireContract, REQUIRED_DB_CONTRACT)
    if ok ~= true then
        return false, message or "QuestieDB contract mismatch"
    end
    if type(QuestDB) ~= "table" or type(QuestDB.GetAllIds) ~= "function"
        or type(QuestDB.objectives) ~= "function" then
        return false, "QuestieDB quest API is unavailable"
    end
    return true
end

-- Centralized QuestieDB item relations: full indexing and fast on-hover
-- lookup must agree, or quest items are missed depending on timing.
-- Only item-bearing quest data is indexed; generic item relations and rewards
-- aren't evidence that an item is required.
local function VisitQuestItemRelations(questID, add)
    local objectives = SafeCall(QuestDB and QuestDB.objectives, questID)
    if type(objectives) == "table" then
        local items = objectives[3]
        if type(items) == "table" then
            for _, row in ipairs(items) do
                if type(row) == "table" then
                    add(row[1], questID, "database objective", tonumber(row[3]))
                end
            end
        end
        local spells = objectives[6]
        if type(spells) == "table" then
            for _, row in ipairs(spells) do
                if type(row) == "table" then
                    -- Spell objective: { spellId, description, requiredItemId }.
                    add(row[3], questID, "database spell item", 1)
                end
            end
        end
    end

    local required = SafeCall(QuestDB and QuestDB.requiredSourceItems, questID)
    if type(required) == "table" then
        for _, itemID in ipairs(required) do
            add(itemID, questID, "database source item", 1)
        end
    end
    add(SafeCall(QuestDB and QuestDB.sourceItemId, questID),
        questID, "database provided item", 1)

    local starters = SafeCall(QuestDB and QuestDB.startedBy, questID)
    local starterItems = type(starters) == "table" and starters[3] or nil
    if type(starterItems) == "table" then
        for _, itemID in ipairs(starterItems) do
            add(itemID, questID, "database quest starter")
        end
    end

    -- Extra-objective references describe event links, not confirmed item
    -- requirements. Surface cautiously; do not claim NEEDED or SAFE.
    local extras = SafeCall(QuestDB and QuestDB.extraObjectives, questID)
    if type(extras) == "table" then
        for _, row in ipairs(extras) do
            local refs = type(row) == "table" and row[5] or nil
            if type(refs) == "table" then
                for _, reference in ipairs(refs) do
                    if type(reference) == "table" and reference[1] == "item" then
                        add(reference[2], questID, "database event item reference")
                    end
                end
            end
        end
    end
end

local function BuildQuestItemIndex()
    if dbIndexRunning or dbIndexReady then return end
    local ready, reason = QuestieDBReady()
    if not ready then
        Print("QuestieDB index not started: " .. tostring(reason))
        return
    end

    local ids = SafeCall(QuestDB.GetAllIds)
    if type(ids) ~= "table" then
        Print("QuestieDB could not provide quest IDs; keeping live quest detection enabled.")
        return
    end

    dbIndexRunning = true
    dbIndexReady = false
    dbIndexProcessed = 0
    dbIndexTotal = #ids
    itemQuestIndex = {}

    local cursor = 1
    local worker = CreateFrame("Frame")
    worker:Show()
    worker:SetScript("OnUpdate", function(self)
        local budget = 40
        while budget > 0 and cursor <= #ids do
            local questID = tonumber(ids[cursor])
            if questID then
                VisitQuestItemRelations(questID, IndexQuestItem)
            end
            cursor = cursor + 1
            dbIndexProcessed = dbIndexProcessed + 1
            budget = budget - 1
        end

        if cursor > #ids then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            dbIndexRunning = false
            dbIndexReady = true
            -- Index is ready; no player action or chat notification is needed.
        end
    end)
end

-- A fast, per-item lookup while the full reverse index is still warming up.
-- ItemDB.relatedQuests supplies candidate IDs, but some provider-given tools
-- have no reverse link. Always inspect the small active quest log as a fallback.
-- Every candidate must be confirmed against exact QuestDB item fields.
-- Never use this partial set to declare an item safe to delete.
-- Before indexing completes, inspect only reverse candidates, direct item
-- quest starters, and the player's active quests. Never scan all quests on hover.
local function LookupItemDuringIndex(itemID, activeMap)
    if not QuestieDBReady() then return nil end
    local matches, checked = {}, {}
    local candidateIDs = SafeCall(ItemDB and ItemDB.relatedQuests, itemID)
    local function CheckQuest(questID)
        questID = tonumber(questID)
        if not questID or questID <= 0 or checked[questID] then return end
        checked[questID] = true
        VisitQuestItemRelations(questID, function(id, quest, source, count)
            if tonumber(id) == itemID then
                AddAssociation(matches, quest, source, count)
            end
        end)
    end
    if type(candidateIDs) == "table" then
        for _, questID in ipairs(candidateIDs) do CheckQuest(questID) end
    end
    local starter = tonumber(SafeCall(ItemDB and ItemDB.startQuest, itemID))
    if starter and starter > 0 then
        AddAssociation(matches, starter, "database quest starter")
        CheckQuest(starter)
    end
    for questID in pairs(activeMap or {}) do CheckQuest(questID) end
    return next(matches) and matches or nil
end

-- ItemDB.questRewards establishes provenance, NOT an item requirement.
-- Only miscellaneous/quest-class reward items get source information here.
-- Ordinary gear rewards stay silent unless separately needed by a quest.
local function AddRewardProvenance(itemID, matches)
    local itemClass = tonumber(SafeCall(ItemDB and ItemDB.class, itemID))
    if itemClass ~= 12 and itemClass ~= 15 then return end
    if itemClass == 15 and tonumber(SafeCall(ItemDB and ItemDB.subClass, itemID)) ~= 0 then return end
    local rewardQuests = SafeCall(ItemDB and ItemDB.questRewards, itemID)
    if type(rewardQuests) ~= "table" then return end
    for _, rawQuestID in ipairs(rewardQuests) do
        local questID = tonumber(rawQuestID)
        local title = questID and SafeCall(QuestDB and QuestDB.name, questID)
        if questID and questID > 0 and type(title) == "string" and title ~= "" then
            AddAssociation(matches, questID, "database quest reward")
        end
    end
end

local function NativeBagQuestInfo(itemID, matches)
    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemID) ~= "function"
        or type(C_Container.GetContainerItemQuestInfo) ~= "function" then
        return
    end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = SafeCall(C_Container.GetContainerNumSlots, bag) or 0
        for slot = 1, slots do
            local slotID = SafeCall(C_Container.GetContainerItemID, bag, slot)
            if tonumber(slotID) == tonumber(itemID) then
                local qinfo = SafeCall(C_Container.GetContainerItemQuestInfo, bag, slot)
                if type(qinfo) == "table" and tonumber(qinfo.questID) and tonumber(qinfo.questID) > 0 then
                    AddAssociation(matches, qinfo.questID, "native bag metadata")
                end
            end
        end
    end
end

local function ActiveObjectiveMatches(itemName, active, matches)
    local lowerName = itemName and string.lower(itemName)
    if not lowerName or lowerName == "" then return end

    for questID, quest in pairs(active) do
        local knownEntry = matches[questID]
        for _, objective in ipairs(quest.objectives or {}) do
            local text = type(objective.text) == "string" and objective.text or ""
            local lowerText = string.lower(text)
            -- Require an exact item name, optionally followed by a quantity.
            -- Substrings and blank objective text produce false matches when
            -- a quest requires multiple items with similar names.
            -- Only accept exact item names or names followed by quantity
            -- delimiters when using the client's active objective as a fallback.
            local suffix = string.sub(lowerText, #lowerName + 1)
            local exactName = objective.type == "item"
                and string.sub(lowerText, 1, #lowerName) == lowerName
                and (suffix == "" or string.sub(suffix, 1, 1) == ":"
                    or string.match(suffix, "^%s+%d+%s*/%s*%d+"))
            if exactName then
                if not knownEntry then
                    AddAssociation(matches, questID, "active quest objective",
                        tonumber(objective.numRequired))
                    knownEntry = matches[questID]
                end
                knownEntry.sources["active quest objective"] = true
                knownEntry.detail = text
                knownEntry.fulfilled = tonumber(objective.numFulfilled)
                knownEntry.required = tonumber(objective.numRequired) or knownEntry.required
                knownEntry.finished = objective.finished
                break
            end
        end
    end
end

local function IsQuestRepeatableByID(questID)
    if SafeCall(C_QuestLog and C_QuestLog.IsRepeatableQuest, questID) == true
        or SafeCall(C_QuestLog and C_QuestLog.IsQuestReplayable, questID) == true then
        return true
    end
    -- The client may return false for unaccepted repeatables. QuestieDB's
    -- specialFlags lowest bit denotes a repeatable quest.
    local flags = tonumber(SafeCall(QuestDB and QuestDB.specialFlags, questID))
    return flags ~= nil and flags > 0 and flags % 2 == 1
end

local function GetQuestLevel(questID, activeInfo)
    if activeInfo and type(activeInfo.level) == "number" and activeInfo.level > 0 then
        return activeInfo.level
    end
    if type(QuestDB) == "table" and type(QuestDB.questLevel) == "function" then
        local level = SafeCall(QuestDB.questLevel, questID)
        if type(level) == "number" and level > 0 then return level end
    end
    if C_QuestLog and type(C_QuestLog.GetQuestDifficultyLevel) == "function" then
        local level = SafeCall(C_QuestLog.GetQuestDifficultyLevel, questID)
        if type(level) == "number" and level > 0 then return level end
    end
    return nil
end

-- An item that starts a quest is not the same as an item required DURING it.
-- requiredSourceItems and sourceItemId are quest uses, not starter items.
local function IsQuestStarterOnly(entry)
    local sources = (entry and entry.sources) or {}
    return sources["database quest starter"]
        and not (sources["database objective"] or sources["database source item"]
            or sources["database provided item"] or sources["database spell item"]
            or sources["active quest objective"] or sources["native bag metadata"])
end

local function IsInformationalOnly(entry)
    local sources = (entry and entry.sources) or {}
    return (sources["database event item reference"] or sources["database quest reward"])
        and not (sources["database quest starter"] or sources["database objective"]
            or sources["database source item"] or sources["database provided item"]
            or sources["database spell item"] or sources["active quest objective"]
            or sources["native bag metadata"])
end

local function GetQuestStatus(questID, matchesEntry, activeMap)
    local active = activeMap[questID]
    local record = DB.quests[questID]
    if IsInformationalOnly(matchesEntry) then
        if (matchesEntry.sources or {})["database quest reward"] then
            return "QUEST REWARD · FUTURE USE UNKNOWN", "|cff88ccff"
        end
        return "QUEST EVENT REFERENCE · REVIEW", "|cffffcc66"
    end
    local starterOnly = IsQuestStarterOnly(matchesEntry)
    if active and starterOnly then
        if IsRepeatableQuest(active) or IsQuestRepeatableByID(questID) then
            return "REPEATABLE — KEEP FOR NEXT TIME", "|cffffcc66"
        end
        return "QUEST STARTED · STARTER ITEM", "|cff66ccff"
    end
    if active then
        if active.isComplete then return "READY TO TURN IN", "|cffffd45c" end
        if IsRepeatableQuest(active) or IsQuestRepeatableByID(questID) then
            return "NEEDED · REPEATABLE", "|cff33ff66"
        end
        return "NEEDED NOW", "|cff33ff66"
    end
    if IsQuestRepeatableByID(questID) then
        if IsQuestCompleted(questID) then return "REPEATABLE · COMPLETED BEFORE", "|cffffcc66" end
        return "REPEATABLE QUEST", "|cffffcc66"
    end
    if IsQuestCompleted(questID) or (record and record.status == "completed") then
        return "COMPLETED", "|cff66ccff"
    end
    if starterOnly then return "STARTS QUEST", "|cffffcc66" end
    if record and record.status == "abandoned" then return "FUTURE USE · ABANDONED", "|cffffcc66" end
    local level = GetQuestLevel(questID)
    local trivial = IsTrivialQuest({ questID = questID, level = level })
    if trivial then return "FUTURE USE · GREY QUEST", "|cffc0c0c0" end
    return "FUTURE QUEST", "|cffffcc66"
end

local function QuestDBName(questID)
    local name = SafeCall(QuestDB and QuestDB.name, questID)
    if type(name) == "string" and name ~= "" then return name end
    return QuestTitle(questID)
end

local function RecordItem(itemID, itemName, matches)
    if not itemID then return end
    local record = DB.items[itemID] or {}
    record.itemID = itemID
    record.name = itemName or record.name
    record.lastSeen = Now()
    record.questIDs = record.questIDs or {}
    for questID in pairs(matches) do
        record.questIDs[questID] = true
    end
    DB.items[itemID] = record
end

local function AssessItemRetention(matches, activeMap)
    local confirmed, activeUse, futureUse, repeatableUse = false, false, false, false
    local activeStarter, uncertainUse, rewardOrigin, allCompleted = false, false, false, true

    for questID, entry in pairs(matches) do
        if IsInformationalOnly(entry) then
            -- Quest rewards and event references do not establish a requirement.
            if entry.sources["database quest reward"] then rewardOrigin = true end
            if entry.sources["database event item reference"] then uncertainUse = true end
        else
            confirmed = true
            local active = activeMap[questID]
            local completed = IsQuestCompleted(questID)
                or (DB.quests[questID] and DB.quests[questID].status == "completed")
            local repeatable = IsQuestRepeatableByID(questID)
                or (active and IsRepeatableQuest(active))
            local starterOnly = IsQuestStarterOnly(entry)
            local neededNow = active and not starterOnly
            if neededNow then activeUse = true end
            if repeatable then repeatableUse = true end
            if starterOnly and active and not repeatable and not completed then
                activeStarter = true
            end
            if (not completed and not (active and starterOnly))
                or repeatable or neededNow then
                allCompleted = false
                if not active and not repeatable then futureUse = true end
            end
        end
    end

    if activeUse then
        return "NEEDED — a current quest uses this item", "|cff33dd77", "needed"
    end
    if repeatableUse then
        return "KEEP — a repeatable quest can use this item", "|cffffcc66", "keep"
    end
    if futureUse then
        return "KEEP — another quest can use this item", "|cffffcc66", "keep"
    end
    if uncertainUse then
        return "REVIEW — referenced by a quest event; item need is unconfirmed", "|cffffcc66", "review"
    end
    if rewardOrigin then
        return "QUEST REWARD — future use is not confirmed", "|cff88ccff", "reward"
    end
    if activeStarter then
        return "QUEST STARTED — no longer needed to accept this quest", "|cff88ccff", "started"
    end
    if confirmed and allCompleted then
        return "SAFE TO DELETE — all known quests that use this item are completed", "|cff88ccff", "delete"
    end
    return nil, nil, "unknown"
end

local function GetTooltipItem(tooltip, data, explicitItemID)
    -- A bag setter supplies a trustworthy itemID even if the client did not
    -- populate GetItem() yet. The typed item callback supplies data.id.
    local explicit = tonumber(explicitItemID)
    if explicit and explicit > 0 then return explicit, nil end
    if type(data) == "table" then
        local dataID = tonumber(data.id) or tonumber(data.itemID)
        if dataID and dataID > 0 then return dataID, nil end
        local linkID = GetItemIDFromLink(data.hyperlink or data.itemLink)
        if linkID then return linkID, nil end
    end
    if tooltip and type(tooltip.GetItem) == "function" then
        local name, link = SafeCall(tooltip.GetItem, tooltip)
        local linkID = GetItemIDFromLink(link)
        if linkID then return linkID, name end
    end
    if tooltip and type(tooltip.GetPrimaryTooltipData) == "function" then
        local primary = SafeCall(tooltip.GetPrimaryTooltipData, tooltip)
        if type(primary) == "table" then
            local itemType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
            if not itemType or primary.type == itemType then
                local dataID = tonumber(primary.id) or tonumber(primary.itemID)
                if dataID and dataID > 0 then return dataID, nil end
                local linkID = GetItemIDFromLink(primary.hyperlink or primary.itemLink)
                if linkID then return linkID, nil end
            end
        end
    end
    return nil, nil
end

-- Keep the default tooltip focused on player-facing information; technical IDs are opt-in.
local DEFAULT_SETTINGS = {
    showQuestIDs = false,
    showItemIDs = false,
    suppressExternalIDs = false,
    showQuestLevels = true,
    showInventoryBreakdown = true,
    showFutureStatusLabels = false,
    filterByFaction = true,
}
local function SettingEnabled(key)
    local value = DB.settings[key]
    if value == nil then return DEFAULT_SETTINGS[key] == true end
    return value == true
end

-- This optional filter only touches isolated technical ID rows that another
-- addon put on a shared item tooltip. It never modifies QIT's own ID settings,
-- and stops at the QIT header so QIT-generated lines are left untouched.
-- Tooltip font strings are reused by WoW, so restore adjusted heights on reset.
local EXTERNAL_ID_KINDS = {
    itemid = true, iconid = true, questid = true, spellid = true,
    npcid = true, textureid = true, modelid = true,
}
local suppressedLineHeights = setmetatable({}, { __mode = "k" })

local function RestoreExternalIDHeights(tooltip)
    local stored = suppressedLineHeights[tooltip]
    if not stored then return end
    for fontString, height in pairs(stored) do
        if type(height) == "number" and height > 0 then
            SafeCall(fontString.SetHeight, fontString, height)
        end
    end
    suppressedLineHeights[tooltip] = nil
end

local function SuppressExternalTooltipIDs(tooltip)
    if not SettingEnabled("suppressExternalIDs") or not tooltip then return end
    -- Standard GameTooltip exposes named TextLeftN/TextRightN font strings.
    -- Do not guess at the internals of arbitrary custom tooltip frames.
    local name = SafeCall(tooltip.GetName, tooltip)
    local count = tonumber(SafeCall(tooltip.NumLines, tooltip))
    if type(name) ~= "string" or name == "" or not count then return end
    local stored = suppressedLineHeights[tooltip]
    for index = 1, math.min(count, 100) do
        local left = _G[name .. "TextLeft" .. index]
        local line = left and SafeCall(left.GetText, left)
        if type(line) == "string" and line ~= "" then
            if string.find(line, "Quest Item Tracker Forever", 1, true) then
                break
            end
            -- A full metadata row, not explanatory prose containing "item id".
            local clean = string.gsub(line, "|c%x%x%x%x%x%x%x%x", "")
            clean = string.gsub(clean, "|r", "")
            clean = string.gsub(clean, "^%s+", "")
            clean = string.gsub(clean, "%s+$", "")
            local label = string.match(clean, "^([%a%s]+)%s*:%s*%d*$")
                or string.match(clean, "^([%a%s]+)%s+%d+$")
                or string.match(clean, "^([%a%s]+)$")
            local normalized = label and string.lower(string.gsub(label, "%s+", ""))
            if normalized and EXTERNAL_ID_KINDS[normalized] then
                local right = _G[name .. "TextRight" .. index]
                stored = stored or {}
                for _, fontString in ipairs({left, right}) do
                    if fontString and type(fontString.SetText) == "function" then
                        local height = SafeCall(fontString.GetHeight, fontString)
                        if type(height) == "number" and height > 0 and stored[fontString] == nil then
                            stored[fontString] = height
                            SafeCall(fontString.SetHeight, fontString, 0)
                        end
                        SafeCall(fontString.SetText, fontString, "")
                    end
                end
            end
        end
    end
    if stored then suppressedLineHeights[tooltip] = stored end
end

-- QuestieDB exposes active-flavor faction race masks in contract 3+. Forever
-- masks include high bits (Skyborne), so WoW's 32-bit bit.band would truncate them.
-- Comparing one bit at a time preserves the full numeric mask in Lua doubles.
local function MasksIntersect(a, b)
    if type(a) ~= "number" or type(b) ~= "number" or a <= 0 or b <= 0 then
        return false
    end
    a, b = math.floor(a), math.floor(b)
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then return true end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
    end
    return false
end

local function QuestMatchesPlayerFaction(questID, activeMap)
    if not SettingEnabled("filterByFaction") then return true end
    -- A currently accepted quest is always relevant, even if its DB flags lag.
    if activeMap and activeMap[questID] then return true end

    local faction = SafeCall(UnitFactionGroup, "player")
    if faction ~= "Alliance" and faction ~= "Horde" then return true end
    local enum = LibQuestieDB and LibQuestieDB.Enum
    local factionMasks = enum and enum.factionRaceMasks
    local allowedMask = factionMasks and factionMasks[faction]
    if type(allowedMask) ~= "number" or allowedMask <= 0 then return true end

    local required = SafeCall(QuestDB and QuestDB.requiredRaces, questID)
    -- Unrestricted (0) or missing data means the quest may be neutral. Don't
    -- hide unknowns: only filter quests explicitly excluded by the race mask.
    if type(required) ~= "number" or required <= 0 then return true end
    return MasksIntersect(required, allowedMask)
end

local optionsPanel
local minimapButton
local questieDBStatusLight
local QIT_ICON_TEXTURE = "Interface\\AddOns\\QuestItemTracker\\Media\\QITIcon"
local QIT_STATUS_TEXTURE = "Interface\\AddOns\\QuestItemTracker\\Media\\StatusCircle"

local function SetSolidColor(texture, r, g, b, a)
    if type(texture.SetColorTexture) == "function" then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

-- Save the panel's center as offsets from UIParent, rather than absolute
-- screen coordinates. This survives /reload and ordinary UI-scale changes.
-- Missing or invalid SavedVariables fall back to the original centered layout.
local function RestoreOptionsPanelPosition(panel)
    local position = DB.settings.optionsPanelPosition
    local x = type(position) == "table" and tonumber(position.x) or nil
    local y = type(position) == "table" and tonumber(position.y) or nil
    if not x or x ~= x or math.abs(x) > 10000 or
        not y or y ~= y or math.abs(y) > 10000 then
        x, y = 0, 45
    end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function SaveOptionsPanelPosition(panel)
    local cx, cy = SafeCall(panel.GetCenter, panel)
    local ux, uy = SafeCall(UIParent and UIParent.GetCenter, UIParent)
    if type(cx) ~= "number" or type(cy) ~= "number" or
        type(ux) ~= "number" or type(uy) ~= "number" then return end

    local panelScale = SafeCall(panel.GetEffectiveScale, panel) or 1
    local parentScale = SafeCall(UIParent.GetEffectiveScale, UIParent) or 1
    if type(panelScale) ~= "number" or type(parentScale) ~= "number" or
        panelScale <= 0 or parentScale <= 0 then return end

    -- GetCenter values are in each frame's own scale. Convert to parent units
    -- before storing offsets for SetPoint relative to UIParent's center.
    local x = (cx * panelScale - ux * parentScale) / parentScale
    local y = (cy * panelScale - uy * parentScale) / parentScale
    if x == x and y == y and math.abs(x) <= 10000 and math.abs(y) <= 10000 then
        DB.settings.optionsPanelPosition = { x = x, y = y }
    end
end

-- CurseForge declares QuestieDB as REQUIRED for automatic installation.
-- The WoW TOC uses OptionalDeps instead, because a hard dependency would stop
-- QIT itself from loading when a manual ZIP user forgets QuestieDB; that would
-- make the missing-dependency warning impossible to show.
local function QuestieDBStatus()
    local ready, detail = QuestieDBReady()
    if ready then
        return true, "Quest Item Tracker Forever is ready",
            "QuestieDB: Installed and enabled. It provides the quest information QITF needs."
    end

    local exists = SafeCall(C_AddOns and C_AddOns.DoesAddOnExist, "QuestieDB")
    -- Older client versions may lack DoesAddOnExist; the reason from
    -- GetAddOnInfo distinguishes a missing folder from a disabled addon.
    local reason
    local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if type(getInfo) == "function" then
        local ok, _, _, _, _, infoReason = pcall(getInfo, "QuestieDB")
        if ok then reason = infoReason end
    end

    if exists == false or reason == "MISSING" then
        return false, "Quest Item Tracker Forever needs attention",
            "QuestieDB: Not installed. QITF needs QuestieDB to find quest items. "
                .. "CurseForge normally installs it for you. If you installed QITF "
                .. "from GitHub, install QuestieDB too, then restart or reload WoW."
    end

    local state = SafeCall(C_AddOns and C_AddOns.GetAddOnEnableState, "QuestieDB")
    if state == nil then state = SafeCall(GetAddOnEnableState, "QuestieDB") end
    if reason == "DISABLED" or state == 0 or state == false then
        return false, "Quest Item Tracker Forever needs attention",
            "QuestieDB: Installed but disabled in WoW. "
                .. "Enable QuestieDB in the AddOns list, then reload or restart the game."
    end

    local loaded = SafeCall(C_AddOns and C_AddOns.IsAddOnLoaded, "QuestieDB")
    if loaded == nil then loaded = SafeCall(IsAddOnLoaded, "QuestieDB") end
    if loaded == false then
        return false, "Quest Item Tracker Forever needs attention",
            "QuestieDB: Installed but not loaded. "
                .. "Check that it is enabled in the AddOns list and restart or reload WoW."
    end

    return false, "Quest Item Tracker Forever needs attention",
        "QuestieDB: Not ready. It's not providing the quest information QITF needs. "
            .. "Make sure you have a compatible version installed and enabled, "
            .. "then reload WoW. " .. tostring(detail or "")
end

local function UpdateQuestieDBStatusLight()
    if not questieDBStatusLight then return end
    local dot = questieDBStatusLight.dot
    if not dot or type(dot.SetVertexColor) ~= "function" then return end
    local ready = QuestieDBStatus()
    -- This is a real circular texture with a transparent background. Font
    -- symbols like "●" can become empty squares in Forever's UI font.
    dot:SetVertexColor(
        ready and 0.24 or 1,
        ready and 0.92 or 0.28,
        ready and 0.45 or 0.28,
        1
    )
end

local function CreateOptionsPanel()
    if optionsPanel then return optionsPanel end
    if not UIParent or type(CreateFrame) ~= "function" then return nil end

    local panel = CreateFrame("Frame", "QITOptionsPanel", UIParent)
    panel:SetSize(360, 454)
    RestoreOptionsPanelPosition(panel)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveOptionsPanelPosition(self)
    end)

    -- Restrained Warcraft-style frame: warm charcoal, aged-gold trim,
    -- and a quiet title band. Keep native WoW controls (checkboxes, reset,
    -- close) so other UI packs can still restyle their normal templates.
    local border = panel:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    SetSolidColor(border, 0.42, 0.33, 0.20, 0.98)
    local background = panel:CreateTexture(nil, "BORDER")
    background:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
    SetSolidColor(background, 0.055, 0.052, 0.047, 0.98)

    local headerBand = panel:CreateTexture(nil, "ARTWORK")
    headerBand:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    headerBand:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    headerBand:SetHeight(43)
    SetSolidColor(headerBand, 0.125, 0.101, 0.072, 0.96)

    local stripe = panel:CreateTexture(nil, "ARTWORK")
    stripe:SetHeight(2)
    stripe:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -45)
    stripe:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -45)
    SetSolidColor(stripe, 0.66, 0.48, 0.25, 0.94)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
    title:SetText("Quest Item Tracker Forever")
    if type(title.SetTextColor) == "function" then
        title:SetTextColor(1, 0.82, 0.41, 1)
    end
    local version = AddonVersion()
    if version then
        local versionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        versionLabel:SetPoint("LEFT", title, "RIGHT", 8, -2)
        versionLabel:SetText("v" .. version)
        if type(versionLabel.SetTextColor) == "function" then
            versionLabel:SetTextColor(0.62, 0.58, 0.49, 1)
        end
    end
    local subTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -58)
    subTitle:SetText("Tooltip preferences  |  Saved automatically")
    if type(subTitle.SetTextColor) == "function" then
        subTitle:SetTextColor(0.79, 0.75, 0.67, 1)
    end

    -- Only a small green/red dot, not another label or block in the menu.
    -- Hovering it explains whether QuestieDB is working and what to fix.
    local statusLight = CreateFrame("Button", "QITQuestieDBStatus", panel)
    statusLight:SetSize(20, 20)
    statusLight:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -19, -52)
    statusLight:EnableMouse(true)
    local dot = statusLight:CreateTexture(nil, "ARTWORK")
    dot:SetSize(18, 18)
    dot:SetPoint("CENTER", statusLight, "CENTER", 0, 0)
    dot:SetTexture(QIT_STATUS_TEXTURE)
    statusLight.dot = dot
    questieDBStatusLight = statusLight
    statusLight:SetScript("OnEnter", function(self)
        if not GameTooltip or type(GameTooltip.SetOwner) ~= "function"
            or type(GameTooltip.SetText) ~= "function"
            or type(GameTooltip.AddLine) ~= "function" then return end
        local ready, title, explanation = QuestieDBStatus()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, ready and 0.28 or 1, ready and 0.9 or 0.3, ready and 0.4 or 0.3)
        GameTooltip:AddLine(explanation, 0.95, 0.95, 0.95, true)
        GameTooltip:Show()
    end)
    statusLight:SetScript("OnLeave", function(self)
        if GameTooltip and type(GameTooltip.GetOwner) == "function"
            and GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
    UpdateQuestieDBStatusLight()

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() panel:Hide() end)

    -- Keep the menu labels short. Hover over any option to understand its
    -- effect in everyday language; the item tooltip itself stays uncluttered.
    local entries = {
        {
            key = "filterByFaction", label = "Only show my faction quests", y = -87,
            help = "Show quests meant for your faction, along with neutral quests. "
                .. "Quests marked for the opposite faction are hidden. "
                .. "Quests you're already working on still appear.",
        },
        {
            key = "suppressExternalIDs", label = "Hide IDs from other addons", y = -154,
            help = "Hide extra number-only details, such as ItemID and IconID, "
                .. "that other addons put on item tooltips. "
                .. "This is off by default and does not change the other addons' settings "
                .. "or hide IDs shown by QIT.",
        },
        {
            key = "showQuestIDs", label = "Show QIT quest IDs", y = -190,
            help = "Show the identifying number for each quest listed by QIT. "
                .. "For example, you can use a quest ID to identify a particular quest "
                .. "when asking for help. This does not control IDs from other addons.",
        },
        {
            key = "showItemIDs", label = "Show QIT item IDs", y = -226,
            help = "Show the item's identifying number inside QIT's section of "
                .. "the tooltip. This can help when reporting an item problem. "
                .. "Other addons' ItemID lines are controlled by the option above.",
        },
        {
            key = "showQuestLevels", label = "Show quest levels", y = -285,
            help = "Show each quest's level next to its name, such as Level 60. "
                .. "Turn this off for shorter quest names without changing which quests appear.",
        },
        {
            key = "showInventoryBreakdown", label = "Show bag / bank breakdown", y = -321,
            help = "Show how many copies of an item are in your bags and bank, "
                .. "next to the total you have. Turn this off to see just the total; "
                .. "QIT still counts your items.",
        },
        {
            key = "showFutureStatusLabels", label = "Show future quest labels", y = -357,
            help = "Add extra explanations for quests you could do later, "
                .. "such as FUTURE QUEST, plus a summary when an item has only future uses. "
                .. "Leaving this off keeps the tooltip shorter without removing "
                .. "important KEEP or NEEDED advice.",
        },
    }
    local idsHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    idsHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -132)
    idsHeading:SetText("ID DISPLAY")
    if type(idsHeading.SetTextColor) == "function" then idsHeading:SetTextColor(0.82, 0.65, 0.38, 1) end
    local detailsHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailsHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -263)
    detailsHeading:SetText("OTHER DETAILS")
    if type(detailsHeading.SetTextColor) == "function" then detailsHeading:SetTextColor(0.82, 0.65, 0.38, 1) end
    local checkboxes = {}
    for i, entry in ipairs(entries) do
        local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        checkbox:SetSize(25, 25)
        checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, entry.y)
        checkbox:SetChecked(SettingEnabled(entry.key))
        -- Expand the checkbox's mouse area across its text, so hovering
        -- anywhere on the option shows its help and clicking text works too.
        if type(checkbox.SetHitRectInsets) == "function" then
            checkbox:SetHitRectInsets(0, -255, 0, 0)
        end
        checkbox:SetScript("OnEnter", function(self)
            if not GameTooltip or type(GameTooltip.SetOwner) ~= "function"
                or type(GameTooltip.SetText) ~= "function"
                or type(GameTooltip.AddLine) ~= "function" then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.label, 0.92, 0.77, 0.49)
            GameTooltip:AddLine(entry.help, 0.95, 0.95, 0.95, true)
            GameTooltip:Show()
        end)
        checkbox:SetScript("OnLeave", function(self)
            if GameTooltip and type(GameTooltip.GetOwner) == "function"
                and GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end)
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
        label:SetText(entry.label)
        checkbox:SetScript("OnClick", function(self)
            DB.settings[entry.key] = self:GetChecked() == true
        end)
        checkboxes[#checkboxes + 1] = { frame = checkbox, key = entry.key }
    end

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(125, 24)
    reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 19)
    reset:SetText("Reset defaults")
    reset:SetScript("OnClick", function()
        for key, value in pairs(DEFAULT_SETTINGS) do DB.settings[key] = value end
        DB.settings.optionsPanelPosition = nil
        RestoreOptionsPanelPosition(panel)
        for _, row in ipairs(checkboxes) do
            row.frame:SetChecked(SettingEnabled(row.key))
        end
    end)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -17, 23)
    hint:SetText("Changes apply on next hover")
    if type(hint.SetTextColor) == "function" then
        hint:SetTextColor(0.63, 0.60, 0.54, 1)
    end
    panel:SetScript("OnShow", function()
        UpdateQuestieDBStatusLight()
        for _, row in ipairs(checkboxes) do
            row.frame:SetChecked(SettingEnabled(row.key))
        end
    end)
    panel:Hide()
    optionsPanel = panel
    return panel
end

local function ToggleOptionsPanel()
    local panel = CreateOptionsPanel()
    if not panel then
        Print("Settings UI is unavailable. The minimap may not be initialized yet.")
        return
    end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

local function PlaceMinimapButton()
    if not minimapButton or not Minimap then return end
    local x = tonumber(DB.settings.minimapX) or 75
    local y = tonumber(DB.settings.minimapY) or -28
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    if minimapButton or not Minimap or type(CreateFrame) ~= "function" then return end
    local button = CreateFrame("Button", "QITMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture(QIT_ICON_TEXTURE)
    if type(icon.SetTexCoord) == "function" then icon:SetTexCoord(0, 1, 0, 1) end
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("CENTER", button, "CENTER", 10, -10)

    button:SetScript("OnClick", ToggleOptionsPanel)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Quest Item Tracker Forever", 0.4, 0.8, 1)
        GameTooltip:AddLine("Click: tooltip settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move minimap button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip and type(GameTooltip.Hide) == "function" then GameTooltip:Hide() end
    end)
    button:SetScript("OnDragStart", function(self) self:StartMoving() end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local centerX, centerY = Minimap:GetCenter()
        if x and y and centerX and centerY then
            local dx, dy = x - centerX, y - centerY
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > 0 then
                -- Snap to the minimap rim, and remember placement on relog.
                DB.settings.minimapX = math.floor(dx / distance * 80 + 0.5)
                DB.settings.minimapY = math.floor(dy / distance * 80 + 0.5)
            end
        end
        PlaceMinimapButton()
    end)
    minimapButton = button
    PlaceMinimapButton()
end

local function AddTooltipLines(tooltip, data, explicitItemID)
    if not tooltip or type(tooltip.AddLine) ~= "function" then return false end
    local itemID, itemName = GetTooltipItem(tooltip, data, explicitItemID)
    if not itemID then return false end
    if decoratedTooltips[tooltip] == itemID then return true end

    -- Merge verified quest uses from the index, fast candidates, and native
    -- active quest data before evaluating KEEP/DELETE. A missing reverse link
    -- does not prove that an item has no quest uses.
    local activeMap = GetActiveQuestMap()
    local indexed = itemQuestIndex[itemID]
    local partial = not dbIndexReady
    local matches = {}
    if type(indexed) == "table" then
        for questID, entry in pairs(indexed) do
            for source in pairs(entry.sources or {}) do
                AddAssociation(matches, questID, source, entry.required)
            end
        end
    end
    if partial then
        local early = LookupItemDuringIndex(itemID, activeMap)
        for questID, entry in pairs(early or {}) do
            for source in pairs(entry.sources or {}) do
                AddAssociation(matches, questID, source, entry.required)
            end
        end
    end

    -- ItemDB.startQuest is a direct, documented lookup even if QuestDB's
    -- startedBy[3] reverse link is absent.
    local startQuest = tonumber(SafeCall(ItemDB and ItemDB.startQuest, itemID))
    if startQuest and startQuest > 0 then
        AddAssociation(matches, startQuest, "database quest starter")
    end
    -- Reward links exist on ItemDB rather than QuestDB. Show only provenance.
    AddRewardProvenance(itemID, matches)

    local itemNameResolved = GetItemName(itemID, itemName)
    ActiveObjectiveMatches(itemNameResolved, activeMap, matches)

    -- Always consider native bag metadata: one item may belong to multiple
    -- active quests, including a custom quest absent from QuestieDB. Only
    -- accept the native quest ID if the player's live quest log confirms it.
    local native = {}
    NativeBagQuestInfo(itemID, native)
    for questID in pairs(native) do
        if activeMap[questID] then
            AddAssociation(matches, questID, "native bag metadata")
        end
    end

    -- Filter before displaying quests AND before the retention recommendation.
    -- An Alliance-only quest must not make a Horde player keep a useless item.
    for questID in pairs(matches) do
        if not QuestMatchesPlayerFaction(questID, activeMap) then
            matches[questID] = nil
        end
    end
    if not next(matches) then return false end

    local bags, bank = CountItemInventory(itemID)
    local totalHave = bags + bank
    local ids, names = {}, {}
    for questID in pairs(matches) do
        ids[#ids + 1] = questID
        names[questID] = string.lower((activeMap[questID] and activeMap[questID].title)
            or QuestDBName(questID))
    end
    table.sort(ids, function(a, b)
        if names[a] == names[b] then return a < b end
        return names[a] < names[b]
    end)

    RecordItem(itemID, itemNameResolved, matches)
    -- Mark this tooltip before rendering: Show() may invoke tooltip hooks again.
    decoratedTooltips[tooltip] = itemID

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff66ccffQuest Item Tracker Forever|r")
    if SettingEnabled("showItemIDs") then
        tooltip:AddLine("Item ID: " .. itemID, 0.75, 0.75, 0.75)
    end
    if SettingEnabled("showInventoryBreakdown") then
        tooltip:AddLine("Have " .. totalHave .. "  (Bags: " .. bags .. " | Bank: " .. bank .. ")", 0.75, 0.9, 0.75)
    else
        tooltip:AddLine("Have " .. totalHave, 0.75, 0.9, 0.75)
    end

    local recommendation, recommendationColor = AssessItemRetention(matches, activeMap)
    -- Before the scan completes, this list can be incomplete: don't promise
    -- the item is disposable or that no future use exists.
    if partial and recommendation and string.find(recommendation, "SAFE TO DELETE", 1, true) then
        recommendation = nil
    end
    if recommendation then
        tooltip:AddLine(recommendationColor .. recommendation .. "|r", 0.9, 0.9, 0.9, true)
    end

    -- Build a display-only layout from the already-filtered matches. Grouped
    -- headings avoid repeating the same REPEATABLE / GREY label per quest.
    -- Retention and per-quest status calculations above remain authoritative.
    local activeCount, futureCount, completedCount = 0, 0, 0
    local ordinaryQuests, repeatableQuests, lowLevelQuests, factionTurnIns = {}, {}, {}, {}
    for _, questID in ipairs(ids) do
        local entry = matches[questID]
        local active = activeMap[questID]
        local status, color = GetQuestStatus(questID, entry, activeMap)

        -- Informational reward/event links do not count as future quest USES.
        if not IsInformationalOnly(entry) then
            if active and not IsQuestStarterOnly(entry) then
                activeCount = activeCount + 1
            elseif IsQuestRepeatableByID(questID) or not IsQuestCompleted(questID) then
                futureCount = futureCount + 1
            else
                completedCount = completedCount + 1
            end
        end

        local row = {
            id = questID,
            entry = entry,
            name = (active and active.title) or QuestDBName(questID),
            level = GetQuestLevel(questID, active),
            status = status,
            color = color,
            rewardOrigin = IsInformationalOnly(entry)
                and (entry.sources or {})["database quest reward"],
        }
        if not IsInformationalOnly(entry) and
            (IsQuestRepeatableByID(questID) or (active and IsRepeatableQuest(active))) then
            repeatableQuests[#repeatableQuests + 1] = row
        elseif status == "FUTURE USE · GREY QUEST" then
            lowLevelQuests[#lowLevelQuests + 1] = row
        elseif not IsInformationalOnly(entry) and
            string.find(row.name, "^A Donation of ") then
            -- City cloth quartermasters share donation titles across faction quests.
            factionTurnIns[#factionTurnIns + 1] = row
        else
            ordinaryQuests[#ordinaryQuests + 1] = row
        end
    end

    local showIDs = SettingEnabled("showQuestIDs")
    local showFuture = SettingEnabled("showFutureStatusLabels")
    local showLevels = SettingEnabled("showQuestLevels")

    -- Multiple distinct faction/city quests can share the same title and level
    -- (for example five separate "A Donation of Wool" quests). Compact only
    -- equivalent presentation rows; never merge underlying IDs, statuses,
    -- requirements or retention/matching decisions.
    local function CompactQuestRows(rows)
        local compact, byKey = {}, {}
        for _, row in ipairs(rows) do
            local entry = row.entry or {}
            local key = table.concat({
                row.name or "",
                tostring(row.level or ""),
                row.status or "",
                row.color or "",
                row.rewardOrigin and "reward" or "ordinary",
                tostring(entry.required or ""),
                tostring(entry.detail or ""),
            }, "\031")
            local existing = byKey[key]
            if existing then
                existing.ids[#existing.ids + 1] = row.id
            else
                row.ids = { row.id }
                compact[#compact + 1] = row
                byKey[key] = row
            end
        end
        return compact
    end

    local function ShowQuestRow(row, grouped)
        local indent = grouped and "    " or "  "
        local nameIndent = grouped and "  " or ""
        local nameLine = nameIndent .. row.color
            .. (row.rewardOrigin and "Reward from: " or "") .. row.name .. "|r"
        if showLevels then
            nameLine = nameLine .. "  (" .. (row.level and ("Level " .. row.level) or "Level unknown") .. ")"
        end
        if #row.ids > 1 then
            nameLine = nameLine .. "  |cff95a9b8(" .. #row.ids .. " quests)|r"
        end
        tooltip:AddLine(nameLine)

        local status = row.status
        if grouped == "repeatable" then
            -- The heading already tells the player these quests repeat.
            if status == "REPEATABLE QUEST" then
                status = nil
            elseif status == "REPEATABLE · COMPLETED BEFORE" then
                status = showFuture and "COMPLETED BEFORE" or nil
            elseif status == "NEEDED · REPEATABLE" then
                status = "NEEDED NOW"
            elseif status == "REPEATABLE — KEEP FOR NEXT TIME" then
                status = "KEEP FOR NEXT TIME"
            end
        elseif grouped == "lowLevel" and status == "FUTURE USE · GREY QUEST" then
            -- One low-level heading replaces every repeated GREY QUEST line.
            status = nil
        end
        -- Future status lines remain opt-in; essential active states remain.
        if not showFuture then
            if status == "FUTURE USE · GREY QUEST" then
                status = "GREY QUEST"
            elseif status == "FUTURE QUEST" or status == "FUTURE USE · ABANDONED" then
                status = nil
            end
        end
        if status or showIDs then
            local statusLine = status and (indent .. status) or indent
            if showIDs then
                local idsText = #row.ids > 1
                    and ("Quest IDs: " .. table.concat(row.ids, ", "))
                    or ("Quest ID: " .. row.id)
                statusLine = statusLine .. (status and "  |  " or "") .. idsText
            end
            tooltip:AddLine(statusLine, 0.78, 0.78, 0.78)
        end

        local entry = row.entry
        if entry.required and entry.required > 0 and not IsInformationalOnly(entry) then
            tooltip:AddLine(indent .. "Have " .. totalHave .. " / Need " .. entry.required, 0.75, 0.9, 0.75)
        elseif entry.detail then
            tooltip:AddLine(indent .. entry.detail, 0.7, 0.7, 0.7, true)
        end
    end

    for _, row in ipairs(CompactQuestRows(ordinaryQuests)) do ShowQuestRow(row, nil) end
    if #factionTurnIns > 0 then
        tooltip:AddLine("FACTION TURN-INS", 0.4, 0.78, 1)
        for _, row in ipairs(CompactQuestRows(factionTurnIns)) do ShowQuestRow(row, "faction") end
    end
    if #repeatableQuests > 0 then
        tooltip:AddLine("REPEATABLE QUESTS", 0.4, 0.78, 1)
        for _, row in ipairs(CompactQuestRows(repeatableQuests)) do ShowQuestRow(row, "repeatable") end
    end
    if #lowLevelQuests > 0 then
        tooltip:AddLine("LOW-LEVEL QUESTS", 0.6, 0.72, 0.84)
        for _, row in ipairs(CompactQuestRows(lowLevelQuests)) do ShowQuestRow(row, "lowLevel") end
    end

    if partial then
        tooltip:AddLine("Checking remaining quests...", 0.7, 0.8, 1, true)
    elseif activeCount == 0 and futureCount > 0 and SettingEnabled("showFutureStatusLabels") then
        tooltip:AddLine("No current quest needs this item; it has future quest uses.", 0.9, 0.8, 0.55, true)
    elseif activeCount == 0 and futureCount == 0 and completedCount > 0 then
        tooltip:AddLine("No remaining known quest uses.", 0.65, 0.85, 1, true)
    end
    if type(tooltip.Show) == "function" then tooltip:Show() end
    return true
end

local function RunTooltipHook(tooltip, data, explicitItemID)
    local ok, err = pcall(AddTooltipLines, tooltip, data, explicitItemID)
    -- Most bag addons place ID rows before the QIT section. Handle them even
    -- when the item has no quest associations and QIT adds no lines.
    SuppressExternalTooltipIDs(tooltip)
    if not ok and not tooltipErrorReported then
        tooltipErrorReported = true
        Print("Tooltip error (first occurrence): " .. tostring(err))
    end
end

local function HookTooltipFrame(tooltip)
    if not tooltip then return false end
    local hooked = false
    if type(tooltip.HookScript) == "function" then
        -- Both legacy and typed hooks can exist in Forever. Register BOTH:
        -- some bag UI implementations use only one of the two mechanisms.
        local ok = pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(self)
            RunTooltipHook(self)
        end)
        if ok then hooked = true; hookStats.legacy = true end

        pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", function(self)
            decoratedTooltips[self] = nil
            RestoreExternalIDHeights(self)
        end)
        pcall(tooltip.HookScript, tooltip, "OnHide", function(self)
            decoratedTooltips[self] = nil
            RestoreExternalIDHeights(self)
        end)
        ok = pcall(tooltip.HookScript, tooltip, "OnShow", function(self)
            RunTooltipHook(self)
        end)
        if ok then hooked = true end
        -- Third-party tooltip callbacks can append IDs after our callbacks;
        -- recheck only while the opt-in setting is enabled.
        pcall(tooltip.HookScript, tooltip, "OnUpdate", function(self)
            SuppressExternalTooltipIDs(self)
        end)
    end

    -- Certain inventory addons use setter methods without publishing a typed
    -- tooltip item or a legacy item script. Securely hook the bag/item setters
    -- to obtain the actual item ID even when tooltip:GetItem() is empty.
    if type(hooksecurefunc) == "function" then
        -- Custom bag UIs may reuse a visible tooltip and call ClearLines()
        -- without hiding it or firing OnTooltipCleared.
        if type(tooltip.ClearLines) == "function" then
            pcall(hooksecurefunc, tooltip, "ClearLines", function(self)
                decoratedTooltips[self] = nil
                RestoreExternalIDHeights(self)
            end)
        end
        if type(tooltip.SetBagItem) == "function" then
            local ok = pcall(hooksecurefunc, tooltip, "SetBagItem", function(self, bag, slot)
                local id = SafeCall(C_Container and C_Container.GetContainerItemID, bag, slot)
                RunTooltipHook(self, nil, id)
            end)
            if ok then hooked = true; hookStats.setters = hookStats.setters + 1 end
        end
        if type(tooltip.SetHyperlink) == "function" then
            local ok = pcall(hooksecurefunc, tooltip, "SetHyperlink", function(self, link)
                RunTooltipHook(self, nil, GetItemIDFromLink(link))
            end)
            if ok then hooked = true; hookStats.setters = hookStats.setters + 1 end
        end
        if type(tooltip.SetItemByID) == "function" then
            local ok = pcall(hooksecurefunc, tooltip, "SetItemByID", function(self, id)
                RunTooltipHook(self, nil, id)
            end)
            if ok then hooked = true; hookStats.setters = hookStats.setters + 1 end
        end
    end
    return hooked
end

local function InstallTooltipHook()
    if tooltipHooked then return true end
    local hooked = false
    if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        local ok = pcall(TooltipDataProcessor.AddTooltipPostCall,
            Enum.TooltipDataType.Item,
            function(tooltip, tooltipData)
                RunTooltipHook(tooltip, tooltipData)
            end)
        if ok then hooked = true; hookStats.typed = true end
    end

    if HookTooltipFrame(GameTooltip) then hooked = true end
    if ItemRefTooltip ~= GameTooltip and HookTooltipFrame(ItemRefTooltip) then hooked = true end
    tooltipHooked = hooked
    return hooked
end

local function ScanBags()
    Print("Scanning quest-item bag metadata...")
    local count = 0
    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemID) ~= "function" then
        Print("Container API unavailable.")
        return
    end

    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = SafeCall(C_Container.GetContainerNumSlots, bag) or 0
        for slot = 1, slots do
            local itemID = SafeCall(C_Container.GetContainerItemID, bag, slot)
            if itemID then
                local qinfo = SafeCall(C_Container.GetContainerItemQuestInfo, bag, slot)
                if type(qinfo) == "table" and (qinfo.isQuestItem or qinfo.questID) then
                    count = count + 1
                    local name = GetItemName(itemID)
                    local matches = {}
                    NativeBagQuestInfo(itemID, matches)
                    local idx = itemQuestIndex[tonumber(itemID)]
                    if type(idx) == "table" then
                        for questID, entry in pairs(idx) do
                            AddAssociation(matches, questID, "database item objective", entry.required)
                        end
                    end
                    RecordItem(itemID, name, matches)
                    Print(string.format("%s (item %d): quest item; native questID=%s",
                        name or ("Item " .. itemID), itemID, tostring(qinfo.questID)))
                end
            end
        end
    end
    Print("Quest-item slots found: " .. count)
end

local function ShowHistory(filter)
    SyncQuestHistory(true)
    local shown = 0
    Print("Quest history (local events plus imported completed-quest snapshot):")
    Print("Imported completed quest records: " .. tostring(CHARACTER_DATA and CHARACTER_DATA.completedQuestImportCount or 0)
        .. " | Last snapshot: " .. tostring(CHARACTER_DATA and CHARACTER_DATA.completedQuestImportAt or "not imported"))
    for _, event in ipairs(DB.events or {}) do
        local haystack = string.lower(tostring(event.kind or "") .. " " .. tostring(event.title or ""))
        if not filter or string.find(haystack, filter, 1, true) then
            Print(string.format("%s | %s | %s (ID: %s)",
                event.time or "unknown date", event.kind or "event",
                event.title or "Unknown", tostring(event.questID or "?")))
            shown = shown + 1
            if shown >= MAX_HISTORY_LINES then break end
        end
    end
    if shown == 0 then Print("No recorded local events yet. Older event dates cannot be reconstructed.") end
    local n = 0
    for _ in pairs(DB.quests or {}) do n = n + 1 end
    Print("Tracked quest records: " .. tostring(n))
end

local function ListCompletedQuests(filter)
    SyncQuestHistory(true)
    local rows = {}
    local needle = filter and string.lower(filter) or nil

    for id, record in pairs(DB.quests or {}) do
        if record.status == "completed" then
            local title = record.title or QuestTitle(id)
            if not needle or string.find(string.lower(title), needle, 1, true) then
                rows[#rows + 1] = {
                    id = tonumber(id) or id,
                    title = title,
                    completedAt = record.completedAt,
                    imported = record.importedCompleted,
                }
            end
        end
    end

    table.sort(rows, function(a, b)
        return string.lower(a.title) < string.lower(b.title)
    end)

    Print("Completed quests for this character: " .. #rows)
    for _, row in ipairs(rows) do
        local when = row.completedAt or (row.imported and "date unknown (imported)" or "date unknown")
        Print(string.format("%s (ID: %s) — %s", row.title, tostring(row.id), when))
    end
    if #rows == 0 then Print("No completed quest records found. Try /qit import.") end
end

local function ListQuests()
    SyncQuestHistory(false)
    local active = GetActiveQuestMap()
    local count = 0
    for id, quest in pairs(active) do
        count = count + 1
        local flags = {}
        if IsTrivialQuest(quest) then flags[#flags + 1] = "GREY"
        end
        if IsRepeatableQuest(quest) then flags[#flags + 1] = "REPEATABLE" end
        Print(string.format("%s (ID: %d) %s", quest.title, id,
            #flags > 0 and "[" .. table.concat(flags, ", ") .. "]" or ""))
    end
    Print("Active quests: " .. count)
end

local function HandleQuestAccepted(a, b)
    -- QUEST_ACCEPTED normally passes (questLogIndex, questID).
    local questID = tonumber(b) or tonumber(a)
    if not questID then return end
    local title = QuestTitle(questID)
    local record = DB.quests[questID] or {}
    record.questID = questID
    record.title = title
    record.firstSeen = record.firstSeen or Now()
    record.lastSeen = Now()
    record.status = "active"
    DB.quests[questID] = record
    AddEvent("ACCEPTED", questID, title)
end

local function HandleQuestTurnedIn(questID)
    questID = tonumber(questID)
    if not questID then return end
    local title = QuestTitle(questID)
    local record = DB.quests[questID] or {}
    record.questID = questID
    record.title = title
    record.completedAt = Now()
    record.status = "completed"
    DB.quests[questID] = record
    AddEvent("COMPLETED", questID, title)
end

local function HandleQuestRemoved(questID)
    questID = tonumber(questID)
    if not questID then return end
    if IsQuestCompleted(questID) then
        HandleQuestTurnedIn(questID)
        return
    end
    local title = QuestTitle(questID, DB.quests[questID] and DB.quests[questID].title)
    local record = DB.quests[questID] or {}
    record.questID = questID
    record.title = title
    record.abandonedAt = Now()
    record.status = "abandoned"
    DB.quests[questID] = record
    AddEvent("ABANDONED / REMOVED", questID, title)
end

local function ApiDiagnostics()
    local dbReady, dbReason = QuestieDBReady()
    Print("Interface: " .. tostring(select(4, GetBuildInfo())))
    Print("Active quest log API: " .. tostring(C_QuestLog and type(C_QuestLog.GetInfo) == "function"))
    Print("Live objective API: " .. tostring(C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function"))
    Print("Container item APIs: " .. tostring(C_Container and type(C_Container.GetContainerItemID) == "function"))
    Print("Bank open: " .. tostring(IsBankOpen()))
    Print("Character scope: " .. tostring(DB.activeCharacterKey or "not initialized"))
    Print("Tooltip hooks — typed: " .. tostring(hookStats.typed) .. ", legacy: "
        .. tostring(hookStats.legacy) .. ", setter hooks: " .. tostring(hookStats.setters))
    Print("QuestieDB available: " .. tostring(dbReady) .. (dbReason and (" (" .. tostring(dbReason) .. ")") or ""))
    Print("QuestieDB item index: " .. (dbIndexReady and "READY" or (dbIndexRunning and "BUILDING" or "NOT STARTED")))
    if dbIndexRunning then Print("Index progress: " .. dbIndexProcessed .. " / " .. dbIndexTotal) end
end

SLASH_QUESTITEMTRACKER1 = "/qit"
SlashCmdList.QUESTITEMTRACKER = function(message)
    local cmd, arg = string.match(string.lower(message or ""), "^(%S*)%s*(.-)$")
    if cmd == "scan" then
        ScanBags()
    elseif cmd == "quests" then
        ListQuests()
    elseif cmd == "history" then
        ShowHistory(arg ~= "" and arg or nil)
    elseif cmd == "completed" then
        ListCompletedQuests(arg ~= "" and arg or nil)
    elseif cmd == "import" then
        local activeCount, completedCount, newlyImported, supported = SyncQuestHistory(true)
        if supported then
            Print("Character snapshot refreshed.")
            Print("Active quests found: " .. activeCount)
            Print("Completed quests found: " .. completedCount)
            Print("New completed history records imported: " .. newlyImported)
            Print("Original completion dates are unavailable for imported quests.")
        else
            Print("This client did not provide GetAllCompletedQuestIDs; completed history could not be bulk imported.")
        end
    elseif cmd == "items" then
        local n = 0
        for id, item in pairs(DB.items or {}) do
            n = n + 1
            Print(string.format("%s (item %d), last seen %s",
                item.name or "Unknown item", id, item.lastSeen or "unknown"))
        end
        Print("Tracked item IDs: " .. n)
    elseif cmd == "db" then
        ApiDiagnostics()
    elseif cmd == "apis" then
        ApiDiagnostics()
    elseif cmd == "options" or cmd == "settings" or cmd == "config" or cmd == "" then
        ToggleOptionsPanel()
    else
        Print("Commands: /qit options | quests | completed [word] | history [word] | scan | items | db")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_REMOVED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        InitializeCharacterData()
        SyncQuestHistory(true)
        InstallTooltipHook()
        CreateMinimapButton()
        if QuestieDBReady() then BuildQuestItemIndex() end
        -- No user setup/import command is required. The current quest log and
        -- all completed quest IDs are synchronized automatically at login.
    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "QuestieDB" then
            UpdateQuestieDBStatusLight()
            InstallTooltipHook()
            if CHARACTER_DATA then SyncQuestHistory(true) end
            BuildQuestItemIndex()
        end
    elseif event == "QUEST_ACCEPTED" then
        completedQuestSnapshot = nil
        HandleQuestAccepted(...)
        SyncQuestHistory(false)
    elseif event == "QUEST_TURNED_IN" then
        completedQuestSnapshot = nil
        HandleQuestTurnedIn(...)
        SyncQuestHistory(true)
    elseif event == "QUEST_REMOVED" then
        completedQuestSnapshot = nil
        HandleQuestRemoved(...)
        SyncQuestHistory(true)
    elseif event == "QUEST_LOG_UPDATE" then
        completedQuestSnapshot = nil
        SyncQuestHistory(false)
    end
end)