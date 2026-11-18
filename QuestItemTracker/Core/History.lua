-- QITF / Core/History.lua: saved variables, character history, quest sync.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
NS.state = NS.state or {}
NS.api = NS.api or {}
NS.constants = NS.constants or {}
local S, api = NS.state, NS.api

-- Quest Item Tracker Forever (version comes from the TOC metadata)
-- Automatic per-character quest sync + tooltip compatibility and index warm-up.
-- Requires the standalone QuestieDB data addon; the full Questie tracker/map addon is not required.

-- Always bind to the actual SavedVariables table. On clients that load
-- SavedVariables AFTER addon Lua runs, the table initially created here is
-- temporary and WoW replaces the global before ADDON_LOADED. If closures
-- capture that temporary table, settings appear to work but vanish on /reload.
S.DB = nil 
local function AttachSavedVariables()
    if type(QuestItemTrackerDB) ~= "table" then QuestItemTrackerDB = {} end
    S.DB = QuestItemTrackerDB
    S.DB.version = 4
    S.DB.quests = S.DB.quests or {} -- v0.3.x legacy bucket, migrated on first login.
    S.DB.events = S.DB.events or {}
    S.DB.items = S.DB.items or {}
    S.DB.characters = S.DB.characters or {}
    -- Preferences are account-wide; quest history stays character-scoped.
    S.DB.settings = type(S.DB.settings) == "table" and S.DB.settings or {}
end
AttachSavedVariables()
S.CHARACTER_DATA = nil 
S.completedQuestSnapshot = nil -- fallback when IsQuestFlaggedCompleted is unavailable

local MAX_EVENTS = 500
local MAX_HISTORY_LINES = 35
local REQUIRED_DB_CONTRACT = 4

S.itemQuestIndex = {}
S.dbIndexReady = false
S.dbIndexRunning = false
S.dbIndexProcessed = 0
S.dbIndexTotal = 0
S.tooltipHooked = false
S.tooltipErrorReported = false
-- Modern data hooks and older client scripts can both run for one hover.
-- Remember only tooltips actually decorated; OnHide/Cleared resets this state.
S.decoratedTooltips = setmetatable({}, { __mode = "k" })
S.hookStats = { typed = false, legacy = false, setters = 0 }

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
    local character = S.DB.characters[key]
    if type(character) ~= "table" then
        character = { quests = {}, events = {}, items = {} }
        S.DB.characters[key] = character
    end

    character.quests = character.quests or {}
    character.events = character.events or {}
    character.items = character.items or {}

    -- Preserve data created by v0.3.x. The old SavedVariables layout was shared,
    -- so migrate it once to the first character that loads the new version.
    if not S.DB.legacyCharacterDataMigrated then
        for id, record in pairs(S.DB.quests) do
            if character.quests[id] == nil then character.quests[id] = record end
        end
        for index, event in ipairs(S.DB.events) do
            character.events[#character.events + 1] = event
        end
        for id, item in pairs(S.DB.items) do
            if character.items[id] == nil then character.items[id] = item end
        end
        S.DB.legacyCharacterDataMigrated = true
    end

    S.CHARACTER_DATA = character
    S.completedQuestSnapshot = nil
    S.DB.activeCharacterKey = key
    S.DB.quests = character.quests
    S.DB.events = character.events
    S.DB.items = character.items
end

local function AddEvent(kind, questID, title, extra)
    table.insert(S.DB.events, 1, {
        time = Now(),
        kind = kind,
        questID = tonumber(questID),
        title = title or (questID and ("Quest " .. tostring(questID))) or "Unknown quest",
        extra = extra,
    })
    while #S.DB.events > MAX_EVENTS do
        table.remove(S.DB.events)
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

    if not S.completedQuestSnapshot then
        local all = SafeCall(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
        if type(all) == "table" then
            S.completedQuestSnapshot = {}
            for _, id in ipairs(all) do
                local key = tonumber(id)
                if key then S.completedQuestSnapshot[key] = true end
            end
        end
    end
    return S.completedQuestSnapshot ~= nil
        and S.completedQuestSnapshot[tonumber(questID)] == true
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
        local record = S.DB.quests[id] or {}
        record.questID = id
        record.title = quest.title
        record.firstSeen = record.firstSeen or "Imported from current quest log"
        record.lastSeen = Now()
        record.status = "active"
        record.level = quest.level
        record.isTrivial = IsTrivialQuest(quest)
        record.isRepeatable = IsRepeatableQuest(quest)
        record.importedFromQuestLog = true
        S.DB.quests[id] = record
    end
    return count, active
end

local function ImportCompletedQuestList(activeMap)
    local completed = SafeCall(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
    if type(completed) ~= "table" then
        S.completedQuestSnapshot = nil
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
            local record = S.DB.quests[id] or {}
            if not record.importedCompleted then newlyImported = newlyImported + 1 end

            record.questID = id
            record.title = QuestTitle(id, record.title)
            record.importedCompleted = true
            record.completionDateUnknown = not record.completedAt
            record.firstSeen = record.firstSeen or "Imported from completed quest list (original date unavailable)"
            -- A repeatable quest can be both in the completed history and active now.
            if not (activeMap and activeMap[id]) then record.status = "completed" end
            S.DB.quests[id] = record
        end
    end

    S.completedQuestSnapshot = snapshot
    S.CHARACTER_DATA.completedQuestImportAt = Now()
    S.CHARACTER_DATA.completedQuestImportCount = total
    return total, newlyImported, true
end

local function ReconcileMissingActiveQuests(activeMap)
    -- Catch a quest removal that happened while the addon was reloading or offline.
    -- Never invent a completion: only the completed-ID snapshot can do that.
    for id, record in pairs(S.DB.quests) do
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
    if not S.CHARACTER_DATA then return 0, 0 end
    local activeCount, activeMap = SyncActiveQuestLog()
    if importCompleted then
        local completedCount, newlyImported, supported = ImportCompletedQuestList(activeMap)
        if supported then ReconcileMissingActiveQuests(activeMap) end
        return activeCount, completedCount, newlyImported, supported
    end
    return activeCount, S.CHARACTER_DATA.completedQuestImportCount or 0, 0, nil
end

NS.constants.MAX_HISTORY_LINES = MAX_HISTORY_LINES
NS.constants.REQUIRED_DB_CONTRACT = REQUIRED_DB_CONTRACT

api.AttachSavedVariables = AttachSavedVariables
api.Print = Print
api.SafeCall = SafeCall
api.AddonVersion = AddonVersion
api.Now = Now
api.InitializeCharacterData = InitializeCharacterData
api.AddEvent = AddEvent
api.QuestTitle = QuestTitle
api.GetActiveQuestMap = GetActiveQuestMap
api.IsQuestCompleted = IsQuestCompleted
api.IsTrivialQuest = IsTrivialQuest
api.IsRepeatableQuest = IsRepeatableQuest
api.SyncQuestHistory = SyncQuestHistory
