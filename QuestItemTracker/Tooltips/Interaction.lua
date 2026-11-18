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


-- Shift locks the selected item's QITF panel, not the cursor. Copy visible
-- QITF lines so that the native bag tooltip can disappear or switch items.
S.qitStartLines = setmetatable({}, { __mode = "k" })
S.pinnedInfo = nil 
local pinnedFrame
local pinAttempts, lastPinResult = 0, "No pin attempt recorded"

local function ReleasePinnedItem()
    if not S.pinnedInfo then return end
    local frame = S.pinnedInfo.frame
    S.pinnedInfo = nil
    ClearTurnInHover(frame)
    frame:Hide()
end

local function PinCurrentItem(tooltip)
    if S.pinnedInfo or not SafeCall(IsShiftKeyDown) then return end
    pinAttempts = pinAttempts + 1
    lastPinResult = "Checking current item tooltip"
    local id = S.decoratedTooltips[tooltip]
    local start = S.qitStartLines[tooltip]
    local sourceName = SafeCall(tooltip.GetName, tooltip)
    local count = SafeCall(tooltip.NumLines, tooltip)
    if not id or not start or not count or count <= start
        or type(sourceName) ~= "string" then
        lastPinResult = "No decorated item or readable source tooltip"
        return
    end
    if not pinnedFrame and type(CreateFrame) == "function" and UIParent then
        local f = SafeCall(CreateFrame, "GameTooltip", "QITPinnedItemInfo",
            UIParent, "GameTooltipTemplate")
        if f and type(f.SetOwner) == "function" and type(f.AddLine) == "function"
            and type(f.ClearLines) == "function" then
            f:SetOwner(UIParent, "ANCHOR_NONE")
            if type(f.SetFrameStrata) == "function" then f:SetFrameStrata("TOOLTIP") end
            if type(f.SetFrameLevel) == "function" then f:SetFrameLevel(500) end
            if type(f.EnableMouse) == "function" then f:EnableMouse(false) end
            if type(f.SetClampedToScreen) == "function" then
                f:SetClampedToScreen(true)
            end
            pinnedFrame = f
        end
    end
    local frame = pinnedFrame
    if not frame then
        lastPinResult = "Pinned tooltip frame could not be created"
        return
    end
    frame:Hide()
    frame:ClearLines()
    frame:AddLine("|cffffdfa0" .. (GetItemName(id) or ("Item " .. id))
        .. "|r  |cff8aaac5SHIFT PINNED|r")
    local added = 0
    for index = start + 1, count do
        local label = _G[sourceName .. "TextLeft" .. index]
        local txt = SafeCall(label and label.GetText, label)
        if type(txt) == "string" then
            local r, g, b = SafeCall(label.GetTextColor, label)
            frame:AddLine(txt, r or 0.9, g or 0.9, b or 0.9, true)
            added = added + 1
        end
    end
    if added == 0 then
        lastPinResult = "The source tooltip had no readable QITF lines"
        return
    end
    -- The copy must size independently of the narrow native bag tooltip.
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
        frame:SetPoint("CENTER", UIParent, "CENTER", 150, 0)
    end
    if S.turnInHoverRows[tooltip] then
        local copied = {}
        for _, row in ipairs(S.turnInHoverRows[tooltip]) do
            copied[#copied + 1] = {
                line = row.line - start + 1,
                title = row.title, destinations = row.destinations,
            }
        end
        S.turnInHoverRows[frame] = copied
    end
    S.pinnedInfo = {frame = frame, itemID = id}
    lastPinResult = "Pinned item " .. tostring(id)
    -- An independent controller owns pin lifetime. GameTooltipTemplate's
    -- OnUpdate may not fire consistently with custom Forever bag UIs.
    frame:Show()
end

-- On-demand diagnostics only. Never spam chat during bag hover.
local function PinDiagnostics()
    local source = GameTooltip
    local id = source and S.decoratedTooltips[source]
    local shown = source and SafeCall(source.IsShown, source)
    return "Shift=" .. tostring(SafeCall(IsShiftKeyDown))
        .. " | selected=" .. tostring(id)
        .. " | tooltipShown=" .. tostring(shown)
        .. " | pinned=" .. tostring(S.pinnedInfo and S.pinnedInfo.itemID or nil)
        .. " | attempts=" .. tostring(pinAttempts)
        .. " | last=" .. tostring(lastPinResult)
end

api.ClearTurnInHover = ClearTurnInHover
api.UpdateTurnInHover = UpdateTurnInHover
api.ReleasePinnedItem = ReleasePinnedItem
api.PinCurrentItem = PinCurrentItem
api.PinDiagnostics = PinDiagnostics
