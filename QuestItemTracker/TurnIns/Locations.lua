-- QITF / TurnIns/Locations.lua: owns turnins responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")
local SettingEnabled = assert(api.SettingEnabled, "QIT load order: SettingEnabled")

-- Read the *finisher* from QuestieDB, not the quest starter or the completion
-- trigger. The current Forever flavor owns these records; QITF owns no location
-- database. Missing information is left out rather than filled with guesses.
local function TurnInZoneName(areaID)
    areaID = tonumber(areaID)
    if not areaID or areaID <= 0 then return nil end
    local name = SafeCall(C_Map and C_Map.GetAreaInfo, areaID)
        or SafeCall(GetAreaInfo, areaID)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

local function TurnInPlace(entityDB, id, withCoordinates)
    if type(entityDB) ~= "table" then return nil end
    local name = SafeCall(entityDB.name, id)
    if type(name) ~= "string" or name == "" then return nil end

    local spawns = SafeCall(entityDB.spawns, id)
    local zoneID = tonumber(SafeCall(entityDB.zoneID, id))
    local chosenID, zoneName
    -- Prefer the provider's normal zone, but only if the client can name it.
    if zoneID then
        zoneName = TurnInZoneName(zoneID)
        if zoneName then chosenID = zoneID end
    end
    if not zoneName and type(spawns) == "table" then
        -- Deterministic alternative; never choose coordinates from a different zone.
        local areas = {}
        for area in pairs(spawns) do
            local numeric = tonumber(area)
            if numeric and numeric > 0 then areas[#areas + 1] = numeric end
        end
        table.sort(areas)
        for _, area in ipairs(areas) do
            local candidate = TurnInZoneName(area)
            if candidate then zoneName, chosenID = candidate, area; break end
        end
    end

    local location = name .. (zoneName and (" — " .. zoneName) or "")
    if withCoordinates and chosenID and type(spawns) == "table" then
        local points = spawns[chosenID] or spawns[tostring(chosenID)]
        local point = type(points) == "table" and points[1] or nil
        local x = point and tonumber(point[1])
        local y = point and tonumber(point[2])
        if x and y and x == x and y == y
            and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
            location = location .. string.format(" (%.1f, %.1f)", x, y)
        end
    end
    return location
end

local function QuestTurnInDetails(questID, withCoordinates)
    local finishers = SafeCall(QuestDB and QuestDB.finishedBy, questID)
    if type(finishers) ~= "table" then return nil end
    local results, seen = {}, {}
    local function AddFinishers(entities, provider)
        if type(entities) ~= "table" then return end
        local ids = {}
        for _, value in pairs(entities) do
            local id = tonumber(value)
            if id and id > 0 then ids[#ids + 1] = id end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local location = TurnInPlace(provider, id, withCoordinates)
            if location and not seen[location] then
                seen[location] = true
                results[#results + 1] = location
            end
        end
    end
    AddFinishers(finishers[1], NpcDB)
    AddFinishers(finishers[2], ObjectDB)
    return #results > 0 and results or nil
end



-- Optional, read-only navigation hint. This currently recognizes TomTom with
-- either a shared HereBeDragons map-math API or the native C_Map world-position
-- API. A waypoint API by itself cannot rank arbitrary turn-in destinations.
-- Never create, move, clear, or replace another addon's waypoints.
local areaToUiMapID
local function TurnInUiMapID(areaID)
    if not areaToUiMapID then
        local support = LibQuestieDB and LibQuestieDB.Support
        local zone = SafeCall(support and support.Get, "ZoneDB")
        local source = zone and zone.private and zone.private.areaIdToUiMapId
        local decoder = type(source) == "string" and (loadstring or load) or nil
        local chunk = decoder and SafeCall(decoder, source)
        local decoded = chunk and SafeCall(chunk)
        if type(decoded) == "table" then areaToUiMapID = decoded end
    end
    return areaToUiMapID and tonumber(areaToUiMapID[tonumber(areaID)])
end

local function TomTomReadOnlyPosition()
    if type(TomTom) ~= "table" or type(TomTom.GetCurrentPlayerPosition) ~= "function" then
        return nil
    end
    local hbd = SafeCall(LibStub, "HereBeDragons-2.0", true)
    if type(hbd) == "table"
        and type(hbd.GetPlayerWorldPosition) == "function"
        and type(hbd.GetWorldCoordinatesFromZone) == "function" then
        local px, py, instance = SafeCall(hbd.GetPlayerWorldPosition, hbd)
        if type(px) == "number" and type(py) == "number"
            and type(instance) == "number" then
            return px, py, instance, function(uiMapID, x, y)
                return SafeCall(hbd.GetWorldCoordinatesFromZone, hbd, x / 100, y / 100, uiMapID)
            end
        end
    end
    -- Some Forever clients/nav builds use C_Map rather than HereBeDragons.
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function"
        or type(C_Map.GetPlayerMapPosition) ~= "function"
        or type(C_Map.GetWorldPosFromMapPos) ~= "function"
        or type(CreateVector2D) ~= "function" then return nil end
    local uiMapID = SafeCall(C_Map.GetBestMapForUnit, "player")
    local localPos = uiMapID and SafeCall(C_Map.GetPlayerMapPosition, uiMapID, "player")
    local instance, world = localPos
        and SafeCall(C_Map.GetWorldPosFromMapPos, uiMapID, localPos)
    local px, py = world and SafeCall(world.GetXY, world)
    if not px or not py or not instance then return nil end
    return px, py, instance, function(mapID, x, y)
        local vec = SafeCall(CreateVector2D, x / 100, y / 100)
        if not vec then return nil end
        local continent, point = SafeCall(C_Map.GetWorldPosFromMapPos, mapID, vec)
        local wx, wy = point and SafeCall(point.GetXY, point)
        return wx, wy, continent
    end
end

local function ClosestFactionTurnIn(row)
    if #row.ids < 2 or not SettingEnabled("showTurnInDetails") then return nil end
    local px, py, instance, toWorld = TomTomReadOnlyPosition()
    if not (px and py and instance and toWorld) then return nil end
    local best, bestSquared
    -- Require a valid map coordinate for *every* grouped quest before
    -- claiming closest. Otherwise we might omit an unindexed nearer NPC.
    for _, questID in ipairs(row.ids) do
        local finishers = SafeCall(QuestDB and QuestDB.finishedBy, questID)
        local foundAny = false
        if type(finishers) ~= "table" then return nil end
        for kind = 1, 2 do
            local provider = kind == 1 and NpcDB or ObjectDB
            local ids = finishers[kind]
            if type(ids) == "table" and type(provider) == "table" then
                for _, id in ipairs(ids) do
                    local name = SafeCall(provider.name, id)
                    local spawns = SafeCall(provider.spawns, id)
                    if type(name) == "string" and type(spawns) == "table" then
                        for areaID, points in pairs(spawns) do
                            local area = tonumber(areaID)
                            local zoneName = area and TurnInZoneName(area)
                            local uiMapID = zoneName and TurnInUiMapID(area)
                            if uiMapID and uiMapID > 0 and type(points) == "table" then
                                for _, point in ipairs(points) do
                                    local x = type(point) == "table" and tonumber(point[1])
                                    local y = type(point) == "table" and tonumber(point[2])
                                    if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                                        local wx, wy, placeInstance = toWorld(uiMapID, x, y)
                                        if wx and wy and placeInstance then
                                            foundAny = true
                                            if placeInstance == instance then
                                                local squared = (wx - px)^2 + (wy - py)^2
                                                if not bestSquared or squared < bestSquared then
                                                    bestSquared = squared
                                                    best = name .. " — " .. zoneName
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if not foundAny then return nil end
    end
    -- Straight-line world distance on the same continent only; no route claims.
    return best
end

api.QuestTurnInDetails = QuestTurnInDetails
api.ClosestFactionTurnIn = ClosestFactionTurnIn
