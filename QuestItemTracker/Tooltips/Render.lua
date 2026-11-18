-- QITF / Tooltips/Render.lua: owns tooltips responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local GetActiveQuestMap = assert(api.GetActiveQuestMap, "QIT load order: GetActiveQuestMap")
local IsQuestCompleted = assert(api.IsQuestCompleted, "QIT load order: IsQuestCompleted")
local IsRepeatableQuest = assert(api.IsRepeatableQuest, "QIT load order: IsRepeatableQuest")
local GetItemName = assert(api.GetItemName, "QIT load order: GetItemName")
local CountItemInventory = assert(api.CountItemInventory, "QIT load order: CountItemInventory")
local AddAssociation = assert(api.AddAssociation, "QIT load order: AddAssociation")
local LookupItemDuringIndex = assert(api.LookupItemDuringIndex, "QIT load order: LookupItemDuringIndex")
local AddRewardProvenance = assert(api.AddRewardProvenance, "QIT load order: AddRewardProvenance")
local NativeBagQuestInfo = assert(api.NativeBagQuestInfo, "QIT load order: NativeBagQuestInfo")
local ActiveObjectiveMatches = assert(api.ActiveObjectiveMatches, "QIT load order: ActiveObjectiveMatches")
local IsQuestRepeatableByID = assert(api.IsQuestRepeatableByID, "QIT load order: IsQuestRepeatableByID")
local IsSeasonalQuestByID = assert(api.IsSeasonalQuestByID, "QIT load order: IsSeasonalQuestByID")
local QuestNameColor = assert(api.QuestNameColor, "QIT load order: QuestNameColor")
local GetQuestLevel = assert(api.GetQuestLevel, "QIT load order: GetQuestLevel")
local IsQuestStarterOnly = assert(api.IsQuestStarterOnly, "QIT load order: IsQuestStarterOnly")
local IsInformationalOnly = assert(api.IsInformationalOnly, "QIT load order: IsInformationalOnly")
local GetQuestStatus = assert(api.GetQuestStatus, "QIT load order: GetQuestStatus")
local QuestDBName = assert(api.QuestDBName, "QIT load order: QuestDBName")
local RecordItem = assert(api.RecordItem, "QIT load order: RecordItem")
local AssessItemRetention = assert(api.AssessItemRetention, "QIT load order: AssessItemRetention")
local GetTooltipItem = assert(api.GetTooltipItem, "QIT load order: GetTooltipItem")
local SettingEnabled = assert(api.SettingEnabled, "QIT load order: SettingEnabled")
local QuestMatchesPlayerFaction = assert(api.QuestMatchesPlayerFaction, "QIT load order: QuestMatchesPlayerFaction")
local QuestTurnInDetails = assert(api.QuestTurnInDetails, "QIT load order: QuestTurnInDetails")
local ClosestFactionTurnIn = assert(api.ClosestFactionTurnIn, "QIT load order: ClosestFactionTurnIn")
local ClearTurnInHover = assert(api.ClearTurnInHover, "QIT load order: ClearTurnInHover")

-- Reuse the same compact, full-text formatting for regular turn-ins and
-- optional nearest hints. WoW's native tooltip may truncate a long colored
-- AddLine even with wrapText=true, especially near narrow bag windows.
local function AddLocationDetailLine(addLine, indent, label, place)
    local split = string.find(place, " — ", 1, true)
    local npc = split and string.sub(place, 1, split - 1)
    local zone = split and string.sub(place, split + #" — ")
    if npc and zone and (#npc + #zone + #label + 2) >= 36 then
        addLine(indent .. "|cffabb1b7" .. label .. ": |r|cffdecfb9"
            .. npc .. "|r", 0.8, 0.8, 0.8, true)
        addLine(indent .. "         |cffdecfb9"
            .. zone .. "|r", 0.8, 0.8, 0.8, true)
    else
        addLine(indent .. "|cffabb1b7" .. label .. ": |r|cffdecfb9"
            .. place .. "|r", 0.8, 0.8, 0.8, true)
    end
end

local function AddTooltipLines(tooltip, data, explicitItemID)
    if not tooltip or type(tooltip.AddLine) ~= "function" then return false end
    local itemID, itemName = GetTooltipItem(tooltip, data, explicitItemID)
    if not itemID then return false end
    if S.decoratedTooltips[tooltip] == itemID then return true end

    -- Merge verified quest uses from the index, fast candidates, and native
    -- active quest data before evaluating KEEP/DELETE. A missing reverse link
    -- does not prove that an item has no quest uses.
    local activeMap = GetActiveQuestMap()
    local indexed = S.itemQuestIndex[itemID]
    local partial = not S.dbIndexReady
    local matches = {}
    if type(indexed) == "table" then
        for questID, entry in pairs(indexed) do
            for source in pairs(entry.sources or {}) do
                AddAssociation(matches, questID, source, entry.required)
            end
        end
    end
    if partial then
        local early = LookupItemDuringIndex(itemID, activeMap)
        for questID, entry in pairs(early or {}) do
            for source in pairs(entry.sources or {}) do
                AddAssociation(matches, questID, source, entry.required)
            end
        end
    end

    -- ItemDB.startQuest is a direct, documented lookup even if QuestDB's
    -- startedBy[3] reverse link is absent.
    local startQuest = tonumber(SafeCall(ItemDB and ItemDB.startQuest, itemID))
    if startQuest and startQuest > 0 then
        AddAssociation(matches, startQuest, "database quest starter")
    end
    -- Reward links exist on ItemDB rather than QuestDB. Show only provenance.
    AddRewardProvenance(itemID, matches)

    local itemNameResolved = GetItemName(itemID, itemName)
    ActiveObjectiveMatches(itemNameResolved, activeMap, matches)

    -- Always consider native bag metadata: one item may belong to multiple
    -- active quests, including a custom quest absent from QuestieDB. Only
    -- accept the native quest ID if the player's live quest log confirms it.
    local native = {}
    NativeBagQuestInfo(itemID, native)
    for questID in pairs(native) do
        if activeMap[questID] then
            AddAssociation(matches, questID, "native bag metadata")
        end
    end

    -- Filter before displaying quests AND before the retention recommendation.
    -- An Alliance-only quest must not make a Horde player keep a useless item.
    for questID in pairs(matches) do
        if not QuestMatchesPlayerFaction(questID, activeMap) then
            matches[questID] = nil
        end
    end
    if not next(matches) then
        S.qitCaptures[tooltip] = nil
        return false
    end
    ClearTurnInHover(tooltip)

    local bags, bank = CountItemInventory(itemID)
    local totalHave = bags + bank
    local ids, names = {}, {}
    for questID in pairs(matches) do
        ids[#ids + 1] = questID
        names[questID] = string.lower((activeMap[questID] and activeMap[questID].title)
            or QuestDBName(questID))
    end
    table.sort(ids, function(a, b)
        if names[a] == names[b] then return a < b end
        return names[a] < names[b]
    end)

    RecordItem(itemID, itemNameResolved, matches)
    -- Mark this tooltip before rendering: Show() may invoke tooltip hooks again.
    S.decoratedTooltips[tooltip] = itemID

    -- Capture QITF-authored lines as they are rendered, not by scraping
    -- GameTooltip's recycled native fontstrings after the fact.
    local capture = { itemID = itemID, lines = {}, hoverRows = {} }
    local function AddCapturedLine(text, red, green, blue, wrap)
        tooltip:AddLine(text, red, green, blue, wrap)
        capture.lines[#capture.lines + 1] = {
            text = text, r = red, g = green, b = blue, wrap = wrap,
        }
    end
    AddCapturedLine(" ")
    AddCapturedLine("|cff66ccffQuest Item Tracker Forever|r")
    if SettingEnabled("showIDs") then
        AddCapturedLine("Item ID: " .. itemID, 0.75, 0.75, 0.75)
    end
    if SettingEnabled("showInventoryBreakdown") then
        AddCapturedLine("Have " .. totalHave .. "  (Bags: " .. bags .. " | Bank: " .. bank .. ")", 0.75, 0.9, 0.75)
    else
        AddCapturedLine("Have " .. totalHave, 0.75, 0.9, 0.75)
    end

    local recommendation, recommendationColor = AssessItemRetention(matches, activeMap)
    -- Before the scan completes, this list can be incomplete: don't promise
    -- the item is disposable or that no future use exists.
    if partial and recommendation and string.find(recommendation, "SAFE TO DELETE", 1, true) then
        recommendation = nil
    end
    if recommendation then
        -- The decision is the attention color; its explanation is quiet ivory.
        local separator = string.find(recommendation, " — ", 1, true)
        if separator then
            local decision = string.sub(recommendation, 1, separator - 1)
            local explanation = string.sub(recommendation, separator)
            AddCapturedLine(recommendationColor .. decision .. "|r|cffd8dee8"
                .. explanation .. "|r", 0.9, 0.9, 0.9, true)
        else
            AddCapturedLine(recommendationColor .. recommendation .. "|r", 0.9, 0.9, 0.9, true)
        end
    end

    -- Build a display-only layout from the already-filtered matches. Grouped
    -- headings avoid repeating the same REPEATABLE / GREY label per quest.
    -- Retention and per-quest status calculations above remain authoritative.
    local activeCount, futureCount, completedCount = 0, 0, 0
    local ordinaryQuests, repeatableQuests, seasonalQuests, lowLevelQuests, factionTurnIns = {}, {}, {}, {}, {}
    local showTurnIn = SettingEnabled("showTurnInDetails")
    local withCoordinates = showTurnIn and SettingEnabled("showTurnInCoordinates")
    for _, questID in ipairs(ids) do
        local entry = matches[questID]
        local active = activeMap[questID]
        local status, color = GetQuestStatus(questID, entry, activeMap)

        -- Informational reward/event links do not count as future quest USES.
        if not IsInformationalOnly(entry) then
            if active and not IsQuestStarterOnly(entry) then
                activeCount = activeCount + 1
            elseif IsQuestRepeatableByID(questID) or not IsQuestCompleted(questID) then
                futureCount = futureCount + 1
            else
                completedCount = completedCount + 1
            end
        end

        local row = {
            id = questID,
            entry = entry,
            name = (active and active.title) or QuestDBName(questID),
            level = GetQuestLevel(questID, active),
            status = status,
            color = color,
            seasonal = IsSeasonalQuestByID(questID),
            turnIns = showTurnIn and QuestTurnInDetails(questID, withCoordinates) or nil,
            rewardOrigin = IsInformationalOnly(entry)
                and (entry.sources or {})["database quest reward"],
        }
        if row.seasonal then
            -- Show the seasonal marker above this quest without hiding it in
            -- the ordinary repeatable group. The quest can still be repeatable.
            seasonalQuests[#seasonalQuests + 1] = row
        elseif not IsInformationalOnly(entry) and
            (IsQuestRepeatableByID(questID) or (active and IsRepeatableQuest(active))) then
            repeatableQuests[#repeatableQuests + 1] = row
        elseif status == "FUTURE USE · GREY QUEST" then
            lowLevelQuests[#lowLevelQuests + 1] = row
        elseif not IsInformationalOnly(entry) and
            string.find(row.name, "^A Donation of ") then
            -- City cloth quartermasters share donation titles across faction quests.
            factionTurnIns[#factionTurnIns + 1] = row
        else
            ordinaryQuests[#ordinaryQuests + 1] = row
        end
    end

    local showIDs = SettingEnabled("showIDs")
    local showFuture = false -- old future-label toggle retired
    local showLevels = SettingEnabled("showQuestLevels")

    -- Multiple distinct faction/city quests can share the same title and level
    -- (for example five separate "A Donation of Wool" quests). Compact only
    -- equivalent presentation rows; never merge underlying IDs, statuses,
    -- requirements or retention/matching decisions.
    local function CompactQuestRows(rows)
        local compact, byKey = {}, {}
        for _, row in ipairs(rows) do
            local entry = row.entry or {}
            local key = table.concat({
                row.name or "",
                tostring(row.level or ""),
                row.status or "",
                row.color or "",
                row.rewardOrigin and "reward" or "ordinary",
                row.seasonal and "seasonal" or "ordinary",
                tostring(entry.required or ""),
                tostring(entry.detail or ""),
            }, "\031")
            local existing = byKey[key]
            if existing then
                existing.ids[#existing.ids + 1] = row.id
                local seen = {}
                for _, location in ipairs(existing.turnIns or {}) do seen[location] = true end
                for _, location in ipairs(row.turnIns or {}) do
                    if not seen[location] then
                        existing.turnIns = existing.turnIns or {}
                        existing.turnIns[#existing.turnIns + 1] = location
                        seen[location] = true
                    end
                end
            else
                row.ids = { row.id }
                compact[#compact + 1] = row
                byKey[key] = row
            end
        end
        return compact
    end

    local crowded = #ids >= 3
    local hoverRows = {}
    local function ShowQuestRow(row, grouped)
        local indent = grouped and "    " or "  "
        local nameIndent = grouped and "  " or ""
        local nameLine = nameIndent .. QuestNameColor(row.level)
            .. (row.rewardOrigin and "Reward from: " or "") .. row.name .. "|r"
        if showLevels then
            nameLine = nameLine .. "  (" .. (row.level and ("Level " .. row.level) or "Level unknown") .. ")"
        end
        if #row.ids > 1 then
            nameLine = nameLine .. "  |cff95a9b8(" .. #row.ids .. " quests)|r"
        end
        AddCapturedLine(nameLine)
        if grouped == "faction" and #row.ids >= 2 then
            local nearest = ClosestFactionTurnIn(row)
            if nearest then
                AddLocationDetailLine(AddCapturedLine, indent, "Closest", nearest)
            end
        end
        if row.turnIns and #row.turnIns > 0 then
            if crowded then
                local line = SafeCall(tooltip.NumLines, tooltip)
                if line then
                    hoverRows[#hoverRows + 1] = {
                        line = line, captureLine = #capture.lines,
                        title = row.name, destinations = row.turnIns,
                    }
                end
            else
                local place = row.turnIns[1]
                if #row.turnIns == 2 then
                    place = place .. " / " .. row.turnIns[2]
                elseif #row.turnIns > 2 then
                    place = place .. " (+" .. (#row.turnIns - 1) .. " other locations)"
                end
                AddLocationDetailLine(AddCapturedLine, indent, "Turn in", place)
            end
        end

        local status = row.status
        if grouped == "repeatable" then
            -- The heading already tells the player these quests repeat.
            if status == "REPEATABLE QUEST" then
                status = nil
            elseif status == "REPEATABLE · COMPLETED BEFORE" then
                status = showFuture and "COMPLETED BEFORE" or nil
            elseif status == "NEEDED · REPEATABLE" then
                status = "NEEDED NOW"
            elseif status == "REPEATABLE — KEEP FOR NEXT TIME" then
                status = "KEEP FOR NEXT TIME"
            end
        elseif grouped == "lowLevel" and status == "FUTURE USE · GREY QUEST" then
            -- One low-level heading replaces every repeated GREY QUEST line.
            status = nil
        end
        -- Future status lines remain opt-in; essential active states remain.
        if not showFuture then
            if status == "FUTURE USE · GREY QUEST" then
                status = "GREY QUEST"
            elseif status == "FUTURE QUEST" or status == "FUTURE USE · ABANDONED" then
                status = nil
            end
        end
        if status or showIDs then
            local statusLine = status and (indent .. status) or indent
            if showIDs then
                local idsText = #row.ids > 1
                    and ("Quest IDs: " .. table.concat(row.ids, ", "))
                    or ("Quest ID: " .. row.id)
                statusLine = statusLine .. (status and "  |  " or "") .. idsText
            end
            AddCapturedLine(statusLine, 0.78, 0.78, 0.78)
        end

        local entry = row.entry
        if entry.required and entry.required > 0 and not IsInformationalOnly(entry) then
            AddCapturedLine(indent .. "Have " .. totalHave .. " / Need " .. entry.required, 0.75, 0.9, 0.75)
        elseif entry.detail then
            AddCapturedLine(indent .. entry.detail, 0.7, 0.7, 0.7, true)
        end
    end

    if #seasonalQuests > 0 then
        AddCapturedLine("|cffff992f— SEASONAL QUEST —|r")
        for _, row in ipairs(CompactQuestRows(seasonalQuests)) do ShowQuestRow(row, "seasonal") end
    end
    for _, row in ipairs(CompactQuestRows(ordinaryQuests)) do ShowQuestRow(row, nil) end
    if #factionTurnIns > 0 then
        -- A restrained faction accent makes this heading distinct from the
        -- cyan addon header and from red/orange/yellow quest difficulty text.
        -- The player's faction is already detected by the existing filter;
        -- this is purely presentation and must not alter which quests appear.
        local faction = SafeCall(UnitFactionGroup, "player")
        local headingColor = "|cffc7b497" -- neutral parchment fallback
        if faction == "Horde" then
            headingColor = "|cffcf8088" -- weathered Horde crimson
        elseif faction == "Alliance" then
            headingColor = "|cff889ee0" -- Alliance blue with violet undertone
        end
        AddCapturedLine(headingColor .. "FACTION TURN-INS|r")
        for _, row in ipairs(CompactQuestRows(factionTurnIns)) do ShowQuestRow(row, "faction") end
    end
    if #repeatableQuests > 0 then
        AddCapturedLine("REPEATABLE QUESTS", 0.4, 0.78, 1)
        for _, row in ipairs(CompactQuestRows(repeatableQuests)) do ShowQuestRow(row, "repeatable") end
    end
    if #lowLevelQuests > 0 then
        AddCapturedLine("LOW-LEVEL QUESTS", 0.6, 0.72, 0.84)
        for _, row in ipairs(CompactQuestRows(lowLevelQuests)) do ShowQuestRow(row, "lowLevel") end
    end

    if partial then
        AddCapturedLine("Checking remaining quests...", 0.7, 0.8, 1, true)
    elseif activeCount == 0 and futureCount > 0 and showFuture then
        AddCapturedLine("No current quest needs this item; it has future quest uses.", 0.9, 0.8, 0.55, true)
    elseif activeCount == 0 and futureCount == 0 and completedCount > 0 then
        AddCapturedLine("No remaining known quest uses.", 0.65, 0.85, 1, true)
    end
    if crowded and #hoverRows > 0 then S.turnInHoverRows[tooltip] = hoverRows end
    capture.hoverRows = hoverRows
    S.qitCaptures[tooltip] = capture
    if type(tooltip.Show) == "function" then tooltip:Show() end
    return true
end

api.AddTooltipLines = AddTooltipLines
