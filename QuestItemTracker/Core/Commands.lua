-- QITF / Core/Commands.lua: owns core responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local Print = assert(api.Print, "QIT load order: Print")
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local Now = assert(api.Now, "QIT load order: Now")
local AddEvent = assert(api.AddEvent, "QIT load order: AddEvent")
local QuestTitle = assert(api.QuestTitle, "QIT load order: QuestTitle")
local GetActiveQuestMap = assert(api.GetActiveQuestMap, "QIT load order: GetActiveQuestMap")
local IsQuestCompleted = assert(api.IsQuestCompleted, "QIT load order: IsQuestCompleted")
local IsTrivialQuest = assert(api.IsTrivialQuest, "QIT load order: IsTrivialQuest")
local IsRepeatableQuest = assert(api.IsRepeatableQuest, "QIT load order: IsRepeatableQuest")
local SyncQuestHistory = assert(api.SyncQuestHistory, "QIT load order: SyncQuestHistory")
local GetItemName = assert(api.GetItemName, "QIT load order: GetItemName")
local IsBankOpen = assert(api.IsBankOpen, "QIT load order: IsBankOpen")
local AddAssociation = assert(api.AddAssociation, "QIT load order: AddAssociation")
local QuestieDBReady = assert(api.QuestieDBReady, "QIT load order: QuestieDBReady")
local NativeBagQuestInfo = assert(api.NativeBagQuestInfo, "QIT load order: NativeBagQuestInfo")
local RecordItem = assert(api.RecordItem, "QIT load order: RecordItem")
local ToggleOptionsPanel = assert(api.ToggleOptionsPanel, "QIT load order: ToggleOptionsPanel")
local PinDiagnostics = assert(api.PinDiagnostics, "QIT load order: PinDiagnostics")
local MAX_HISTORY_LINES = NS.constants.MAX_HISTORY_LINES

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
                    local idx = S.itemQuestIndex[tonumber(itemID)]
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
    Print("Imported completed quest records: " .. tostring(S.CHARACTER_DATA and S.CHARACTER_DATA.completedQuestImportCount or 0)
        .. " | Last snapshot: " .. tostring(S.CHARACTER_DATA and S.CHARACTER_DATA.completedQuestImportAt or "not imported"))
    for _, event in ipairs(S.DB.events or {}) do
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
    for _ in pairs(S.DB.quests or {}) do n = n + 1 end
    Print("Tracked quest records: " .. tostring(n))
end

local function ListCompletedQuests(filter)
    SyncQuestHistory(true)
    local rows = {}
    local needle = filter and string.lower(filter) or nil

    for id, record in pairs(S.DB.quests or {}) do
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
    local record = S.DB.quests[questID] or {}
    record.questID = questID
    record.title = title
    record.firstSeen = record.firstSeen or Now()
    record.lastSeen = Now()
    record.status = "active"
    S.DB.quests[questID] = record
    AddEvent("ACCEPTED", questID, title)
end

local function HandleQuestTurnedIn(questID)
    questID = tonumber(questID)
    if not questID then return end
    local title = QuestTitle(questID)
    local record = S.DB.quests[questID] or {}
    record.questID = questID
    record.title = title
    record.completedAt = Now()
    record.status = "completed"
    S.DB.quests[questID] = record
    AddEvent("COMPLETED", questID, title)
end

local function HandleQuestRemoved(questID)
    questID = tonumber(questID)
    if not questID then return end
    if IsQuestCompleted(questID) then
        HandleQuestTurnedIn(questID)
        return
    end
    local title = QuestTitle(questID, S.DB.quests[questID] and S.DB.quests[questID].title)
    local record = S.DB.quests[questID] or {}
    record.questID = questID
    record.title = title
    record.abandonedAt = Now()
    record.status = "abandoned"
    S.DB.quests[questID] = record
    AddEvent("ABANDONED / REMOVED", questID, title)
end

local function ApiDiagnostics()
    local dbReady, dbReason = QuestieDBReady()
    Print("Interface: " .. tostring(select(4, GetBuildInfo())))
    Print("Active quest log API: " .. tostring(C_QuestLog and type(C_QuestLog.GetInfo) == "function"))
    Print("Live objective API: " .. tostring(C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function"))
    Print("Container item APIs: " .. tostring(C_Container and type(C_Container.GetContainerItemID) == "function"))
    Print("Bank open: " .. tostring(IsBankOpen()))
    Print("Character scope: " .. tostring(S.DB.activeCharacterKey or "not initialized"))
    Print("Tooltip hooks — typed: " .. tostring(S.hookStats.typed) .. ", legacy: "
        .. tostring(S.hookStats.legacy) .. ", setter hooks: " .. tostring(S.hookStats.setters))
    Print("QuestieDB available: " .. tostring(dbReady) .. (dbReason and (" (" .. tostring(dbReason) .. ")") or ""))
    Print("QuestieDB item index: " .. (S.dbIndexReady and "READY" or (S.dbIndexRunning and "BUILDING" or "NOT STARTED")))
    if S.dbIndexRunning then Print("Index progress: " .. S.dbIndexProcessed .. " / " .. S.dbIndexTotal) end
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
        for id, item in pairs(S.DB.items or {}) do
            n = n + 1
            Print(string.format("%s (item %d), last seen %s",
                item.name or "Unknown item", id, item.lastSeen or "unknown"))
        end
        Print("Tracked item IDs: " .. n)
    elseif cmd == "pin" then
        Print(PinDiagnostics())
    elseif cmd == "db" then
        ApiDiagnostics()
    elseif cmd == "apis" then
        ApiDiagnostics()
    elseif cmd == "options" or cmd == "settings" or cmd == "config" or cmd == "" then
        ToggleOptionsPanel()
    else
        Print("Commands: /qit options | quests | completed [word] | history [word] | scan | items | pin | db")
    end
end

api.HandleQuestAccepted = HandleQuestAccepted
api.HandleQuestTurnedIn = HandleQuestTurnedIn
api.HandleQuestRemoved = HandleQuestRemoved
