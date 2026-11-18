-- QITF / Tooltips/Hooks.lua: owns tooltips responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local Print = assert(api.Print, "QIT load order: Print")
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local GetItemIDFromLink = assert(api.GetItemIDFromLink, "QIT load order: GetItemIDFromLink")
local ClearTurnInHover = assert(api.ClearTurnInHover, "QIT load order: ClearTurnInHover")
local UpdateTurnInHover = assert(api.UpdateTurnInHover, "QIT load order: UpdateTurnInHover")
local PinCurrentItem = assert(api.PinCurrentItem, "QIT load order: PinCurrentItem")
local AddTooltipLines = assert(api.AddTooltipLines, "QIT load order: AddTooltipLines")
local GetTooltipItem = assert(api.GetTooltipItem, "QIT load order: GetTooltipItem")
local SettingEnabled = assert(api.SettingEnabled, "QIT load order: SettingEnabled")

-- On stock Forever, Show IDs means ordinary item/spell IDs as well as IDs
-- from QITF's quest list. These are our own lines, appended with the native
-- tooltip API; never edit or resize another UI's FontStrings.
local nativeIDRows = setmetatable({}, { __mode = "k" })
local function AddNativeID(tooltip, label, id)
    if not SettingEnabled("showIDs") or not tooltip
        or type(tooltip.AddLine) ~= "function" then return end
    id = tonumber(id)
    if not id or id <= 0 or id ~= math.floor(id) then return end
    local key = label .. ":" .. tostring(id)
    if nativeIDRows[tooltip] == key then return end
    nativeIDRows[tooltip] = key  -- set before AddLine in case the UI re-enters
    tooltip:AddLine(label .. " ID: " .. tostring(id), 0.75, 0.75, 0.75)
end

-- Item and spell ID writes must share the same error boundary as quest
-- rendering. Secure or unusual tooltip frames can reject AddLine.
local function ReportTooltipError(err)
    if S.tooltipErrorReported then return end
    S.tooltipErrorReported = true
    Print("Tooltip error (first occurrence): " .. tostring(err))
end

local function RenderItemTooltip(tooltip, data, explicitItemID)
    local decorated = AddTooltipLines(tooltip, data, explicitItemID)
    if not decorated then
        -- QITF quest items already have their Item ID in Render.lua. Ordinary
        -- items get one native line here, without redoing the quest list.
        AddNativeID(tooltip, "Item", GetTooltipItem(tooltip, data, explicitItemID))
    end
    return decorated
end

local function RunTooltipHook(tooltip, data, explicitItemID)
    local ok, decorated = pcall(RenderItemTooltip, tooltip, data, explicitItemID)
    -- If Shift was already held as the player hovered the item, pin on the
    -- same callback: some bag UIs dismiss their item tooltip immediately.
    if ok and decorated == true and not S.pinnedInfo and SafeCall(IsShiftKeyDown) then
        PinCurrentItem(tooltip)
    end
    if not ok then
        nativeIDRows[tooltip] = nil
        ReportTooltipError(decorated)
    end
end

local function RunSpellTooltipHook(tooltip, data)
    local ok, err = pcall(AddNativeID, tooltip, "Spell", data and data.id)
    if not ok then
        nativeIDRows[tooltip] = nil
        ReportTooltipError(err)
    end
end

-- All reset signals invalidate the same per-tooltip state. A normal
-- client may fire more than one for a single reuse; repeated clears are safe.
local function ClearTooltipState(tooltip)
    nativeIDRows[tooltip] = nil
    S.decoratedTooltips[tooltip] = nil
    S.qitCaptures[tooltip] = nil
    ClearTurnInHover(tooltip)
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
        if ok then hooked = true; S.hookStats.legacy = true end

        pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", ClearTooltipState)
        pcall(tooltip.HookScript, tooltip, "OnHide", ClearTooltipState)
        ok = pcall(tooltip.HookScript, tooltip, "OnShow", function(self)
            RunTooltipHook(self)
        end)
        if ok then hooked = true end
        -- Native quest-row hover tracking only; no identifier polling.
        local hoverElapsed = 0
        pcall(tooltip.HookScript, tooltip, "OnUpdate", function(self, elapsed)
            if not S.pinnedInfo and S.turnInHoverRows[self] then
                hoverElapsed = hoverElapsed + (tonumber(elapsed) or 0)
                if hoverElapsed >= 0.05 then
                    hoverElapsed = 0
                    UpdateTurnInHover(self)
                end
            end
        end)
    end

    -- Certain inventory addons use setter methods without publishing a typed
    -- tooltip item or a legacy item script. Securely hook the bag/item setters
    -- to obtain the actual item ID even when tooltip:GetItem() is empty.
    if type(hooksecurefunc) == "function" then
        -- Custom bag UIs may reuse a visible tooltip and call ClearLines()
        -- without hiding it or firing OnTooltipCleared.
        if type(tooltip.ClearLines) == "function" then
            pcall(hooksecurefunc, tooltip, "ClearLines", ClearTooltipState)
        end
        if type(tooltip.SetBagItem) == "function" then
            local ok = pcall(hooksecurefunc, tooltip, "SetBagItem", function(self, bag, slot)
                local id = SafeCall(C_Container and C_Container.GetContainerItemID, bag, slot)
                RunTooltipHook(self, nil, id)
            end)
            if ok then hooked = true; S.hookStats.setters = S.hookStats.setters + 1 end
        end
        if type(tooltip.SetHyperlink) == "function" then
            local ok = pcall(hooksecurefunc, tooltip, "SetHyperlink", function(self, link)
                RunTooltipHook(self, nil, GetItemIDFromLink(link))
            end)
            if ok then hooked = true; S.hookStats.setters = S.hookStats.setters + 1 end
        end
        if type(tooltip.SetItemByID) == "function" then
            local ok = pcall(hooksecurefunc, tooltip, "SetItemByID", function(self, id)
                RunTooltipHook(self, nil, id)
            end)
            if ok then hooked = true; S.hookStats.setters = S.hookStats.setters + 1 end
        end
    end
    return hooked
end

local function InstallTooltipHook()
    if S.tooltipHooked then return true end
    local hooked = false
    if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        local ok = pcall(TooltipDataProcessor.AddTooltipPostCall,
            Enum.TooltipDataType.Item,
            function(tooltip, tooltipData)
                RunTooltipHook(tooltip, tooltipData)
            end)
        if ok then hooked = true; S.hookStats.typed = true end
        -- Forever exposes spell data in the same typed tooltip API as items.
        -- No global font hooks, OnUpdate scans, or spell-tooltip rebuilding.
        if Enum.TooltipDataType.Spell then
            local spellOk = pcall(TooltipDataProcessor.AddTooltipPostCall,
                Enum.TooltipDataType.Spell,
                RunSpellTooltipHook)
            if spellOk then hooked = true end
        end
    end

    if HookTooltipFrame(GameTooltip) then hooked = true end
    if ItemRefTooltip ~= GameTooltip and HookTooltipFrame(ItemRefTooltip) then hooked = true end
    S.tooltipHooked = hooked
    return hooked
end

api.InstallTooltipHook = InstallTooltipHook
