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
    showQuestIDs = false,
    showItemIDs = false,
    suppressExternalIDs = false,
    showQuestLevels = true,
    showInventoryBreakdown = true,
    showFutureStatusLabels = false,
    filterByFaction = true,
    showTurnInDetails = true,
    showTurnInCoordinates = false,
}
local function SettingEnabled(key)
    local value = S.DB.settings[key]
    if value == nil then return DEFAULT_SETTINGS[key] == true end
    return value == true
end

-- This optional filter only touches isolated technical ID rows that another
-- addon put on a shared item tooltip. It never modifies QIT's own ID settings,
-- and stops at the QIT header so QIT-generated lines are left untouched.
-- Tooltip font strings are reused by WoW, so restore adjusted heights on reset.
local EXTERNAL_ID_KINDS = {
    itemid = true, iconid = true, questid = true, spellid = true,
    npcid = true, textureid = true, modelid = true,
}
local suppressedLineHeights = setmetatable({}, { __mode = "k" })

local function RestoreExternalIDHeights(tooltip)
    local stored = suppressedLineHeights[tooltip]
    if not stored then return end
    for fontString, height in pairs(stored) do
        if type(height) == "number" and height > 0 then
            SafeCall(fontString.SetHeight, fontString, height)
        end
    end
    suppressedLineHeights[tooltip] = nil
end

local function SuppressExternalTooltipIDs(tooltip)
    if not SettingEnabled("suppressExternalIDs") or not tooltip then return end
    -- Standard GameTooltip exposes named TextLeftN/TextRightN font strings.
    -- Do not guess at the internals of arbitrary custom tooltip frames.
    local name = SafeCall(tooltip.GetName, tooltip)
    local count = tonumber(SafeCall(tooltip.NumLines, tooltip))
    if type(name) ~= "string" or name == "" or not count then return end
    local stored = suppressedLineHeights[tooltip]
    for index = 1, math.min(count, 100) do
        local left = _G[name .. "TextLeft" .. index]
        local line = left and SafeCall(left.GetText, left)
        if type(line) == "string" and line ~= "" then
            if string.find(line, "Quest Item Tracker Forever", 1, true) then
                break
            end
            -- A full metadata row, not explanatory prose containing "item id".
            local clean = string.gsub(line, "|c%x%x%x%x%x%x%x%x", "")
            clean = string.gsub(clean, "|r", "")
            clean = string.gsub(clean, "^%s+", "")
            clean = string.gsub(clean, "%s+$", "")
            local label = string.match(clean, "^([%a%s]+)%s*:%s*%d*$")
                or string.match(clean, "^([%a%s]+)%s+%d+$")
                or string.match(clean, "^([%a%s]+)$")
            local normalized = label and string.lower(string.gsub(label, "%s+", ""))
            if normalized and EXTERNAL_ID_KINDS[normalized] then
                local right = _G[name .. "TextRight" .. index]
                stored = stored or {}
                for _, fontString in ipairs({left, right}) do
                    if fontString and type(fontString.SetText) == "function" then
                        local height = SafeCall(fontString.GetHeight, fontString)
                        if type(height) == "number" and height > 0 and stored[fontString] == nil then
                            stored[fontString] = height
                            SafeCall(fontString.SetHeight, fontString, 0)
                        end
                        SafeCall(fontString.SetText, fontString, "")
                    end
                end
            end
        end
    end
    if stored then suppressedLineHeights[tooltip] = stored end
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
api.RestoreExternalIDHeights = RestoreExternalIDHeights
api.SuppressExternalTooltipIDs = SuppressExternalTooltipIDs
api.QuestMatchesPlayerFaction = QuestMatchesPlayerFaction
