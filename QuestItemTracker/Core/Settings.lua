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
local function SettingEnabled(key)
    local value = S.DB.settings[key]
    if value == nil and key == "showIDs" then
        return S.DB.settings.showQuestIDs == true
            or S.DB.settings.showItemIDs == true
    end
    if value == nil then return DEFAULT_SETTINGS[key] == true end
    return value == true
end

-- Unified Show IDs setting. Technical ID rows may be supplied by another
-- addon using the same GameTooltip. FontStrings are reused: never change
-- text, geometry or anchors, which can clip later tooltips (e.g. Hearthstone).
local ID_KINDS = {
    itemid = true, iconid = true, questid = true, spellid = true,
    npcid = true, textureid = true, modelid = true,
}
local originalAlpha = setmetatable({}, { __mode = "k" })

local function RestoreExternalIDVisibility(tooltip)
    local stored = originalAlpha[tooltip]
    if not stored then return end
    for fontString, alpha in pairs(stored) do
        if type(alpha) == "number" then
            SafeCall(fontString.SetAlpha, fontString, alpha)
        end
    end
    originalAlpha[tooltip] = nil
end

local function SuppressExternalTooltipIDs(tooltip)
    if not tooltip then return end
    -- Restore previous rows first; they may have been reused for different
    -- text without firing a clear/hide event.
    RestoreExternalIDVisibility(tooltip)
    if SettingEnabled("showIDs") then return end
    local name = SafeCall(tooltip.GetName, tooltip)
    local count = tonumber(SafeCall(tooltip.NumLines, tooltip))
    if type(name) ~= "string" or name == "" or not count then return end

    local stored
    for i = 1, math.min(count, 100) do
        local left = _G[name .. "TextLeft" .. i]
        local line = left and SafeCall(left.GetText, left)
        if type(line) == "string" and line ~= "" then
            if string.find(line, "Quest Item Tracker Forever", 1, true) then break end
            local clean = string.gsub(line, "|c%x%x%x%x%x%x%x%x", "")
            clean = string.gsub(clean, "|r", "")
            clean = string.gsub(clean, "^%s+", "")
            clean = string.gsub(clean, "%s+$", "")
            local label = string.match(clean, "^([%a%s]+)%s*:%s*%d*$")
                or string.match(clean, "^([%a%s]+)%s+%d+$")
                or string.match(clean, "^([%a%s]+)$")
            local normalized = label and string.lower(string.gsub(label, "%s+", ""))
            if normalized and ID_KINDS[normalized] then
                stored = stored or {}
                local right = _G[name .. "TextRight" .. i]
                for _, stringRegion in ipairs({ left, right }) do
                    if stringRegion and type(stringRegion.SetAlpha) == "function" then
                        local alpha = SafeCall(stringRegion.GetAlpha, stringRegion)
                        if type(alpha) == "number" then
                            stored[stringRegion] = alpha
                            SafeCall(stringRegion.SetAlpha, stringRegion, 0)
                        end
                    end
                end
            end
        end
    end
    if stored then originalAlpha[tooltip] = stored end
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
api.RestoreExternalIDVisibility = RestoreExternalIDVisibility
api.SuppressExternalTooltipIDs = SuppressExternalTooltipIDs
api.QuestMatchesPlayerFaction = QuestMatchesPlayerFaction
