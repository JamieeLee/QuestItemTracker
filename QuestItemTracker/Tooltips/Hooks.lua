-- QITF / Tooltips/Hooks.lua: owns tooltips responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local Print = assert(api.Print, "QIT load order: Print")
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local GetItemIDFromLink = assert(api.GetItemIDFromLink, "QIT load order: GetItemIDFromLink")
local SettingEnabled = assert(api.SettingEnabled, "QIT load order: SettingEnabled")
local RestoreExternalIDVisibility = assert(api.RestoreExternalIDVisibility, "QIT load order: RestoreExternalIDVisibility")
local SuppressExternalTooltipIDs = assert(api.SuppressExternalTooltipIDs, "QIT load order: SuppressExternalTooltipIDs")
local ClearTurnInHover = assert(api.ClearTurnInHover, "QIT load order: ClearTurnInHover")
local UpdateTurnInHover = assert(api.UpdateTurnInHover, "QIT load order: UpdateTurnInHover")
local PinCurrentItem = assert(api.PinCurrentItem, "QIT load order: PinCurrentItem")
local AddTooltipLines = assert(api.AddTooltipLines, "QIT load order: AddTooltipLines")

local function RunTooltipHook(tooltip, data, explicitItemID)
    local ok, err = pcall(AddTooltipLines, tooltip, data, explicitItemID)
    -- Apply the single ID visibility policy to all standard item tooltips,
    -- including ordinary items that never receive a QITF quest section.
    SuppressExternalTooltipIDs(tooltip)
    -- If Shift was already held as the player hovered the item, pin on the
    -- same callback: some bag UIs dismiss their item tooltip immediately.
    if ok and err == true and not S.pinnedInfo and SafeCall(IsShiftKeyDown) then
        PinCurrentItem(tooltip)
    end
    if not ok and not S.tooltipErrorReported then
        S.tooltipErrorReported = true
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
        if ok then hooked = true; S.hookStats.legacy = true end

        pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", function(self)
            S.decoratedTooltips[self] = nil
            S.qitCaptures[self] = nil
            ClearTurnInHover(self)
            RestoreExternalIDVisibility(self)
        end)
        pcall(tooltip.HookScript, tooltip, "OnHide", function(self)
            S.decoratedTooltips[self] = nil
            S.qitCaptures[self] = nil
            ClearTurnInHover(self)
            RestoreExternalIDVisibility(self)
        end)
        ok = pcall(tooltip.HookScript, tooltip, "OnShow", function(self)
            RunTooltipHook(self)
        end)
        if ok then hooked = true end
        -- Some inventory UIs append IDs after their regular tooltip callbacks.
        -- Check at most every 0.15 seconds, not every rendered frame.
        local rescanElapsed, hoverElapsed = 0, 0
        pcall(tooltip.HookScript, tooltip, "OnUpdate", function(self, elapsed)
            if not S.pinnedInfo and S.turnInHoverRows[self] then
                hoverElapsed = hoverElapsed + (tonumber(elapsed) or 0)
                if hoverElapsed >= 0.05 then
                    hoverElapsed = 0
                    UpdateTurnInHover(self)
                end
            end
            if SettingEnabled("showIDs") then
                rescanElapsed = 0
                return
            end
            rescanElapsed = rescanElapsed + (tonumber(elapsed) or 0)
            if rescanElapsed >= 0.15 then
                rescanElapsed = 0
                SuppressExternalTooltipIDs(self)
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
            pcall(hooksecurefunc, tooltip, "ClearLines", function(self)
                S.decoratedTooltips[self] = nil
                S.qitCaptures[self] = nil
                ClearTurnInHover(self)
                RestoreExternalIDVisibility(self)
            end)
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
    end

    if HookTooltipFrame(GameTooltip) then hooked = true end
    if ItemRefTooltip ~= GameTooltip and HookTooltipFrame(ItemRefTooltip) then hooked = true end
    S.tooltipHooked = hooked
    return hooked
end

api.InstallTooltipHook = InstallTooltipHook
