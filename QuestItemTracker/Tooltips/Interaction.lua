-- Tooltip interaction only: native quest-row observation and independent
-- QITF panels. Rendering/layout lives in Tooltips/Panel.lua.
local _, NS = ...
local S = assert(NS.state)
local api = assert(NS.api)
local SafeCall = assert(api.SafeCall)
local GetItemName = assert(api.GetItemName)
local NewInfoPanel = assert(api.NewInfoPanel)

-- Native GameTooltip rows may have destinations; the pinned QITF panel has
-- its own real mouse hit boxes and never requires native fontstring lookups.
S.turnInHoverRows = setmetatable({}, { __mode = "k" })
S.qitCaptures = setmetatable({}, { __mode = "k" })
S.pinnedInfo = nil

local turnInBubble, turnInBubbleOwner, turnInBubbleRow
local pinnedPanel, pinController
local pinAttempts, pinSuccesses, shiftSamples = 0, 0, 0
local lastPinResult = "No pin attempt recorded"
local lastRelease = "Not pinned yet"
local lastPosition = "Not positioned"
local lastCandidateID

local function ShiftHeld()
    local down = SafeCall(IsShiftKeyDown)
    return down == true or down == 1
end

local function HideTurnInBubble(owner)
    if owner and owner ~= turnInBubbleOwner then return end
    if turnInBubble then turnInBubble.frame:Hide() end
    turnInBubbleOwner, turnInBubbleRow = nil, nil
end

local function ClearTurnInHover(tooltip)
    S.turnInHoverRows[tooltip] = nil
    HideTurnInBubble(tooltip)
end

local function ShowTurnInBubble(owner, row)
    if turnInBubbleOwner == owner and turnInBubbleRow == row then return end
    if not turnInBubble then
        turnInBubble = NewInfoPanel("QITTurnInHoverBubble", 285, false)
    end
    if not turnInBubble then return end
    local lines = { { text = row.title, r = 0.89, g = 0.72, b = 0.42 } }
    for i, location in ipairs(row.destinations or {}) do
        if i > 10 then
            lines[#lines + 1] = { text = "More destinations omitted", r = 0.7, g = 0.7, b = 0.7 }
            break
        end
        lines[#lines + 1] = { text = location, r = 0.86, g = 0.83, b = 0.76 }
    end
    turnInBubble:Render(lines)
    local bubble = turnInBubble.frame
    bubble:ClearAllPoints()
    local right = tonumber(SafeCall(owner.GetRight, owner))
    local scale = tonumber(SafeCall(owner.GetEffectiveScale, owner)) or 1
    local parentScale = tonumber(SafeCall(UIParent.GetEffectiveScale, UIParent)) or 1
    local screenWidth = tonumber(SafeCall(UIParent.GetWidth, UIParent))
    if parentScale <= 0 then parentScale = 1 end
    if right and screenWidth and right * scale / parentScale + 300 > screenWidth then
        bubble:SetPoint("TOPRIGHT", owner, "TOPLEFT", -10, -3)
    else
        bubble:SetPoint("TOPLEFT", owner, "TOPRIGHT", 10, -3)
    end
    turnInBubbleOwner, turnInBubbleRow = owner, row
    bubble:Show()
end

local function UpdateTurnInHover(tooltip)
    local rows = S.turnInHoverRows[tooltip]
    if not rows or (type(tooltip.IsShown) == "function" and not tooltip:IsShown()) then
        HideTurnInBubble(tooltip)
        return
    end
    local px, py = SafeCall(GetCursorPosition)
    local scale = tonumber(SafeCall(tooltip.GetEffectiveScale, tooltip)) or 1
    local left, right = SafeCall(tooltip.GetLeft, tooltip), SafeCall(tooltip.GetRight, tooltip)
    local hovered
    if scale > 0 and px and py and left and right then
        px, py = px / scale, py / scale
        if px >= left and px <= right then
            local name = SafeCall(tooltip.GetName, tooltip)
            for _, row in ipairs(rows) do
                local label = name and _G[name .. "TextLeft" .. row.line]
                local top = SafeCall(label and label.GetTop, label)
                local bottom = SafeCall(label and label.GetBottom, label)
                if top and bottom and py <= top and py >= bottom then
                    hovered = row
                    break
                end
            end
        end
    end
    if hovered then ShowTurnInBubble(tooltip, hovered)
    else HideTurnInBubble(tooltip) end
end

local function ReleasePinnedItem(reason)
    local pinned = S.pinnedInfo
    if not pinned then return end
    lastRelease = tostring(reason or "released") .. " (item " .. tostring(pinned.itemID) .. ")"
    S.pinnedInfo = nil
    HideTurnInBubble(pinned.frame)
    pinned.frame:Hide()
end

local function PinCurrentItem(tooltip)
    if S.pinnedInfo or not ShiftHeld() then return end
    local capture = tooltip and S.qitCaptures[tooltip]
    if not capture or not capture.lines or #capture.lines == 0 then return end
    lastCandidateID = capture.itemID
    pinAttempts = pinAttempts + 1
    if not pinnedPanel then
        pinnedPanel = NewInfoPanel("QITPinnedItemInfo", 330, true)
    end
    if not pinnedPanel then
        lastPinResult = "Pinned frame creation failed"
        return
    end
    local frame = pinnedPanel.frame
    frame:Hide()
    local content = {
        { text = "|cffffdfa0" .. GetItemName(capture.itemID)
            .. "|r  |cff8aaac5SHIFT PINNED|r" },
    }
    for _, line in ipairs(capture.lines) do content[#content + 1] = line end
    local hoverTargets = {}
    for _, row in ipairs(capture.hoverRows or {}) do
        if row.captureLine then
            hoverTargets[row.captureLine + 1] = row
        end
    end
    pinnedPanel:Render(content, hoverTargets,
        function(row) ShowTurnInBubble(frame, row) end,
        function() HideTurnInBubble(frame) end)

    -- Anchor ONCE to screen coordinates. The panel is never owned or moved
    -- by the native tooltip or cursor, even if the bag addon recycles it.
    frame:ClearAllPoints()
    local left = tonumber(SafeCall(tooltip.GetLeft, tooltip))
    local right = tonumber(SafeCall(tooltip.GetRight, tooltip))
    local top = tonumber(SafeCall(tooltip.GetTop, tooltip))
    local scale = tonumber(SafeCall(tooltip.GetEffectiveScale, tooltip)) or 1
    local parentScale = tonumber(SafeCall(UIParent.GetEffectiveScale, UIParent)) or 1
    local screenWidth = tonumber(SafeCall(UIParent.GetWidth, UIParent))
    if parentScale <= 0 then parentScale = 1 end
    local ratio, gap, panelWidth = scale / parentScale, 12, 330
    if right and top and screenWidth and right * ratio + gap + panelWidth <= screenWidth then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            right * ratio + gap, top * ratio)
        lastPosition = "Right of source"
    elseif left and top and left * ratio >= panelWidth + gap then
        frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT",
            left * ratio - gap, top * ratio)
        lastPosition = "Left of source"
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        lastPosition = "Screen center"
    end
    S.pinnedInfo = { frame = frame, itemID = capture.itemID }
    frame:Show()
    local shown = type(frame.IsShown) ~= "function" or frame:IsShown()
    pinSuccesses = pinSuccesses + 1
    lastPinResult = "Pinned item " .. tostring(capture.itemID)
        .. "; visible=" .. tostring(shown)
end

local function TryPinFromVisibleSource()
    if S.pinnedInfo or not ShiftHeld() then return end
    local source = GameTooltip
    if source and S.qitCaptures[source]
        and (type(source.IsShown) ~= "function" or source:IsShown()) then
        PinCurrentItem(source)
        return
    end
    source = ItemRefTooltip
    if source and source ~= GameTooltip and S.qitCaptures[source]
        and (type(source.IsShown) ~= "function" or source:IsShown()) then
        PinCurrentItem(source)
    end
end

local function StartPinController()
    if pinController or type(CreateFrame) ~= "function" then return end
    pinController = CreateFrame("Frame", "QITPinController")
    pinController:RegisterEvent("MODIFIER_STATE_CHANGED")
    pinController:SetScript("OnEvent", function(_, _, key)
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        if ShiftHeld() then TryPinFromVisibleSource()
        else ReleasePinnedItem("Shift released") end
    end)
    -- Fallback for the Forever client or other UIs that do not fire a
    -- modifier callback while a bag is focused; only 20 checks/second.
    local accumulated = 0
    pinController:SetScript("OnUpdate", function(_, elapsed)
        accumulated = accumulated + (tonumber(elapsed) or 0)
        if accumulated < 0.05 then return end
        accumulated = 0
        if S.pinnedInfo then
            if not ShiftHeld() then ReleasePinnedItem("Shift released") end
        elseif ShiftHeld() then
            shiftSamples = shiftSamples + 1
            TryPinFromVisibleSource()
        end
    end)
    pinController:Show()
end

local function PinDiagnostics()
    local source = GameTooltip
    local capture = source and S.qitCaptures[source]
    return "ShiftNow=" .. tostring(ShiftHeld())
        .. " | shiftPolls=" .. tostring(shiftSamples)
        .. " | selected=" .. tostring(capture and capture.itemID or nil)
        .. " | lastCandidate=" .. tostring(lastCandidateID)
        .. " | tooltipShown=" .. tostring(source and SafeCall(source.IsShown, source))
        .. " | pinnedNow=" .. tostring(S.pinnedInfo and S.pinnedInfo.itemID or nil)
        .. " | attempts=" .. tostring(pinAttempts)
        .. " | successes=" .. tostring(pinSuccesses)
        .. " | last=" .. tostring(lastPinResult)
        .. " | position=" .. lastPosition
        .. " | released=" .. lastRelease
end

api.ClearTurnInHover = ClearTurnInHover
api.UpdateTurnInHover = UpdateTurnInHover
api.ReleasePinnedItem = ReleasePinnedItem
api.PinCurrentItem = PinCurrentItem
api.PinDiagnostics = PinDiagnostics
api.StartPinController = StartPinController
