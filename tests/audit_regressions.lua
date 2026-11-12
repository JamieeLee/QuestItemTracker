-- QIT mock Forever runtime: protect quest snapshot cache, native active quest
-- fallback, strict objective matching, and DB repeatable-status consistency.

local file = arg[1] or 'QuestItemTracker/QuestItemTracker.lua'
local questLogCalls, completedListCalls, bagMetadataCalls = 0, 0, 0
local eventFrame, worker, activeObjectives
local history = {}
local currentItemId = 777
local allActive = {
    { questID = 1001, title = 'Iron Claw Quest', level = 32, frequency = 0 },
    { questID = 2002, title = 'Custom Bag Quest', level = 33, frequency = false },
}
local qnames = {[1001]='Iron Claw Quest',[2002]='Custom Bag Quest',[1003]='Other Quest'}
activeObjectives = {
    [1001] = {{type='item',text='Iron Claw Fragment: 1/4',numRequired=4,numFulfilled=1}},
    [2002] = {{type='monster',text='Kill 3 Mobs',numRequired=3,numFulfilled=0}},
}
local genericMethods = {}
setmetatable(genericMethods, {__index=function(t,name)
    local method = function() end; rawset(t,name,method); return method
end})
local function newFrame()
    local f={scripts={},events={}}
    function f:SetScript(k,fn) self.scripts[k]=fn end
    function f:RegisterEvent(name) self.events[name]=true end
    setmetatable(f,{__index=genericMethods})
    return f
end
function CreateFrame(_,name)
    local frame=newFrame()
    if not eventFrame then eventFrame=frame else worker=frame end
    return frame
end
function UnitName() return 'QA' end
function GetRealmName() return 'ForeverMock' end
function UnitFactionGroup() return 'Horde' end
function GetItemInfo() return 'Iron Claw' end
function GetBuildInfo() return 'test','test','test',16001 end
function date() return '2026-11-11' end
DEFAULT_CHAT_FRAME={AddMessage=function(_,msg) error('Unexpected message '..msg) end}
QuestItemTrackerDB={}
SlashCmdList={}
LibQuestieDB={RequireContract=function() return true end,
    Enum={factionRaceMasks={Alliance=2,Horde=1}}}
QuestDB={
    GetAllIds=function() return {1001,1003} end,
    objectives=function(id) if id==1001 then return {[3]={{777,'',3}}} end;return {} end,
    name=function(id) return qnames[id] end,
    questLevel=function() return 32 end,
    requiredRaces=function() return 0 end,
    specialFlags=function(id) return id==1001 and 1 or 0 end,
}
ItemDB={
    relatedQuests=function(id) if id==777 then return {1001} end return nil end,
    startQuest=function() return 0 end,
    class=function() return 12 end,
    subClass=function() return 0 end,
}
C_QuestLog={
    GetNumQuestLogEntries=function() questLogCalls=questLogCalls+1;return #allActive end,
    GetInfo=function(i) return allActive[i] end,
    GetQuestObjectives=function(id) return activeObjectives[id] or {} end,
    GetTitleForQuestID=function(id) return qnames[id] end,
    GetAllCompletedQuestIDs=function() completedListCalls=completedListCalls+1;return history end,
    -- Omit IsQuestFlaggedCompleted to force the expensive fallback path.
    IsRepeatableQuest=function() return false end,
    IsQuestReplayable=function() return false end,
}
C_Container={
    GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end,
    GetContainerItemID=function(bag,slot) if bag==0 and slot==1 then return currentItemId end end,
    GetContainerItemInfo=function() return {stackCount=1} end,
    GetContainerItemQuestInfo=function(bag,slot)
        bagMetadataCalls=bagMetadataCalls+1
        if bag==0 and slot==1 then return {isQuestItem=true,questID=2002} end
    end,
}
NUM_BAG_SLOTS=4
local tooltip={lines={},callbacks={}}
function tooltip:GetItem() return 'Iron Claw','item:777' end
function tooltip:HookScript(k,fn) self.callbacks[k]=fn end
function tooltip:AddLine(line) table.insert(self.lines,line) end
function tooltip:Show() end
function tooltip:clear() self.lines={};if self.callbacks.OnTooltipCleared then self.callbacks.OnTooltipCleared(self) end end
GameTooltip=tooltip
ItemRefTooltip=nil
Minimap=nil
UIParent=nil

assert(loadfile(file))('QuestItemTracker')
assert(eventFrame and eventFrame.scripts.OnEvent,'addon event handler missing')
local onEvent=eventFrame.scripts.OnEvent
onEvent(eventFrame,'PLAYER_LOGIN')
assert(QuestItemTrackerDB.activeCharacterKey=='ForeverMock::QA')
assert(not eventFrame.events.BAG_UPDATE_DELAYED, 'unnecessary BAG_UPDATE_DELAYED event still registered')
assert(completedListCalls==1, 'snapshot importer should run once on login')

-- While index is warming, use the quest log only once for a tooltip, not twice.
local beforeLog=questLogCalls
local beforeCompleted=completedListCalls
tooltip.callbacks.OnTooltipSetItem(tooltip)
assert(questLogCalls==beforeLog+1,'early tooltip read quest log more than once')
assert(completedListCalls==beforeCompleted,'full completed quest list must be cached')
local joined=table.concat(tooltip.lines,'\n')
assert(joined:find('Iron Claw Quest',1,true),'indexed/related active quest missing')
assert(joined:find('Custom Bag Quest',1,true),'second active quest missing from native metadata')
assert(joined:match('Custom Bag Quest[^\n]*\n%s*NEEDED NOW'), 'false frequency must not count as repeatable')
assert(joined:find('NEEDED · REPEATABLE',1,true),'DB-only repeatability not honored')
assert(joined:find('Have 1 / Need 3',1,true),'item required count corrupted')
assert(not joined:find('Have 1 / Need 4',1,true),'different item substring falsely matched')
assert(not joined:find('Iron Claw Fragment: 1/4',1,true),'different objective detail incorrectly inherited')

-- Full index finish should not lose the second quest relation.
assert(worker and worker.scripts.OnUpdate,'quest index did not initialize')
worker.scripts.OnUpdate(worker)
tooltip:clear();tooltip.callbacks.OnTooltipSetItem(tooltip)
joined=table.concat(tooltip.lines,'\n')
assert(joined:find('Iron Claw Quest',1,true))
assert(joined:find('Custom Bag Quest',1,true))

-- Exact objective names still match and retain the correct detail/count.
activeObjectives[1001] = {{type='item',text='Iron Claw: 1/5',numRequired=5,numFulfilled=1}}
tooltip:clear();tooltip.callbacks.OnTooltipSetItem(tooltip)
joined=table.concat(tooltip.lines,'\n')
assert(joined:find('Have 1 / Need 5',1,true),'exact objective did not update required count')

-- Changing quest history invalidates the cached fallback once, not per quest.
local oldCompletedCount=completedListCalls
onEvent(eventFrame,'QUEST_LOG_UPDATE')
tooltip:clear();tooltip.callbacks.OnTooltipSetItem(tooltip)
assert(completedListCalls == oldCompletedCount+1,
    'fallback completed ID lookup should run only once after invalidation')

print('PASS: faction/UI branding + single quest scan + native multi-quest + exact objectives + DB repeatable + cached completed snapshot')
