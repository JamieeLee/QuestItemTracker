-- Quest Item Tracker v0.4.3
-- Automatic per-character quest sync + tooltip compatibility and index warm-up.
-- Requires the standalone QuestieDB data addon; the full Questie tracker/map addon is not required.

local ADDON = ...
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

local MAX_EVENTS = 500
local MAX_HISTORY_LINES = 35
local REQUIRED_DB_CONTRACT = 4

local itemQuestIndex = {}
local dbIndexReady = false
local dbIndexRunning = false
local dbIndexProcessed = 0
local dbIndexTotal = 0
local dbIndexFrame
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
        if info and not info.isHeader and info.questID then
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

    local all = SafeCall(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
    if type(all) == "table" then
        for _, id in ipairs(all) do
            if tonumber(id) == tonumber(questID) then return true end
        end
    end
    return false
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
    if quest and quest.frequency ~= nil and quest.frequency ~= 0 then return true end
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
        return 0, 0, false
    end

    local total = 0
    local newlyImported = 0
    for _, rawID in ipairs(completed) do
        local id = tonumber(rawID)
        if id then
            total = total + 1
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
    dbIndexFrame = worker
    worker:Show()
    worker:SetScript("OnUpdate", function(self)
        local budget = 40
        while budget > 0 and cursor <= #ids do
            local questID = tonumber(ids[cursor])
            if questID then
                local objectives = SafeCall(QuestDB.objectives, questID)
                local itemObjectives = type(objectives) == "table" and objectives[3] or nil
                if type(itemObjectives) == "table" then
                    for _, objective in ipairs(itemObjectives) do
                        if type(objective) == "table" then
                            IndexQuestItem(objective[1], questID, "database objective", tonumber(objective[3]))
                        end
                    end
                end

                local requiredSources = SafeCall(QuestDB.requiredSourceItems, questID)
                if type(requiredSources) == "table" then
                    for _, itemID in ipairs(requiredSources) do
                        IndexQuestItem(itemID, questID, "database source item", 1)
                    end
                end
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
-- ItemDB.relatedQuests provides *candidate* quest IDs only. Confirm each actual item
-- objective or required source item against QuestDB before showing anything.
-- Never use this partial set to declare an item safe to delete.
local function LookupItemDuringIndex(itemID)
    if not QuestieDBReady() or type(ItemDB) ~= "table"
        or type(ItemDB.relatedQuests) ~= "function" then
        return nil
    end
    local candidateIDs = SafeCall(ItemDB.relatedQuests, itemID)
    if type(candidateIDs) ~= "table" then return nil end

    local matches = {}
    for _, rawQuestID in ipairs(candidateIDs) do
        local questID = tonumber(rawQuestID)
        if questID and questID > 0 then
            local objectives = SafeCall(QuestDB.objectives, questID)
            local itemObjectives = type(objectives) == "table" and objectives[3] or nil
            if type(itemObjectives) == "table" then
                for _, objective in ipairs(itemObjectives) do
                    if type(objective) == "table" and tonumber(objective[1]) == itemID then
                        AddAssociation(matches, questID, "database objective", tonumber(objective[3]))
                    end
                end
            end
            local sources = SafeCall(QuestDB.requiredSourceItems, questID)
            if type(sources) == "table" then
                for _, sourceID in ipairs(sources) do
                    if tonumber(sourceID) == itemID then
                        AddAssociation(matches, questID, "database source item", 1)
                        break
                    end
                end
            end
        end
    end
    return next(matches) and matches or nil
end

-- Item membership comes exclusively from QuestDB item objectives and requiredSourceItems.
-- This intentionally excludes generic related-quest and quest-reward links: those do not
-- prove that the player must keep or turn in the item.

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
                if type(qinfo) == "table" and qinfo.questID then
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
        if knownEntry then
            for _, objective in ipairs(quest.objectives or {}) do
                local text = objective.text or ""
                local lowerText = string.lower(text)
                if objective.type == "item" and lowerText ~= ""
                    and (string.find(lowerText, lowerName, 1, true)
                        or string.find(lowerName, lowerText, 1, true)) then
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
end

local function IsQuestRepeatableByID(questID)
    local value = SafeCall(C_QuestLog and C_QuestLog.IsRepeatableQuest, questID)
    if value == nil then value = SafeCall(C_QuestLog and C_QuestLog.IsQuestReplayable, questID) end
    return value == true
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

local function GetQuestStatus(questID, matchesEntry, activeMap)
    local active = activeMap[questID]
    local record = DB.quests[questID]
    local sources = matchesEntry and matchesEntry.sources or {}
    local sourceOnly = sources["database source item"] and not sources["database objective"]
    if active and sourceOnly then
        if IsRepeatableQuest(active) then
            return "REPEATABLE — KEEP FOR NEXT TIME", "|cffffcc66"
        end
        return "QUEST ACCEPTED · START ITEM NO LONGER NEEDED", "|cff66ccff"
    end
    if active then
        if active.isComplete then return "READY TO TURN IN", "|cffffd45c" end
        if IsRepeatableQuest(active) then return "NEEDED · REPEATABLE", "|cff33ff66" end
        return "NEEDED NOW", "|cff33ff66"
    end
    if IsQuestRepeatableByID(questID) then
        if IsQuestCompleted(questID) then return "REPEATABLE · COMPLETED BEFORE", "|cffffcc66" end
        return "REPEATABLE QUEST", "|cffffcc66"
    end
    if IsQuestCompleted(questID) or (record and record.status == "completed") then
        return "COMPLETED", "|cff66ccff"
    end
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

local function GetObjectiveCountFromDB(questID, itemID)
    local objectives = SafeCall(QuestDB and QuestDB.objectives, questID)
    local itemObjectives = type(objectives) == "table" and objectives[3] or nil
    if type(itemObjectives) == "table" then
        for _, objective in ipairs(itemObjectives) do
            if type(objective) == "table" and tonumber(objective[1]) == tonumber(itemID) then
                return tonumber(objective[3])
            end
        end
    end
    return nil
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
    local hasUse = false
    local hasActiveUse = false
    local hasFutureUse = false
    local hasRepeatableUse = false
    local allCompleted = true

    for questID, entry in pairs(matches) do
        hasUse = true
        local active = activeMap[questID]
        local sources = entry.sources or {}
        local sourceOnly = sources["database source item"] and not sources["database objective"]
        local completed = IsQuestCompleted(questID)
            or (DB.quests[questID] and DB.quests[questID].status == "completed")
        local repeatable = IsQuestRepeatableByID(questID)
            or (active and IsRepeatableQuest(active))
        local stillNeededNow = active and not sourceOnly

        if stillNeededNow then hasActiveUse = true end
        if repeatable then hasRepeatableUse = true end
        if (not completed and not (active and sourceOnly)) or repeatable or stillNeededNow then
            allCompleted = false
            if not active and not repeatable then hasFutureUse = true end
        end
    end

    if hasActiveUse then
        return "NEEDED — a current quest uses this item", "|cff33dd77", "needed"
    end
    if hasRepeatableUse then
        return "KEEP — a repeatable quest can use this item", "|cffffcc66", "keep"
    end
    if hasFutureUse then
        return "KEEP — another quest can use this item", "|cffffcc66", "keep"
    end
    if hasUse and allCompleted then
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
    showQuestLevels = true,
    showInventoryBreakdown = true,
    showFutureStatusLabels = false,
}
local function SettingEnabled(key)
    local value = DB.settings[key]
    if value == nil then return DEFAULT_SETTINGS[key] == true end
    return value == true
end

local optionsPanel
local minimapButton

local function SetSolidColor(texture, r, g, b, a)
    if type(texture.SetColorTexture) == "function" then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

local function CreateOptionsPanel()
    if optionsPanel then return optionsPanel end
    if not UIParent or type(CreateFrame) ~= "function" then return nil end

    local panel = CreateFrame("Frame", "QITOptionsPanel", UIParent)
    panel:SetSize(360, 347)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 45)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local border = panel:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    SetSolidColor(border, 0.34, 0.43, 0.55, 0.96)
    local background = panel:CreateTexture(nil, "BORDER")
    background:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
    SetSolidColor(background, 0.055, 0.075, 0.11, 0.98)
    local stripe = panel:CreateTexture(nil, "ARTWORK")
    stripe:SetHeight(2)
    stripe:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -45)
    stripe:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -45)
    SetSolidColor(stripe, 0.38, 0.7, 0.94, 1)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
    title:SetText("Quest Item Tracker")
    local subTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -58)
    subTitle:SetText("Tooltip preferences  |  Saved automatically")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() panel:Hide() end)

    local entries = {
        { key = "showQuestIDs", label = "Show quest IDs" },
        { key = "showItemIDs", label = "Show item IDs" },
        { key = "showQuestLevels", label = "Show quest levels" },
        { key = "showInventoryBreakdown", label = "Show bag / bank breakdown" },
        { key = "showFutureStatusLabels", label = "Show future quest labels" },
    }
    local checkboxes = {}
    for i, entry in ipairs(entries) do
        local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        checkbox:SetSize(25, 25)
        checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -86 - (i - 1) * 36)
        checkbox:SetChecked(SettingEnabled(entry.key))
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
        for _, row in ipairs(checkboxes) do
            row.frame:SetChecked(SettingEnabled(row.key))
        end
    end)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -17, 23)
    hint:SetText("Changes apply on next hover")
    panel:SetScript("OnShow", function()
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
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    if type(icon.SetTexCoord) == "function" then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("CENTER", button, "CENTER", 10, -10)

    button:SetScript("OnClick", ToggleOptionsPanel)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Quest Item Tracker", 0.4, 0.8, 1)
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

    -- Don't decorate generic items. During indexing, only verified item
    -- objectives/source items from ItemDB reverse relations are sufficient.
    local indexed = dbIndexReady and itemQuestIndex[itemID] or nil
    local partial = nil
    if type(indexed) ~= "table" or not next(indexed) then
        if dbIndexReady then return false end
        partial = LookupItemDuringIndex(itemID)
        if not partial then return false end
    end

    local itemNameResolved = GetItemName(itemID, itemName)
    local activeMap = GetActiveQuestMap()
    local matches = {}

    if partial then
        matches = partial
    else
        for questID, entry in pairs(indexed) do
            AddAssociation(matches, questID, "database item use", entry.required)
            local target = matches[questID]
            target.sources = entry.sources or target.sources
        end
    end

    ActiveObjectiveMatches(itemNameResolved, activeMap, matches)

    local bags, bank = CountItemInventory(itemID)
    local totalHave = bags + bank
    local ids = {}
    for questID in pairs(matches) do ids[#ids + 1] = questID end
    table.sort(ids, function(a, b)
        return string.lower(QuestDBName(a)) < string.lower(QuestDBName(b))
    end)

    RecordItem(itemID, itemNameResolved, matches)
    -- Mark this tooltip before rendering: Show() may invoke tooltip hooks again.
    decoratedTooltips[tooltip] = itemID

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff66ccffQuest Item Tracker|r")
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

    local activeCount, futureCount, completedCount = 0, 0, 0
    for _, questID in ipairs(ids) do
        local entry = matches[questID]
        local active = activeMap[questID]
        local questName = (active and active.title) or QuestDBName(questID)
        local status, color = GetQuestStatus(questID, entry, activeMap)
        local level = GetQuestLevel(questID, active)
        local levelText = level and ("Level " .. level) or "Level unknown"

        local sources = entry.sources or {}
        local sourceOnly = sources["database source item"] and not sources["database objective"]
        if active and not sourceOnly then
            activeCount = activeCount + 1
        elseif IsQuestRepeatableByID(questID) or not IsQuestCompleted(questID) then
            futureCount = futureCount + 1
        else
            completedCount = completedCount + 1
        end

        local nameLine = color .. questName .. "|r"
        if SettingEnabled("showQuestLevels") then nameLine = nameLine .. "  (" .. levelText .. ")" end
        tooltip:AddLine(nameLine)
        -- Future status lines are optional; quest names/levels never disappear.
        -- Grey quests retain a concise GREY QUEST marker even in compact mode.
        if not SettingEnabled("showFutureStatusLabels") then
            if status == "FUTURE USE · GREY QUEST" then
                status = "GREY QUEST"
            elseif status == "FUTURE QUEST" or status == "FUTURE USE · ABANDONED" then
                status = nil
            end
        end
        if status or SettingEnabled("showQuestIDs") then
            local statusLine = status and ("  " .. status) or "  "
            if SettingEnabled("showQuestIDs") then
                statusLine = statusLine .. (status and "  |  " or "") .. "Quest ID: " .. questID
            end
            tooltip:AddLine(statusLine, 0.78, 0.78, 0.78)
        end

        if entry.required and entry.required > 0 then
            tooltip:AddLine("  Have " .. totalHave .. " / Need " .. entry.required, 0.75, 0.9, 0.75)
        elseif entry.detail then
            tooltip:AddLine("  " .. entry.detail, 0.7, 0.7, 0.7, true)
        end
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
        end)
        pcall(tooltip.HookScript, tooltip, "OnHide", function(self)
            decoratedTooltips[self] = nil
        end)
        ok = pcall(tooltip.HookScript, tooltip, "OnShow", function(self)
            RunTooltipHook(self)
        end)
        if ok then hooked = true end
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
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
frame:RegisterEvent("BANK_BAG_SLOT_FLAGS_UPDATED")
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
            InstallTooltipHook()
            if CHARACTER_DATA then SyncQuestHistory(true) end
            BuildQuestItemIndex()
        end
    elseif event == "QUEST_ACCEPTED" then
        HandleQuestAccepted(...)
        SyncQuestHistory(false)
    elseif event == "QUEST_TURNED_IN" then
        HandleQuestTurnedIn(...)
        SyncQuestHistory(true)
    elseif event == "QUEST_REMOVED" then
        HandleQuestRemoved(...)
        SyncQuestHistory(true)
    elseif event == "QUEST_LOG_UPDATE" then
        SyncQuestHistory(false)
    elseif event == "BAG_UPDATE_DELAYED" or event == "BANKFRAME_OPENED"
        or event == "BANKFRAME_CLOSED" or event == "PLAYERBANKSLOTS_CHANGED"
        or event == "BANK_BAG_SLOT_FLAGS_UPDATED" then
        -- Counts are read live when the item tooltip is opened/refreshed.
    end
end)