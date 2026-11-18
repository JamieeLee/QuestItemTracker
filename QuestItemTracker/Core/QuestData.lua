-- QITF / Core/QuestData.lua: owns core responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local Print = assert(api.Print, "QIT load order: Print")
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local Now = assert(api.Now, "QIT load order: Now")
local QuestTitle = assert(api.QuestTitle, "QIT load order: QuestTitle")
local IsQuestCompleted = assert(api.IsQuestCompleted, "QIT load order: IsQuestCompleted")
local IsTrivialQuest = assert(api.IsTrivialQuest, "QIT load order: IsTrivialQuest")
local IsRepeatableQuest = assert(api.IsRepeatableQuest, "QIT load order: IsRepeatableQuest")
local REQUIRED_DB_CONTRACT = NS.constants.REQUIRED_DB_CONTRACT

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
    local row = S.itemQuestIndex[itemID]
    if not row then
        row = {}
        S.itemQuestIndex[itemID] = row
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
    if S.dbIndexRunning or S.dbIndexReady then return end
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

    S.dbIndexRunning = true
    S.dbIndexReady = false
    S.dbIndexProcessed = 0
    S.dbIndexTotal = #ids
    S.itemQuestIndex = {}

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
            S.dbIndexProcessed = S.dbIndexProcessed + 1
            budget = budget - 1
        end

        if cursor > #ids then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            S.dbIndexRunning = false
            S.dbIndexReady = true
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

-- Holiday categories are supplied by QuestieDB's current flavor (Forever),
-- not by full Questie or a guessed real-world holiday schedule.
-- This is display-only: it must never make an item safer to delete or change KEEP.
local SEASONAL_SORT_NAMES = {
    "WINTER_VEIL", "HARVEST_FESTIVAL", "CHILDRENS_WEEK",
    "LOVE_IS_IN_THE_AIR", "PILGRIMS_BOUNTY", "NOBLEGARDEN",
    "BREWFEST", "MIDSUMMER", "LUNAR_FESTIVAL",
    "DARKMOON_FAIRE", "DAY_OF_THE_DEAD", "SEASONAL", "HALLOWS_END",
}
-- Some quests use a geographical zone sort in older data snapshots even
-- though their known event association is unambiguous. Keep this tiny,
-- known event-quest fallback isolated from the general category rules.
local VERIFIED_SEASONAL_QUESTS = {
    [6962] = true, -- Treats for Great-father Winter
    [7025] = true, -- Treats for Greatfather Winter
}

local function IsSeasonalQuestByID(questID)
    if VERIFIED_SEASONAL_QUESTS[tonumber(questID)] then return true end
    local questSort = tonumber(SafeCall(QuestDB and QuestDB.zoneOrSort, questID))
    if not questSort or questSort >= 0 then return false end
    local enums = LibQuestieDB and LibQuestieDB.Enum
    local sorts = enums and enums.sortKeys
    if type(sorts) ~= "table" then return false end
    for _, name in ipairs(SEASONAL_SORT_NAMES) do
        if questSort == tonumber(sorts[name]) then return true end
    end
    return false
end

-- Let the WoW Forever client choose the quest difficulty category relative
-- to the character, rather than reimplementing level thresholds ourselves.
local function QuestNameColor(questLevel)
    local color = questLevel and SafeCall(GetQuestDifficultyColor, questLevel)
    if type(color) == "table" and type(color.r) == "number"
        and type(color.g) == "number" and type(color.b) == "number" then
        local function Byte(value)
            return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
        end
        return string.format("|cff%02x%02x%02x", Byte(color.r), Byte(color.g), Byte(color.b))
    end
    return "|cffe8edf2" -- neutral ivory when the client's API has no answer
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
    local record = S.DB.quests[questID]
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
    local record = S.DB.items[itemID] or {}
    record.itemID = itemID
    record.name = itemName or record.name
    record.lastSeen = Now()
    record.questIDs = record.questIDs or {}
    for questID in pairs(matches) do
        record.questIDs[questID] = true
    end
    S.DB.items[itemID] = record
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
                or (S.DB.quests[questID] and S.DB.quests[questID].status == "completed")
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

api.AddAssociation = AddAssociation
api.QuestieDBReady = QuestieDBReady
api.BuildQuestItemIndex = BuildQuestItemIndex
api.LookupItemDuringIndex = LookupItemDuringIndex
api.AddRewardProvenance = AddRewardProvenance
api.NativeBagQuestInfo = NativeBagQuestInfo
api.ActiveObjectiveMatches = ActiveObjectiveMatches
api.IsQuestRepeatableByID = IsQuestRepeatableByID
api.IsSeasonalQuestByID = IsSeasonalQuestByID
api.QuestNameColor = QuestNameColor
api.GetQuestLevel = GetQuestLevel
api.IsQuestStarterOnly = IsQuestStarterOnly
api.IsInformationalOnly = IsInformationalOnly
api.GetQuestStatus = GetQuestStatus
api.QuestDBName = QuestDBName
api.RecordItem = RecordItem
api.AssessItemRetention = AssessItemRetention
