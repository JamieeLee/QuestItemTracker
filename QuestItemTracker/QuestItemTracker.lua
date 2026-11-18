-- QITF / QuestItemTracker.lua: owns questitemtracker.lua responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local AttachSavedVariables = assert(api.AttachSavedVariables, "QIT load order: AttachSavedVariables")
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local InitializeCharacterData = assert(api.InitializeCharacterData, "QIT load order: InitializeCharacterData")
local SyncQuestHistory = assert(api.SyncQuestHistory, "QIT load order: SyncQuestHistory")
local QuestieDBReady = assert(api.QuestieDBReady, "QIT load order: QuestieDBReady")
local BuildQuestItemIndex = assert(api.BuildQuestItemIndex, "QIT load order: BuildQuestItemIndex")
local UpdateQuestieDBStatusLight = assert(api.UpdateQuestieDBStatusLight, "QIT load order: UpdateQuestieDBStatusLight")
local CreateMinimapButton = assert(api.CreateMinimapButton, "QIT load order: CreateMinimapButton")
local UpdateTurnInHover = assert(api.UpdateTurnInHover, "QIT load order: UpdateTurnInHover")
local ReleasePinnedItem = assert(api.ReleasePinnedItem, "QIT load order: ReleasePinnedItem")
local PinCurrentItem = assert(api.PinCurrentItem, "QIT load order: PinCurrentItem")
local InstallTooltipHook = assert(api.InstallTooltipHook, "QIT load order: InstallTooltipHook")
local HandleQuestAccepted = assert(api.HandleQuestAccepted, "QIT load order: HandleQuestAccepted")
local HandleQuestTurnedIn = assert(api.HandleQuestTurnedIn, "QIT load order: HandleQuestTurnedIn")
local HandleQuestRemoved = assert(api.HandleQuestRemoved, "QIT load order: HandleQuestRemoved")

-- Independent from any tooltip's OnUpdate or hide behavior: custom bag
-- addons may replace their tooltip frame while Shift remains held.
local pinWatchElapsed = 0
local frame = CreateFrame("Frame")
-- An unparented data frame has no visual impact, but it must remain shown
-- or WoW may stop delivering OnUpdate while the source tooltip is hidden.
frame:Show()
frame:SetScript("OnUpdate", function(_, elapsed)
    pinWatchElapsed = pinWatchElapsed + (tonumber(elapsed) or 0)
    if pinWatchElapsed < 0.05 then return end
    pinWatchElapsed = 0
    if S.pinnedInfo then
        if not SafeCall(IsShiftKeyDown) then
            ReleasePinnedItem()
        else
            UpdateTurnInHover(S.pinnedInfo.frame)
        end
        return
    end
    if not SafeCall(IsShiftKeyDown) then return end
    local source = GameTooltip
    if source and S.decoratedTooltips[source] and S.qitStartLines[source]
        and (type(source.IsShown) ~= "function" or source:IsShown()) then
        PinCurrentItem(source)
    elseif ItemRefTooltip and S.decoratedTooltips[ItemRefTooltip]
        and S.qitStartLines[ItemRefTooltip]
        and (type(ItemRefTooltip.IsShown) ~= "function" or ItemRefTooltip:IsShown()) then
        PinCurrentItem(ItemRefTooltip)
    end
end)
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
        if addonName == "QuestItemTracker" then
            -- The definitive SavedVariables table exists at this point,
            -- including on clients without LoadSavedVariablesFirst support.
            AttachSavedVariables()
        elseif addonName == "QuestieDB" then
            UpdateQuestieDBStatusLight()
            InstallTooltipHook()
            if S.CHARACTER_DATA then SyncQuestHistory(true) end
            BuildQuestItemIndex()
        end
    elseif event == "QUEST_ACCEPTED" then
        S.completedQuestSnapshot = nil
        HandleQuestAccepted(...)
        SyncQuestHistory(false)
    elseif event == "QUEST_TURNED_IN" then
        S.completedQuestSnapshot = nil
        HandleQuestTurnedIn(...)
        SyncQuestHistory(true)
    elseif event == "QUEST_REMOVED" then
        S.completedQuestSnapshot = nil
        HandleQuestRemoved(...)
        SyncQuestHistory(true)
    elseif event == "QUEST_LOG_UPDATE" then
        S.completedQuestSnapshot = nil
        SyncQuestHistory(false)
    end
end)

