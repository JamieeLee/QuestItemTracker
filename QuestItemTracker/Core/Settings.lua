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

-- One ID policy for standard named tooltip rows, independent of the bag
-- addon that added them. We only touch exact technical identifier rows.
-- Apply immediately after lines are appended, never by a timed rescan:
-- repeatedly hiding visible lines caused flicker with third-party UI skins.
local ID_KINDS = {
    itemid = true, iconid = true, questid = true, spellid = true,
    npcid = true, textureid = true, modelid = true,
}
local hiddenRows = setmetatable({}, { __mode = "k" })
local applyingIDs = setmetatable({}, { __mode = "k" })

local function GetRow(tooltip, index)
    local name = SafeCall(tooltip and tooltip.GetName, tooltip)
    if type(name) ~= "string" or name == "" then return nil, nil end
    return _G[name .. "TextLeft" .. index], _G[name .. "TextRight" .. index]
end

local function IsTechnicalID(text)
    if type(text) ~= "string" or text == "" then return false end
    local plain = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    plain = string.gsub(plain, "|r", "")
    plain = string.gsub(plain, "^%s+", "")
    plain = string.gsub(plain, "%s+$", "")
    local label = string.match(plain, "^([%a%s]+)%s*:%s*%d*$")
        or string.match(plain, "^([%a%s]+)%s+%d+$")
        or string.match(plain, "^([%a%s]+)$")
    local normalized = label and string.lower(string.gsub(label, "%s+", ""))
    return normalized and ID_KINDS[normalized] == true or false
end

local function RestoreEntry(row, restoreText)
    if not row then return end
    for _, part in ipairs({ row.left, row.right }) do
        if part and part.fontString then
            local fs = part.fontString
            if type(part.height) == "number" and part.height > 0 then
                SafeCall(fs.SetHeight, fs, part.height)
            end
            -- Only restore text on an explicit user toggle, never on a
            -- recycled tooltip: old ItemIDs must not leak into the next item.
            if restoreText and SafeCall(fs.GetText, fs) == "" then
                SafeCall(fs.SetText, fs, part.text)
            end
        end
    end
end

local function RestoreExternalIDVisibility(tooltip, restoreText)
    local rows = hiddenRows[tooltip]
    if not rows then return end
    for _, row in pairs(rows) do RestoreEntry(row, restoreText) end
    hiddenRows[tooltip] = nil
end

local function SuppressExternalTooltipIDs(tooltip, mostRecentOnly)
    if not tooltip or applyingIDs[tooltip] then return end
    if SettingEnabled("showIDs") then
        RestoreExternalIDVisibility(tooltip, true)
        return
    end
    local count = tonumber(SafeCall(tooltip.NumLines, tooltip))
    if not count or count < 1 then return end
    applyingIDs[tooltip] = true
    local rows = hiddenRows[tooltip]
    local first = mostRecentOnly and count or 1
    for index = first, math.min(count, 100) do
        local left, right = GetRow(tooltip, index)
        local text = left and SafeCall(left.GetText, left)
        local previous = rows and rows[index]
        if previous and text ~= "" then
            -- A UI reused a line without a clear event. Restore its original
            -- dimensions before evaluating its new contents.
            RestoreEntry(previous, false)
            rows[index] = nil
            previous = nil
        end
        if previous and text == "" and right then
            -- AddDoubleLine sets its right-hand value AFTER calling AddLine
            -- in some client implementations. Suppress that later value too.
            local value = SafeCall(right.GetText, right)
            if type(value) == "string" and value ~= "" then
                local height = tonumber(SafeCall(right.GetHeight, right))
                previous.right = {
                    fontString = right, text = value,
                    height = (previous.right and previous.right.height) or height,
                }
                SafeCall(right.SetText, right, "")
                SafeCall(right.SetHeight, right, 0)
            end
        end
        if not previous and IsTechnicalID(text) then
            local row = {}
            for _, spec in ipairs({ { "left", left }, { "right", right } }) do
                local fs = spec[2]
                if fs and type(fs.GetText) == "function"
                    and type(fs.SetText) == "function"
                    and type(fs.SetHeight) == "function" then
                    local currentText = SafeCall(fs.GetText, fs)
                    local height = tonumber(SafeCall(fs.GetHeight, fs))
                    row[spec[1]] = {
                        fontString = fs, text = currentText,
                        height = height,
                    }
                end
            end
            if row.left then
                rows = rows or {}
                rows[index] = row
                -- Compact this row BEFORE an addon re-shows/reflows a tooltip.
                -- Hiding via alpha leaves an entire empty row behind.
                for _, part in ipairs({ row.left, row.right }) do
                    if part then
                        local fs = part.fontString
                        SafeCall(fs.SetText, fs, "")
                        SafeCall(fs.SetHeight, fs, 0)
                    end
                end
            end
        end
    end
    if rows and next(rows) then hiddenRows[tooltip] = rows
    else hiddenRows[tooltip] = nil end
    applyingIDs[tooltip] = nil
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
