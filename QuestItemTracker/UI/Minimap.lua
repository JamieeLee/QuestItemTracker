-- QITF / UI/Minimap.lua: owns ui responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local ToggleOptionsPanel = assert(api.ToggleOptionsPanel, "QIT load order: ToggleOptionsPanel")

local QIT_BADGE_TEXTURE = "Interface\\AddOns\\QuestItemTracker\\Media\\QITForeverBadge"

-- Position the minimap button around the actual rim, keeping saved drag
-- directions compatible with earlier builds. The radius adjusts to size.
local MINIMAP_EDGE_PADDING = 5
local MINIMAP_SAVE_RADIUS = 80

local function MinimapDirection()
    -- Restore the committed drop position after /reload. Keep historical
    -- X/Y fields as a fallback for players upgrading from older versions.
    local saved = S.DB.settings.minimapPosition
    if type(saved) == "table" then
        local sx, sy = tonumber(saved.x), tonumber(saved.y)
        if sx and sy and sx == sx and sy == sy then
            local length = math.sqrt(sx * sx + sy * sy)
            if length > 0.001 and length < 10000 then
                return sx / length, sy / length
            end
        end
    end
    local x = tonumber(S.DB.settings.minimapX) or 75
    local y = tonumber(S.DB.settings.minimapY) or -28
    local length = math.sqrt(x * x + y * y)
    if length < 0.001 then return 1, 0 end
    return x / length, y / length
end

local function PlaceMinimapButton()
    if not S.minimapButton or not Minimap then return end
    local nx, ny = MinimapDirection()
    local width = tonumber(SafeCall(Minimap.GetWidth, Minimap)) or 140
    local height = tonumber(SafeCall(Minimap.GetHeight, Minimap)) or width
    if width <= 0 then width = 140 end
    if height <= 0 then height = width end

    -- Square minimap skins use the perimeter rather than a round orbit.
    local shape = SafeCall(GetMinimapShape)
    if shape == "SQUARE" then
        local edge = math.max(math.abs(nx), math.abs(ny))
        if edge > 0 then nx, ny = nx / edge, ny / edge end
    end

    local x = nx * (width / 2 + MINIMAP_EDGE_PADDING)
    local y = ny * (height / 2 + MINIMAP_EDGE_PADDING)
    S.minimapButton:ClearAllPoints()
    S.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function SaveMinimapCursorDirection()
    if not Minimap or type(GetCursorPosition) ~= "function" then return false end
    local mouseX, mouseY = SafeCall(GetCursorPosition)
    local centerX, centerY = SafeCall(Minimap.GetCenter, Minimap)
    local scale = tonumber(SafeCall(Minimap.GetEffectiveScale, Minimap)) or 1
    if type(mouseX) ~= "number" or type(mouseY) ~= "number"
        or type(centerX) ~= "number" or type(centerY) ~= "number"
        or scale <= 0 then return false end
    local dx, dy = mouseX / scale - centerX, mouseY / scale - centerY
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return false end
    -- Persist *while* dragging, not only on drag-stop. Some UI clients
    -- can miss a final release callback even though the icon moves normally;
    -- a reload must still restore the last position reached on the rim.
    local nx, ny = dx / distance, dy / distance
    S.DB.settings.minimapX = nx * MINIMAP_SAVE_RADIUS
    S.DB.settings.minimapY = ny * MINIMAP_SAVE_RADIUS
    S.DB.settings.minimapPosition = { x = nx, y = ny }
    PlaceMinimapButton()
    return true
end

local function FinishMinimapDrag(button)
    if not button.qitDragging then return end
    button.qitDragging = false
    button:SetScript("OnUpdate", nil)
    -- The last cursor event may have occurred between update frames.
    SaveMinimapCursorDirection()
    -- One final save in case the cursor moved after the last frame update.
    -- The same durable direction is also written during every drag update.
    local nx, ny = MinimapDirection()
    S.DB.settings.minimapPosition = { x = nx, y = ny }
    PlaceMinimapButton()
end

local function CreateMinimapButton()
    if S.minimapButton or not Minimap or type(CreateFrame) ~= "function" then return end
    local button = CreateFrame("Button", "QITMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    -- The approved gold QIT / FOREVER minimap badge has its own border.
    -- Keep the existing rim alignment and drag behavior, but do not overlay
    -- a second tracking border that obscures the badge's lettering.
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture(QIT_BADGE_TEXTURE)

    button:SetScript("OnClick", ToggleOptionsPanel)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Quest Item Tracker Forever", 0.96, 0.79, 0.40)
        GameTooltip:AddLine("Click: tooltip settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move minimap button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip and type(GameTooltip.Hide) == "function" then GameTooltip:Hide() end
    end)
    button:SetScript("OnDragStart", function(self)
        -- Orbit around the minimap as the cursor moves, rather than briefly
        -- dragging the button through the middle and snapping it back.
        self.qitDragging = true
        self:SetScript("OnUpdate", SaveMinimapCursorDirection)
    end)
    button:SetScript("OnDragStop", FinishMinimapDrag)
    -- Some client/UI combinations send OnMouseUp but not OnDragStop.
    -- A plain click is unaffected because qitDragging is only set by drag.
    button:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" then FinishMinimapDrag(self) end
    end)
    S.minimapButton = button
    PlaceMinimapButton()
    -- Minimap replacement/scale addons sometimes resize their map after login.
    if type(Minimap.HookScript) == "function" then
        Minimap:HookScript("OnSizeChanged", PlaceMinimapButton)
    end
end

api.CreateMinimapButton = CreateMinimapButton
