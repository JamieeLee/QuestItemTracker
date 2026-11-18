-- QITF / UI/Options.lua: owns ui responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local Print = assert(api.Print, "QIT load order: Print")
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local AddonVersion = assert(api.AddonVersion, "QIT load order: AddonVersion")
local QuestieDBReady = assert(api.QuestieDBReady, "QIT load order: QuestieDBReady")
local SettingEnabled = assert(api.SettingEnabled, "QIT load order: SettingEnabled")
local DEFAULT_SETTINGS = assert(NS.defaults)

local optionsPanel
S.minimapButton = nil 
local questieDBStatusLight
local QIT_STATUS_TEXTURE = "Interface\\AddOns\\QuestItemTracker\\Media\\StatusCircle"

local function SetSolidColor(texture, r, g, b, a)
    if type(texture.SetColorTexture) == "function" then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

-- Save the panel's center as offsets from UIParent, rather than absolute
-- screen coordinates. This survives /reload and ordinary UI-scale changes.
-- Missing or invalid SavedVariables fall back to the original centered layout.
local function RestoreOptionsPanelPosition(panel)
    local position = S.DB.settings.optionsPanelPosition
    local x = type(position) == "table" and tonumber(position.x) or nil
    local y = type(position) == "table" and tonumber(position.y) or nil
    if not x or x ~= x or math.abs(x) > 10000 or
        not y or y ~= y or math.abs(y) > 10000 then
        x, y = 0, 45
    end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function SaveOptionsPanelPosition(panel)
    local cx, cy = SafeCall(panel.GetCenter, panel)
    local ux, uy = SafeCall(UIParent and UIParent.GetCenter, UIParent)
    if type(cx) ~= "number" or type(cy) ~= "number" or
        type(ux) ~= "number" or type(uy) ~= "number" then return end

    local panelScale = SafeCall(panel.GetEffectiveScale, panel) or 1
    local parentScale = SafeCall(UIParent.GetEffectiveScale, UIParent) or 1
    if type(panelScale) ~= "number" or type(parentScale) ~= "number" or
        panelScale <= 0 or parentScale <= 0 then return end

    -- GetCenter values are in each frame's own scale. Convert to parent units
    -- before storing offsets for SetPoint relative to UIParent's center.
    local x = (cx * panelScale - ux * parentScale) / parentScale
    local y = (cy * panelScale - uy * parentScale) / parentScale
    if x == x and y == y and math.abs(x) <= 10000 and math.abs(y) <= 10000 then
        S.DB.settings.optionsPanelPosition = { x = x, y = y }
    end
end

-- CurseForge declares QuestieDB as REQUIRED for automatic installation.
-- The WoW TOC uses OptionalDeps instead, because a hard dependency would stop
-- QIT itself from loading when a manual ZIP user forgets QuestieDB; that would
-- make the missing-dependency warning impossible to show.
local function QuestieDBStatus()
    local ready, detail = QuestieDBReady()
    if ready then
        return true, "Quest Item Tracker Forever is ready",
            "QuestieDB: Installed and enabled. It provides the quest information QITF needs."
    end

    local exists = SafeCall(C_AddOns and C_AddOns.DoesAddOnExist, "QuestieDB")
    -- Older client versions may lack DoesAddOnExist; the reason from
    -- GetAddOnInfo distinguishes a missing folder from a disabled addon.
    local reason
    local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if type(getInfo) == "function" then
        local ok, _, _, _, _, infoReason = pcall(getInfo, "QuestieDB")
        if ok then reason = infoReason end
    end

    if exists == false or reason == "MISSING" then
        return false, "Quest Item Tracker Forever needs attention",
            "QuestieDB: Not installed. QITF needs QuestieDB to find quest items. "
                .. "CurseForge normally installs it for you. If you installed QITF "
                .. "from GitHub, install QuestieDB too, then restart or reload WoW."
    end

    local state = SafeCall(C_AddOns and C_AddOns.GetAddOnEnableState, "QuestieDB")
    if state == nil then state = SafeCall(GetAddOnEnableState, "QuestieDB") end
    if reason == "DISABLED" or state == 0 or state == false then
        return false, "Quest Item Tracker Forever needs attention",
            "QuestieDB: Installed but disabled in WoW. "
                .. "Enable QuestieDB in the AddOns list, then reload or restart the game."
    end

    local loaded = SafeCall(C_AddOns and C_AddOns.IsAddOnLoaded, "QuestieDB")
    if loaded == nil then loaded = SafeCall(IsAddOnLoaded, "QuestieDB") end
    if loaded == false then
        return false, "Quest Item Tracker Forever needs attention",
            "QuestieDB: Installed but not loaded. "
                .. "Check that it is enabled in the AddOns list and restart or reload WoW."
    end

    return false, "Quest Item Tracker Forever needs attention",
        "QuestieDB: Not ready. It's not providing the quest information QITF needs. "
            .. "Make sure you have a compatible version installed and enabled, "
            .. "then reload WoW. " .. tostring(detail or "")
end

local function UpdateQuestieDBStatusLight()
    if not questieDBStatusLight then return end
    local dot = questieDBStatusLight.dot
    if not dot or type(dot.SetVertexColor) ~= "function" then return end
    local ready = QuestieDBStatus()
    -- This is a real circular texture with a transparent background. Font
    -- symbols like "●" can become empty squares in Forever's UI font.
    dot:SetVertexColor(
        ready and 0.24 or 1,
        ready and 0.92 or 0.28,
        ready and 0.45 or 0.28,
        1
    )
end

local function CreateOptionsPanel()
    if optionsPanel then return optionsPanel end
    if not UIParent or type(CreateFrame) ~= "function" then return nil end

    local panel = CreateFrame("Frame", "QITOptionsPanel", UIParent)
    panel:SetSize(360, 540)
    RestoreOptionsPanelPosition(panel)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveOptionsPanelPosition(self)
    end)

    -- Restrained Warcraft-style frame: warm charcoal, aged-gold trim,
    -- and a quiet title band. Keep native WoW controls (checkboxes, reset,
    -- close) so other UI packs can still restyle their normal templates.
    local border = panel:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    SetSolidColor(border, 0.42, 0.33, 0.20, 0.98)
    local background = panel:CreateTexture(nil, "BORDER")
    background:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
    SetSolidColor(background, 0.055, 0.052, 0.047, 0.98)

    local headerBand = panel:CreateTexture(nil, "ARTWORK")
    headerBand:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    headerBand:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    headerBand:SetHeight(43)
    SetSolidColor(headerBand, 0.125, 0.101, 0.072, 0.96)

    local stripe = panel:CreateTexture(nil, "ARTWORK")
    stripe:SetHeight(2)
    stripe:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -45)
    stripe:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -45)
    SetSolidColor(stripe, 0.66, 0.48, 0.25, 0.94)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
    title:SetText("Quest Item Tracker Forever")
    if type(title.SetTextColor) == "function" then
        title:SetTextColor(1, 0.82, 0.41, 1)
    end
    local version = AddonVersion()
    if version then
        local versionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        versionLabel:SetPoint("LEFT", title, "RIGHT", 8, -2)
        versionLabel:SetText("v" .. version)
        if type(versionLabel.SetTextColor) == "function" then
            versionLabel:SetTextColor(0.62, 0.58, 0.49, 1)
        end
    end
    local subTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -58)
    subTitle:SetText("Tooltip preferences  |  Saved automatically")
    if type(subTitle.SetTextColor) == "function" then
        subTitle:SetTextColor(0.79, 0.75, 0.67, 1)
    end

    -- Only a small green/red dot, not another label or block in the menu.
    -- Hovering it explains whether QuestieDB is working and what to fix.
    local statusLight = CreateFrame("Button", "QITQuestieDBStatus", panel)
    statusLight:SetSize(20, 20)
    statusLight:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -19, -52)
    statusLight:EnableMouse(true)
    local dot = statusLight:CreateTexture(nil, "ARTWORK")
    dot:SetSize(18, 18)
    dot:SetPoint("CENTER", statusLight, "CENTER", 0, 0)
    dot:SetTexture(QIT_STATUS_TEXTURE)
    statusLight.dot = dot
    questieDBStatusLight = statusLight
    statusLight:SetScript("OnEnter", function(self)
        if not GameTooltip or type(GameTooltip.SetOwner) ~= "function"
            or type(GameTooltip.SetText) ~= "function"
            or type(GameTooltip.AddLine) ~= "function" then return end
        local ready, title, explanation = QuestieDBStatus()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, ready and 0.28 or 1, ready and 0.9 or 0.3, ready and 0.4 or 0.3)
        GameTooltip:AddLine(explanation, 0.95, 0.95, 0.95, true)
        GameTooltip:Show()
    end)
    statusLight:SetScript("OnLeave", function(self)
        if GameTooltip and type(GameTooltip.GetOwner) == "function"
            and GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
    UpdateQuestieDBStatusLight()

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() panel:Hide() end)

    -- Keep the menu labels short. Hover over any option to understand its
    -- effect in everyday language; the item tooltip itself stays uncluttered.
    local entries = {
        {
            key = "filterByFaction", label = "Only show my faction quests", y = -87,
            help = "Show quests meant for your faction, along with neutral quests. "
                .. "Quests marked for the opposite faction are hidden. "
                .. "Quests you're already working on still appear.",
        },
        {
            key = "suppressExternalIDs", label = "Hide IDs from other addons", y = -154,
            help = "Hide extra number-only details, such as ItemID and IconID, "
                .. "that other addons put on item tooltips. "
                .. "This is off by default and does not change the other addons' settings "
                .. "or hide IDs shown by QITF.",
        },
        {
            key = "showQuestIDs", label = "Show QITF quest IDs", y = -190,
            help = "Show the identifying number for each quest listed by QITF. "
                .. "For example, you can use a quest ID to identify a particular quest "
                .. "when asking for help. This does not control IDs from other addons.",
        },
        {
            key = "showItemIDs", label = "Show QITF item IDs", y = -226,
            help = "Show the item's identifying number inside QITF's section of "
                .. "the tooltip. This can help when reporting an item problem. "
                .. "Other addons' ItemID lines are controlled by the option above.",
        },
        {
            key = "showQuestLevels", label = "Show quest levels", y = -285,
            help = "Show each quest's level next to its name, such as Level 60. "
                .. "Turn this off for shorter quest names without changing which quests appear.",
        },
        {
            key = "showInventoryBreakdown", label = "Show bag / bank breakdown", y = -321,
            help = "Show how many copies of an item are in your bags and bank, "
                .. "next to the total you have. Turn this off to see just the total; "
                .. "QITF still counts your items.",
        },
        {
            key = "showFutureStatusLabels", label = "Show future quest labels", y = -357,
            help = "Add extra explanations for quests you could do later, "
                .. "such as FUTURE QUEST, plus a summary when an item has only future uses. "
                .. "Leaving this off keeps the tooltip shorter without removing "
                .. "important KEEP or NEEDED advice.",
        },
        {
            key = "showTurnInDetails", label = "Show turn-in NPC and zone", y = -394,
            help = "Show where to hand in a quest item using QuestieDB's known "
                .. "quest-finisher name and zone. Unknown destinations are omitted. "
                .. "This is on by default; it does not add map tracking.",
        },
        {
            key = "showTurnInCoordinates", label = "Show turn-in coordinates", y = -430,
            help = "Add one known location's coordinates after the NPC and zone, "
                .. "when QuestieDB has them. Off by default. Requires the "
                .. "turn-in NPC and zone option above.",
        },
    }
    local idsHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    idsHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -132)
    idsHeading:SetText("ID DISPLAY")
    if type(idsHeading.SetTextColor) == "function" then idsHeading:SetTextColor(0.82, 0.65, 0.38, 1) end
    local detailsHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailsHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -263)
    detailsHeading:SetText("OTHER DETAILS")
    if type(detailsHeading.SetTextColor) == "function" then detailsHeading:SetTextColor(0.82, 0.65, 0.38, 1) end
    local checkboxes = {}
    for i, entry in ipairs(entries) do
        local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        checkbox:SetSize(25, 25)
        checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, entry.y)
        checkbox:SetChecked(SettingEnabled(entry.key))
        -- Expand the checkbox's mouse area across its text, so hovering
        -- anywhere on the option shows its help and clicking text works too.
        if type(checkbox.SetHitRectInsets) == "function" then
            checkbox:SetHitRectInsets(0, -255, 0, 0)
        end
        checkbox:SetScript("OnEnter", function(self)
            if not GameTooltip or type(GameTooltip.SetOwner) ~= "function"
                or type(GameTooltip.SetText) ~= "function"
                or type(GameTooltip.AddLine) ~= "function" then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.label, 0.92, 0.77, 0.49)
            GameTooltip:AddLine(entry.help, 0.95, 0.95, 0.95, true)
            GameTooltip:Show()
        end)
        checkbox:SetScript("OnLeave", function(self)
            if GameTooltip and type(GameTooltip.GetOwner) == "function"
                and GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end)
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
        label:SetText(entry.label)
        checkbox:SetScript("OnClick", function(self)
            S.DB.settings[entry.key] = self:GetChecked() == true
        end)
        checkboxes[#checkboxes + 1] = { frame = checkbox, key = entry.key }
    end

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(125, 24)
    reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 19)
    reset:SetText("Reset defaults")
    reset:SetScript("OnClick", function()
        for key, value in pairs(DEFAULT_SETTINGS) do S.DB.settings[key] = value end
        S.DB.settings.optionsPanelPosition = nil
        RestoreOptionsPanelPosition(panel)
        for _, row in ipairs(checkboxes) do
            row.frame:SetChecked(SettingEnabled(row.key))
        end
    end)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -17, 23)
    hint:SetText("Changes apply on next hover")
    if type(hint.SetTextColor) == "function" then
        hint:SetTextColor(0.63, 0.60, 0.54, 1)
    end
    panel:SetScript("OnShow", function()
        UpdateQuestieDBStatusLight()
        for _, row in ipairs(checkboxes) do
            row.frame:SetChecked(SettingEnabled(row.key))
        end
    end)
    panel:Hide()
    optionsPanel = panel
    return panel
end

local function ToggleOptionsPanel()
    local panel = CreateOptionsPanel()
    if not panel then
        Print("Settings UI is unavailable. The minimap may not be initialized yet.")
        return
    end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

api.UpdateQuestieDBStatusLight = UpdateQuestieDBStatusLight
api.ToggleOptionsPanel = ToggleOptionsPanel
