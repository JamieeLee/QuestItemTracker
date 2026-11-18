-- QITF / Core/Settings.lua: owns core responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local GetItemIDFromLink = assert(api.GetItemIDFromLink, "QIT load order: GetItemIDFromLink")

local function GetTooltipItem(tooltip, data, explicitItemID)
    -- A bag setter supplies a trustworthy itemID even if the client did not
    -- populate GetItem() yet. The typed item callback supplies data.id.
    local explicit = tonumber(explicitItemID)
    if explicit and explicit > 0 then return explicit, nil end
    if type(data) == "table" then
        local dataID = tonumber(data.id) or tonumber(data.itemID)
        if dataID and dataID > 0 then return dataID, nil end
        local linkID = GetItemIDFromLink(data.hyperlink or data.itemLink)
        if linkID then return linkID, nil end
    end
    if tooltip and type(tooltip.GetItem) == "function" then
        local name, link = SafeCall(tooltip.GetItem, tooltip)
        local linkID = GetItemIDFromLink(link)
        if linkID then return linkID, name end
    end
    if tooltip and type(tooltip.GetPrimaryTooltipData) == "function" then
        local primary = SafeCall(tooltip.GetPrimaryTooltipData, tooltip)
        if type(primary) == "table" then
            local itemType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
            if not itemType or primary.type == itemType then
                local dataID = tonumber(primary.id) or tonumber(primary.itemID)
                if dataID and dataID > 0 then return dataID, nil end
                local linkID = GetItemIDFromLink(primary.hyperlink or primary.itemLink)
                if linkID then return linkID, nil end
            end
        end
    end
    return nil, nil
end

-- Keep the default tooltip focused on player-facing information; technical IDs are opt-in.
local DEFAULT_SETTINGS = {
    showIDs = false,
    showQuestLevels = true,
    showInventoryBreakdown = true,
    filterByFaction = true,
    showTurnInDetails = true,
    showTurnInCoordinates = false,
}
local ExternalIDOwner
local function SettingEnabled(key)
    -- When a UI supplies its own ID controls, its presentation takes
    -- precedence. Leave the player's saved QITF preference untouched.
    if key == "showIDs" and ExternalIDOwner() then return false end
    local value = S.DB.settings[key]
    if value == nil and key == "showIDs" then
        return S.DB.settings.showQuestIDs == true
            or S.DB.settings.showItemIDs == true
    end
    if value == nil then return DEFAULT_SETTINGS[key] == true end
    return value == true or value == 1
end

-- QITF only controls the identifiers that QITF itself adds. Modifying
-- another addon's GameTooltipTextLeftN/RightN fontstrings changed their layout
-- and caused clipped Hearthstone/spell descriptions on the Forever client.
-- There is no standard WoW API to identify every third-party tooltip provider.
-- Recognize a provider by a concrete, publicly exposed capability, never by
-- scanning a tooltip's fontstrings or trying to rewrite its ID lines.
ExternalIDOwner = function()
    local ui = _G and _G.EllesmereUI
    if type(ui) == "table" and type(ui.SpellIDOn) == "function" then
        return "EllesmereUI"
    end
    return nil
end

-- QuestieDB exposes active-flavor faction race masks in contract 3+. Forever
-- masks include high bits (Skyborne), so WoW's 32-bit bit.band would truncate them.
-- Comparing one bit at a time preserves the full numeric mask in Lua doubles.
local function MasksIntersect(a, b)
    if type(a) ~= "number" or type(b) ~= "number" or a <= 0 or b <= 0 then
        return false
    end
    a, b = math.floor(a), math.floor(b)
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then return true end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
    end
    return false
end

local function QuestMatchesPlayerFaction(questID, activeMap)
    if not SettingEnabled("filterByFaction") then return true end
    -- A currently accepted quest is always relevant, even if its DB flags lag.
    if activeMap and activeMap[questID] then return true end

    local faction = SafeCall(UnitFactionGroup, "player")
    if faction ~= "Alliance" and faction ~= "Horde" then return true end
    local enum = LibQuestieDB and LibQuestieDB.Enum
    local factionMasks = enum and enum.factionRaceMasks
    local allowedMask = factionMasks and factionMasks[faction]
    if type(allowedMask) ~= "number" or allowedMask <= 0 then return true end

    local required = SafeCall(QuestDB and QuestDB.requiredRaces, questID)
    -- Unrestricted (0) or missing data means the quest may be neutral. Don't
    -- hide unknowns: only filter quests explicitly excluded by the race mask.
    if type(required) ~= "number" or required <= 0 then return true end
    return MasksIntersect(required, allowedMask)
end

NS.defaults = DEFAULT_SETTINGS

api.GetTooltipItem = GetTooltipItem
api.SettingEnabled = SettingEnabled
api.ExternalIDOwner = ExternalIDOwner
api.QuestMatchesPlayerFaction = QuestMatchesPlayerFaction
