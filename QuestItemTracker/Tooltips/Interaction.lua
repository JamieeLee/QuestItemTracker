-- QITF / Tooltips/Interaction.lua: owns tooltips responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local GetItemName = assert(api.GetItemName, "QIT load order: GetItemName")

-- Transient detail bubbles for items with three or more matching quests.
-- The bag tooltip keeps its own mouse/owner handling; only observe the cursor.
S.turnInHoverRows = setmetatable({}, { __mode = "k" })
local turnInBubble, turnInBubbleOwner, turnInBubbleRow

local function HideTurnInBubble(owner)
    if owner and owner ~= turnInBubbleOwner then return end
    if turnInBubble then turnInBubble:Hide() end
    turnInBubbleOwner, turnInBubbleRow = nil, nil
end

local function ClearTurnInHover(tooltip)
    S.turnInHoverRows[tooltip] = nil
    HideTurnInBubble(tooltip)
end

local function ShowTurnInBubble(tooltip, row)
    if turnInBubbleOwner == tooltip and turnInBubbleRow == row then return end
    if not turnInBubble and type(CreateFrame) == "function" and UIParent then
        local bubble = SafeCall(CreateFrame, "GameTooltip", "QITTurnInHoverBubble",
            UIParent, "GameTooltipTemplate")
        if bubble and type(bubble.SetOwner) == "function"
            and type(bubble.AddLine) == "function"
            and type(bubble.ClearLines) == "function" then
            bubble:SetOwner(UIParent, "ANCHOR_NONE")
            bubble:Hide()
            turnInBubble = bubble
        end
    end
    local bubble = turnInBubble
    if not bubble then return end
    bubble:Hide()
    bubble:ClearLines()
    bubble:AddLine(row.title, 0.89, 0.72, 0.42)
    for i, location in ipairs(row.destinations) do
        if i > 10 then
            bubble:AddLine("More destinations omitted", 0.7, 0.7, 0.7)
            break
        end
        bubble:AddLine(location, 0.86, 0.83, 0.76, true)
    end
    bubble:ClearAllPoints()
    local right = SafeCall(tooltip.GetRight, tooltip)
    local width = SafeCall(UIParent.GetWidth, UIParent)
    if right and width and right + 290 > width then
        bubble:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -8, -6)
    else
        bubble:SetPoint("TOPLEFT", tooltip, "TOPRIGHT", 8, -6)
    end
    bubble:Show()
    turnInBubbleOwner, turnInBubbleRow = tooltip, row
end

local function UpdateTurnInHover(tooltip)
    local rows = S.turnInHoverRows[tooltip]
    if not rows or (type(tooltip.IsShown) == "function" and not tooltip:IsShown()) then
        HideTurnInBubble(tooltip)
        return
    end
    local px, py = SafeCall(GetCursorPosition)
    local scale = tonumber(SafeCall(tooltip.GetEffectiveScale, tooltip)) or 1
    local left = SafeCall(tooltip.GetLeft, tooltip)
    local right = SafeCall(tooltip.GetRight, tooltip)
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


-- QITF owns a snapshot of its authored quest lines, independent of the
-- native GameTooltip. Bag addons may recycle or hide that tooltip anytime.
S.qitCaptures = setmetatable({}, { __mode = "k" })
S.pinnedInfo = nil
local pinnedFrame, pinController
local pinAttempts, shiftSamples = 0, 0
local lastPinResult = "No pin attempt recorded"
local lastCandidateID

local function ShiftHeld()
    local down = SafeCall(IsShiftKeyDown)
    return down == true or down == 1
end

local function ReleasePinnedItem()
    local pinned = S.pinnedInfo
    if not pinned then return end
    S.pinnedInfo = nil
    ClearTurnInHover(pinned.frame)
    pinned.frame:Hide()
end

local function PinCurrentItem(tooltip)
    if S.pinnedInfo or not ShiftHeld() then return end
    pinAttempts = pinAttempts + 1
    local capture = tooltip and S.qitCaptures[tooltip]
    if not capture or type(capture.lines) ~= "table" or #capture.lines == 0 then
        lastPinResult = "No QITF information captured for this tooltip"
        return
    end
    lastCandidateID = capture.itemID

    if not pinnedFrame and type(CreateFrame) == "function" and UIParent then
        local frame = SafeCall(CreateFrame, "GameTooltip", "QITPinnedItemInfo",
            UIParent, "GameTooltipTemplate")
        if frame and type(frame.SetOwner) == "function"
            and type(frame.AddLine) == "function"
            and type(frame.ClearLines) == "function" then
            frame:SetOwner(UIParent, "ANCHOR_NONE")
            if type(frame.SetFrameStrata) == "function" then
                frame:SetFrameStrata("TOOLTIP")
            end
            if type(frame.SetFrameLevel) == "function" then frame:SetFrameLevel(500) end
            -- Quest row hover needs this independent tooltip to accept mouse.
            if type(frame.EnableMouse) == "function" then frame:EnableMouse(true) end
            if type(frame.SetClampedToScreen) == "function" then
                frame:SetClampedToScreen(true)
            end
            pinnedFrame = frame
        end
    end
    local frame = pinnedFrame
    if not frame then
        lastPinResult = "Pinned info frame could not be created"
        return
    end
    frame:Hide()
    frame:ClearLines()
    frame:AddLine("|cffffdfa0"
        .. (GetItemName(capture.itemID) or ("Item " .. tostring(capture.itemID)))
        .. "|r  |cff8aaac5SHIFT PINNED|r")
    for _, line in ipairs(capture.lines) do
        frame:AddLine(line.text, line.r, line.g, line.b, line.wrap)
    end
    if type(frame.SetMinimumWidth) == "function" then
        frame:SetMinimumWidth(300)
    end

    frame:ClearAllPoints()
    local left, top = SafeCall(tooltip.GetLeft, tooltip), SafeCall(tooltip.GetTop, tooltip)
    if left and top then
        local scale = tonumber(SafeCall(tooltip.GetEffectiveScale, tooltip)) or 1
        local parentScale = tonumber(SafeCall(UIParent.GetEffectiveScale, UIParent)) or 1
        if parentScale <= 0 then parentScale = 1 end
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            left * scale / parentScale, top * scale / parentScale)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    local copiedRows = {}
    for _, row in ipairs(capture.hoverRows or {}) do
        if row.captureLine then
            copiedRows[#copiedRows + 1] = {
                line = row.captureLine + 1, -- header is line 1
                title = row.title, destinations = row.destinations,
            }
        end
    end
    if #copiedRows > 0 then S.turnInHoverRows[frame] = copiedRows end
    S.pinnedInfo = { frame = frame, itemID = capture.itemID }
    lastPinResult = "Pinned item " .. tostring(capture.itemID)
    frame:Show()
end

-- A separate, always-shown watcher owns Shift; the native source tooltip's
-- OnUpdate is not reliable when an inventory addon dismisses or replaces it.
local function StartPinController()
    if pinController or type(CreateFrame) ~= "function" then return end
    pinController = CreateFrame("Frame")
    local elapsedTotal = 0
    pinController:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + (tonumber(elapsed) or 0)
        if elapsedTotal < 0.05 then return end
        elapsedTotal = 0
        if S.pinnedInfo then
            if not ShiftHeld() then ReleasePinnedItem()
            else UpdateTurnInHover(S.pinnedInfo.frame) end
            return
        end
        if not ShiftHeld() then return end
        shiftSamples = shiftSamples + 1
        if GameTooltip and S.qitCaptures[GameTooltip]
            and (type(GameTooltip.IsShown) ~= "function" or GameTooltip:IsShown()) then
            lastCandidateID = S.qitCaptures[GameTooltip].itemID
            PinCurrentItem(GameTooltip)
        elseif ItemRefTooltip and S.qitCaptures[ItemRefTooltip]
            and (type(ItemRefTooltip.IsShown) ~= "function" or ItemRefTooltip:IsShown()) then
            lastCandidateID = S.qitCaptures[ItemRefTooltip].itemID
            PinCurrentItem(ItemRefTooltip)
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
        .. " | pinned=" .. tostring(S.pinnedInfo and S.pinnedInfo.itemID or nil)
        .. " | attempts=" .. tostring(pinAttempts)
        .. " | last=" .. tostring(lastPinResult)
end

api.ClearTurnInHover = ClearTurnInHover
api.UpdateTurnInHover = UpdateTurnInHover
api.ReleasePinnedItem = ReleasePinnedItem
api.PinCurrentItem = PinCurrentItem
api.PinDiagnostics = PinDiagnostics
api.StartPinController = StartPinController
