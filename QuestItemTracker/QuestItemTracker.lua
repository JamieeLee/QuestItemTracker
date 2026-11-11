-- Quest Item Tracker v0.3.1
-- Preserves QIT v0.2 quest history/live-quest matching and adds QuestieDB data lookup.
-- QuestieDB is an OPTIONAL data dependency. The full Questie tracker/map addon is NOT required.

local ADDON = ...
QuestItemTrackerDB = QuestItemTrackerDB or {}

local DB = QuestItemTrackerDB
DB.version = 3
DB.quests = DB.quests or {}
DB.events = DB.events or {}
DB.items = DB.items or {}

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
    return count
end

local function ImportCompletedQuestList()
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
            if record.status ~= "active" then
                record.status = "completed"
            end
            DB.quests[id] = record
        end
    end

    DB.completedQuestImportAt = Now()
    DB.completedQuestImportCount = total
    return total, newlyImported, true
end

local function SyncQuestHistory()
    local activeCount = SyncActiveQuestLog()
    local completedCount = ImportCompletedQuestList()
    return activeCount, completedCount
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

local function CountBags(itemID)
    local total = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function"
        and type(C_Container.GetContainerItemID) == "function" then
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            local slots = SafeCall(C_Container.GetContainerNumSlots, bag) or 0
            for slot = 1, slots do
                local slotID = SafeCall(C_Container.GetContainerItemID, bag, slot)
                if tonumber(slotID) == tonumber(itemID) then
                    local info = SafeCall(C_Container.GetContainerItemInfo, bag, slot)
                    total = total + (info and tonumber(info.stackCount) or 1)
                end
            end
        end
    end
    return total
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
                        IndexQuestItem(itemID, questID, "database source item")
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
            Print("QuestieDB item index ready (" .. dbIndexProcessed .. " quests scanned).")
        end
    end)
end

local function QuestieDBItemRelations(itemID, matches)
    if type(ItemDB) ~= "table" then return end
    if type(ItemDB.relatedQuests) == "function" then
        local related = SafeCall(ItemDB.relatedQuests, itemID)
        if type(related) == "table" then
            for _, questID in ipairs(related) do
                AddAssociation(matches, questID, "database related quest")
            end
        end
    end
    if type(ItemDB.startQuest) == "function" then
        local start = SafeCall(ItemDB.startQuest, itemID)
        if type(start) == "number" then
            AddAssociation(matches, start, "starts quest")
        elseif type(start) == "table" then
            for _, questID in ipairs(start) do AddAssociation(matches, questID, "starts quest") end
        end
    end
    if type(ItemDB.questRewards) == "function" then
        local rewards = SafeCall(ItemDB.questRewards, itemID)
        if type(rewards) == "table" then
            for _, questID in ipairs(rewards) do AddAssociation(matches, questID, "quest reward") end
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
        for _, objective in ipairs(quest.objectives or {}) do
            local text = objective.text or ""
            local lowerText = string.lower(text)
            if objective.type == "item" and lowerText ~= ""
                and (string.find(lowerText, lowerName, 1, true)
                    or string.find(lowerName, lowerText, 1, true)) then
                local entry = matches[questID]
                if not entry then
                    entry = { questID = questID, sources = {}, required = nil }
                    matches[questID] = entry
                end
                entry.sources["active quest objective"] = true
                entry.detail = text
                entry.fulfilled = tonumber(objective.numFulfilled)
                entry.required = tonumber(objective.numRequired) or entry.required
                entry.finished = objective.finished
                break
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
    if active then
        if active.isComplete then return "READY TO TURN IN", "|cffffd45c" end
        if IsTrivialQuest(active) then return "GREY / TRIVIAL · ACTIVE", "|ffc0c0c0" end
        if IsRepeatableQuest(active) then return "ACTIVE · REPEATABLE", "|cff33ff66" end
        return "ACTIVE", "|cff33ff66"
    end
    if IsQuestCompleted(questID) or (record and record.status == "completed") then
        if IsQuestRepeatableByID(questID) then return "COMPLETED · REPEATABLE", "|cff66ccff" end
        return "COMPLETED", "|cff66ccff"
    end
    if record and record.status == "abandoned" then return "PREVIOUSLY ABANDONED", "|cffffaa55" end

    local level = GetQuestLevel(questID)
    local trivial = IsTrivialQuest({ questID = questID, level = level })
    if trivial then return "GREY / TRIVIAL", "|ffc0c0c0" end
    return "NOT IN QUEST LOG", "|cffffcc66"
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
    local hasKnownConsumer = false
    local hasUncertainAssociation = false
    local hasOutstandingUse = false
    local completedNonRepeatableUses = 0
    local repeatableUse = false

    for questID, entry in pairs(matches) do
        local sources = entry.sources or {}
        local isRewardOnly = sources["quest reward"]
            and not (sources["database item objective"] or sources["active quest objective"]
                or sources["database source item"] or sources["starts quest"]
                or sources["native bag metadata"])

        if not isRewardOnly then
            local isObjective = sources["database item objective"] or sources["active quest objective"]
            local isSource = sources["database source item"] or sources["starts quest"]
            local isNativeQuestItem = sources["native bag metadata"]
            local isRelatedOnly = sources["database related quest"]
                and not isObjective and not isSource and not isNativeQuestItem

            if isObjective or isSource then
                hasKnownConsumer = true
                local active = activeMap[questID]
                local completed = IsQuestCompleted(questID)
                local repeatable = IsQuestRepeatableByID(questID)
                    or (active and IsRepeatableQuest(active))

                if active then
                    hasOutstandingUse = true
                elseif repeatable then
                    repeatableUse = true
                    hasOutstandingUse = true
                elseif completed then
                    completedNonRepeatableUses = completedNonRepeatableUses + 1
                else
                    -- The quest is not active or completed. It may be a future
                    -- use, even if prerequisites currently hide it.
                    hasOutstandingUse = true
                end
            elseif isNativeQuestItem or isRelatedOnly then
                -- The relation is real enough to show, but not specific enough
                -- to prove that this item is consumed by that quest.
                hasUncertainAssociation = true
            end
        end
    end

    if hasOutstandingUse then
        if repeatableUse then
            return "KEEP — repeatable or outstanding quest use", "|cff33dd77"
        end
        return "KEEP — an active or future quest may need this", "|cff33dd77"
    end
    if hasKnownConsumer and completedNonRepeatableUses > 0 and not hasUncertainAssociation then
        return "LIKELY SAFE TO DELETE — all known non-repeatable uses are completed", "|cff88ccff"
    end
    if hasUncertainAssociation then
        return "REVIEW — database association needs confirmation", "|cffffcc66"
    end
    if completedNonRepeatableUses > 0 then
        return "REVIEW — completed quest use found, but other uses are uncertain", "|cffffcc66"
    end
    return "REVIEW — no confirmed consuming quest use found", "|cffffcc66"
end

local function AddTooltipLines(tooltip)
    if not tooltip or type(tooltip.GetItem) ~= "function" then return end
    local itemName, itemLink = tooltip:GetItem()
    if not itemLink then return end

    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then return end

    local itemNameResolved = GetItemName(itemID, itemName)
    local activeMap = GetActiveQuestMap()
    local matches = {}

    -- Keep all the original v0.2 detection paths intact.
    NativeBagQuestInfo(itemID, matches)
    ActiveObjectiveMatches(itemNameResolved, activeMap, matches)

    -- Add the wider database view when QuestieDB is installed.
    local dbReady = QuestieDBReady()
    if dbReady then
        local indexed = itemQuestIndex[itemID]
        if type(indexed) == "table" then
            for questID, entry in pairs(indexed) do
                AddAssociation(matches, questID, "database item objective", entry.required)
                local target = matches[questID]
                if entry.sources then
                    for source in pairs(entry.sources) do target.sources[source] = true end
                end
            end
        end
        QuestieDBItemRelations(itemID, matches)
    end

    -- Fill missing objective counts even when the quest was found through
    -- ItemDB.relatedQuests rather than the reverse objective index.
    for questID, entry in pairs(matches) do
        if not entry.required then
            entry.required = GetObjectiveCountFromDB(questID, itemID)
        end
    end

    local have = CountBags(itemID)
    local ids = {}
    for questID in pairs(matches) do ids[#ids + 1] = questID end
    table.sort(ids, function(a, b)
        return string.lower(QuestDBName(a)) < string.lower(QuestDBName(b))
    end)

    RecordItem(itemID, itemNameResolved, matches)

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff66ccffQuest Item Tracker|r")
    tooltip:AddLine("Item ID: " .. itemID .. "  |  In bags: " .. tostring(have), 0.75, 0.75, 0.75)

    local recommendation, recommendationColor = AssessItemRetention(matches, activeMap)
    tooltip:AddLine(recommendationColor .. recommendation .. "|r", 0.9, 0.9, 0.9, true)

    if #ids == 0 then
        tooltip:AddLine("No quest association identified.", 1, 0.7, 0.2)
        tooltip:AddLine("This is not proof the item is unused; database coverage may be incomplete.", 0.7, 0.7, 0.7, true)
        if dbIndexRunning then
            tooltip:AddLine("Quest database indexing: " .. dbIndexProcessed .. " / " .. dbIndexTotal, 0.7, 0.7, 0.7)
        elseif not dbReady then
            tooltip:AddLine("QuestieDB not loaded; showing live game detection only.", 0.7, 0.7, 0.7, true)
        end
    else
        tooltip:AddLine("Quest associations:", 0.3, 1, 0.3)
        for _, questID in ipairs(ids) do
            local entry = matches[questID]
            local active = activeMap[questID]
            local questName = (active and active.title) or QuestDBName(questID)
            local status, color = GetQuestStatus(questID, entry, activeMap)
            local level = GetQuestLevel(questID, active)
            local levelText = level and ("Level " .. level) or "Level unknown"

            tooltip:AddLine(color .. questName .. "|r  (" .. levelText .. ")")
            tooltip:AddLine("  " .. status .. "  |  Quest ID: " .. questID, 0.78, 0.78, 0.78)

            if entry.fulfilled ~= nil and entry.required ~= nil then
                tooltip:AddLine("  Have " .. entry.fulfilled .. " / Need " .. entry.required
                    .. "  |  In bags: " .. have, 0.75, 0.9, 0.75)
            elseif entry.required and entry.required > 0 then
                tooltip:AddLine("  Have " .. have .. " / Need " .. entry.required, 0.75, 0.9, 0.75)
            elseif entry.detail then
                tooltip:AddLine("  " .. entry.detail, 0.7, 0.7, 0.7, true)
            end

            local sourceLabels = {}
            if entry.sources["native bag metadata"] then sourceLabels[#sourceLabels + 1] = "game item link" end
            if entry.sources["active quest objective"] then sourceLabels[#sourceLabels + 1] = "active objective" end
            if entry.sources["database item objective"] then sourceLabels[#sourceLabels + 1] = "database objective" end
            if entry.sources["database source item"] then sourceLabels[#sourceLabels + 1] = "quest start requirement" end
            if entry.sources["database related quest"] then sourceLabels[#sourceLabels + 1] = "related quest" end
            if entry.sources["starts quest"] then sourceLabels[#sourceLabels + 1] = "starts quest" end
            if entry.sources["quest reward"] then sourceLabels[#sourceLabels + 1] = "quest reward" end
            if #sourceLabels > 0 then
                tooltip:AddLine("  Match: " .. table.concat(sourceLabels, ", "), 0.62, 0.62, 0.62, true)
            end
        end
    end

    if dbIndexRunning then
        tooltip:AddLine("Quest database indexing: " .. dbIndexProcessed .. " / " .. dbIndexTotal, 0.65, 0.75, 0.9)
    end
    tooltip:Show()
end

local function InstallTooltipHook()
    if tooltipHooked then return true end

    -- Prefer the native typed post-call when the client exposes it.
    if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        local ok = pcall(TooltipDataProcessor.AddTooltipPostCall,
            Enum.TooltipDataType.Item,
            function(tooltip)
                local success, err = pcall(AddTooltipLines, tooltip)
                if not success then Print("Tooltip error: " .. tostring(err)) end
            end)
        if ok then
            tooltipHooked = true
            return true
        end
    end

    -- Forever-compatible fallback and the original QIT fallback path.
    if not GameTooltip or type(GameTooltip.HookScript) ~= "function" then return false end
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        local ok, err = pcall(AddTooltipLines, tooltip)
        if not ok then Print("Tooltip error: " .. tostring(err)) end
    end)
    if ItemRefTooltip and type(ItemRefTooltip.HookScript) == "function" then
        ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            local ok, err = pcall(AddTooltipLines, tooltip)
            if not ok then Print("ItemRef tooltip error: " .. tostring(err)) end
        end)
    end
    tooltipHooked = true
    return true
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
    SyncQuestHistory()
    local shown = 0
    Print("Quest history (local events plus imported completed-quest snapshot):")
    Print("Imported completed quest records: " .. tostring(DB.completedQuestImportCount or 0)
        .. " | Last snapshot: " .. tostring(DB.completedQuestImportAt or "not imported"))
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
    SyncQuestHistory()
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

    Print("Completed quests known to QIT: " .. #rows)
    for _, row in ipairs(rows) do
        local when = row.completedAt or (row.imported and "date unknown (imported)" or "date unknown")
        Print(string.format("%s (ID: %s) — %s", row.title, tostring(row.id), when))
    end
    if #rows == 0 then Print("No completed quest records found. Try /qit import.") end
end

local function ListQuests()
    SyncQuestHistory()
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
    Print("Native bag quest metadata: " .. tostring(C_Container and type(C_Container.GetContainerItemQuestInfo) == "function"))
    Print("GameTooltip HookScript: " .. tostring(GameTooltip and type(GameTooltip.HookScript) == "function"))
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
        local activeCount = SyncActiveQuestLog()
        local completedCount, newlyImported, supported = ImportCompletedQuestList()
        if supported then
            Print("Character snapshot imported.")
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
    else
        Print("Commands: /qit import | quests | completed [word] | history [word] | scan | items | db")
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
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SyncQuestHistory()
        local hooked = InstallTooltipHook()
        Print("Loaded v0.3.3. Live quest tracking + completed history import + QuestieDB lookup.")
        Print("Tooltip hook installed: " .. tostring(hooked))
        if QuestieDBReady() then
            BuildQuestItemIndex()
        else
            Print("QuestieDB is optional; native live-quest matching remains active.")
        end
        Print("Commands: /qit import | quests | completed | history | scan | items | db")
    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "QuestieDB" then
            InstallTooltipHook()
            BuildQuestItemIndex()
        end
    elseif event == "QUEST_ACCEPTED" then
        HandleQuestAccepted(...)
    elseif event == "QUEST_TURNED_IN" then
        HandleQuestTurnedIn(...)
    elseif event == "QUEST_REMOVED" then
        HandleQuestRemoved(...)
    elseif event == "QUEST_LOG_UPDATE" then
        SyncQuestHistory()
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Item observations are recorded on hover or /qit scan.
    end
end)