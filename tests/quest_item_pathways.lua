-- QuestieDB public-schema coverage for every item-bearing quest entry path.
_G.QuestItemTrackerDB = nil
_G.DEFAULT_CHAT_FRAME = {AddMessage = function() end}
_G.SlashCmdList = {}
_G.NUM_BAG_SLOTS = 4
_G.NUM_BANKBAGSLOTS = 7
_G.BANK_CONTAINER = -1
_G.UnitName = function() return 'TestHero' end
_G.GetRealmName = function() return 'Forever' end
_G.UnitFactionGroup = function() return 'Horde' end
_G.GetBuildInfo = function() return '1.60','x','x',16001 end
_G.GetQuestDifficultyColor = function() return {r=1,g=0.5,b=0} end
_G.LibQuestieDB={RequireContract=function(v)return v==4 end,Enum={factionRaceMasks={Alliance=4294967373,Horde=8589934770}}}
local data = {
 [700] = {name='Item-start via quest row',startedBy={{}, {}, {15001}}},
 [701] = {name='Item-start via item row'},
 [702] = {name='Spell tool',objectives={[6]={{9220,'Use item',15003}}}},
 [703] = {name='Required quest source',requiredSourceItems={15004}},
 [704] = {name='Collect from enemies',objectives={[3]={{15005,'Claw',5}}}},
 [705] = {name='Tool from questgiver',sourceItemId=15006},
 [706] = {name='Event item reference',extraObjectives={{{},3,'A waypoint',0,{{'item',15007}}}}},
 [707] = {name='Rewards an ordinary item'},
 [708] = {name='Generic related item'},
 [709] = {name='Live native bag quest'},
 [710] = {name='Live objective text quest'},
 [711] = {name='Accepted starter item',startedBy={[3]={15012}}},
 [712] = {name='Starter also needed later',startedBy={[3]={15013}},objectives={[3]={{15013,'Both uses',3}}}},
 [713] = {name='Completed item starter',startedBy={[3]={15014}}},
 [714] = {name='Future reuse',objectives={[3]={{15015,'Reusable',2}}}},
 [715] = {name='Completed former use',objectives={[3]={{15015,'Reusable',2}}}},
 [716] = {name='Direct item-start only'},
 [717] = {name='Repeatable completed item',objectives={[3]={{15020,'Repeat item',2}}},specialFlags=1},
 [719] = {name='Future quest same native item',objectives={[3]={{15022,'Dual-purpose item',1}}}},
 [6134] = {name='Ghost-o-plasm Round Up',sourceItemId=15848,objectives={[3]={{15849,'Ghost-o-Plasm',8}}}},
 [95682] = {name='Open the Maw',requiredRaces=8589934770},
 [95683] = {name='Alliance reward quest',requiredRaces=4294967373},
}
local ids={}
for id in pairs(data) do ids[#ids+1]=id end
table.sort(ids)
local activeIDs={702,703,704,705,709,710,711,712,6134}
local active={}
for _,id in ipairs(activeIDs) do active[id]=true end
local completed={[713]=true,[715]=true,[717]=true}
_G.QuestDB={
 GetAllIds=function()return ids end,
 name=function(id)return data[id] and data[id].name end,
 questLevel=function()return 20 end,
 requiredRaces=function(id)return data[id] and data[id].requiredRaces or 0 end,
 objectives=function(id)return data[id] and data[id].objectives end,
 requiredSourceItems=function(id)return data[id] and data[id].requiredSourceItems end,
 sourceItemId=function(id)return data[id] and (data[id].sourceItemId or 0) end,
 startedBy=function(id)return data[id] and (data[id].startedBy or {}) end,
 extraObjectives=function(id)return data[id] and data[id].extraObjectives end,
 specialFlags=function(id)return data[id] and (data[id].specialFlags or 0) end,
}
_G.ItemDB={
 relatedQuests=function(itemID)
  return ({[15001]={700},[15007]={706},[15009]={708},[15013]={712},[15015]={714,715},[15022]={719}})[itemID]
 end,
 startQuest=function(itemID)
  if itemID==15002 then return 701 end
  if itemID==15018 then return 716 end
  return 0
 end,
 questRewards=function(itemID)
  if itemID==15008 then return {707} end -- ordinary gear reward remains silent
  if itemID==271745 then return {95682} end -- the Horde Bloody Map
  if itemID==15101 then return {95683} end -- other-faction-only reward
 end,
 class=function(itemID)
  if itemID==271745 or itemID==15101 then return 15 end
  if itemID==15008 then return 4 end
 end,
 subClass=function(itemID)
  if itemID==271745 or itemID==15101 then return 0 end
 end,
}
local itemNames={}
for id=15001,15022 do itemNames[id]='Item'..id end
itemNames[15011]='Quest Claw';itemNames[15848]='Crate of Ghost Magnets'; itemNames[6948]='Hearthstone'
itemNames[271745]='Bloody Map';itemNames[15101]='Alliance quest reward'
_G.C_Item={GetItemName=function(id)return itemNames[id] end}
_G.GetItemInfo=function(id)return itemNames[id] end
_G.C_QuestLog={
 GetNumQuestLogEntries=function()return #activeIDs end,
 GetInfo=function(i)
  local id=activeIDs[i]
  if id then return {questID=id,title=data[id].name,isHeader=false,level=20,isComplete=false} end
 end,
 GetQuestObjectives=function(id)
  if id==710 then return {{type='item',text='Quest Claw: 1/4',numFulfilled=1,numRequired=4}} end
  return {}
 end,
 GetAllCompletedQuestIDs=function()return {713,715,717} end,
 IsQuestFlaggedCompleted=function(id)return completed[id] or false end,
 IsRepeatableQuest=function()return false end,
 IsQuestReplayable=function()return false end,
 IsQuestTrivial=function()return false end,
 GetQuestDifficultyLevel=function()return 20 end,
 GetTitleForQuestID=function(id)return data[id] and data[id].name end,
}
_G.BankFrame={IsShown=function()return false end}
local bag={}
for id=15001,15022 do bag[#bag+1]={id=id,count=2} end
bag[#bag+1]={id=15848,count=1}
bag[#bag+1]={id=271745,count=1}
bag[#bag+1]={id=15101,count=1}
_G.C_Container={
 GetContainerNumSlots=function(b)return b==0 and #bag or 0 end,
 GetContainerItemID=function(b,slot)return b==0 and bag[slot] and bag[slot].id end,
 GetContainerItemInfo=function(b,slot)return b==0 and bag[slot] and {stackCount=bag[slot].count} end,
 GetContainerItemQuestInfo=function(b,slot)
  local id=b==0 and bag[slot] and bag[slot].id
  if id==15010 or id==15022 then return {questID=709,isQuestItem=true} end
 end,
}
local frames={}
local function Frame(kind,name,parent)
 local f={kind=kind,name=name,parent=parent,scripts={},events={},shown=true}
 function f:RegisterEvent(x) self.events[x]=true end
 function f:SetScript(k,v)self.scripts[k]=v end
 function f:Show()self.shown=true;if self.scripts.OnShow then self.scripts.OnShow(self) end end
 function f:Hide()self.shown=false end
 function f:IsShown()return self.shown end
 function f:SetChecked(x)self.checked=x end
 function f:GetChecked()return self.checked end
 function f:SetText(x)self.text=x end
 function f:SetSize()end
 function f:SetPoint()end
 function f:ClearAllPoints()end
 function f:GetCenter()return 500,500 end
 function f:StartMoving()end
 function f:StopMovingOrSizing()end
 function f:SetFrameStrata()end
 function f:EnableMouse()end
 function f:SetMovable()end
 function f:SetClampedToScreen()end
 function f:RegisterForDrag()end
 function f:RegisterForClicks()end
 function f:SetHeight()end
 function f:SetWidth()end
 function f:SetAllPoints()end
 function f:SetTexture()end
 function f:SetColorTexture()end
 function f:SetTexCoord()end
 function f:CreateTexture()return Frame('Texture',nil,self) end
 function f:CreateFontString()return Frame('FontString',nil,self) end
 frames[#frames+1]=f
 return f
end
_G.CreateFrame=Frame
_G.UIParent=Frame('Frame','UIParent')
_G.Minimap=Frame('Frame','Minimap')
local callback
_G.Enum={TooltipDataType={Item=222}}
_G.TooltipDataProcessor={AddTooltipPostCall=function(_,cb)callback=cb end}
_G.GameTooltip={lines={},scripts={}}
function GameTooltip:HookScript(e,cb)self.scripts[e]=cb end
function GameTooltip:AddLine(x)self.lines[#self.lines+1]=x end
function GameTooltip:GetItem()return nil,nil end
function GameTooltip:Show()self.shown=true end
function GameTooltip:Hide()self.shown=false end
function GameTooltip:SetBagItem()end
function GameTooltip:SetHyperlink()end
function GameTooltip:SetOwner()end
function GameTooltip:ClearLines()self.lines={} end
_G.hooksecurefunc=function(obj,k,hook)local old=obj[k];obj[k]=function(self,...)local val=old(self,...);hook(self,...);return val end end
assert(loadfile('QuestItemTracker/QuestItemTracker.lua'))('QuestItemTracker')
local main
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then main=f end end
assert(main)
main.scripts.OnEvent(main,'PLAYER_LOGIN')
assert(callback)
local function tooltip(id)
 GameTooltip:ClearLines()
 if GameTooltip.scripts.OnTooltipCleared then GameTooltip.scripts.OnTooltipCleared(GameTooltip) end
 callback(GameTooltip,{id=id,type=222})
 return table.concat(GameTooltip.lines,'\n')
end
local function check(id,includes,excludes,context)
 local t=tooltip(id)
 for _,p in ipairs(includes or {}) do assert(t:find(p,1,true),context..': missing '..p..' in '..t) end
 for _,p in ipairs(excludes or {}) do assert(not t:find(p,1,true),context..': unexpectedly found '..p..' in '..t) end
end
check(15002,{'Item-start via item row','KEEP'}, {'SAFE TO DELETE'},'Direct starter before scan')
check(15006,{'Tool from questgiver','NEEDED'}, {'SAFE TO DELETE'},'Provider before scan')
check(15010,{'Live native bag quest','NEEDED'},nil,'Bag-native before scan')
check(15011,{'Live objective text quest','NEEDED','Need 4'},nil,'Active objective text')
check(15007,{'Event item reference','REVIEW'}, {'NEEDED','SAFE TO DELETE'},'Event reference before scan')
check(15022,{'Live native bag quest','Future quest same native item','NEEDED'},nil,'Native quest plus future DB relation before scan')
check(271745,{'Reward from: Open the Maw','QUEST REWARD','FUTURE USE UNKNOWN'},
 {'SAFE TO DELETE','NEEDED','KEEP','Have 1 / Need','FUTURE QUEST'},'Bloody Map before scan')
assert(tooltip(15101)=='','Opposite-faction reward is excluded on Horde')
assert(tooltip(15008)=='','Ordinary equipment reward must not appear')
assert(tooltip(15009)=='','Generic relatedQuests must not be proof')
assert(tooltip(6948)=='','Normal item must stay invisible')
for _,f in ipairs(frames) do
 if f~=main and f.scripts.OnUpdate then
  for n=1,20 do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,0.016) end end
 end
end
check(15001,{'Item-start via quest row','STARTS QUEST','KEEP'},nil,'Quest startedBy item')
check(15002,{'Item-start via item row','STARTS QUEST','KEEP'},nil,'ItemDB.startQuest')
check(15003,{'Spell tool','NEEDED'},nil,'Spell-objective item')
check(15004,{'Required quest source','NEEDED'}, {'START ITEM NO LONGER NEEDED'},'Required source active')
check(15005,{'Collect from enemies','NEEDED','Need 5'},nil,'Item objective')
check(15006,{'Tool from questgiver','NEEDED'},nil,'Provided quest tool')
check(15007,{'Event item reference','REVIEW'}, {'NEEDED','SAFE TO DELETE'},'Event reference')
check(15010,{'Live native bag quest','NEEDED'},nil,'Native bag quest relation')
check(15011,{'Live objective text quest','NEEDED'},nil,'Active objective text fallback')
check(15012,{'Accepted starter item','QUEST STARTED'}, {'SAFE TO DELETE','NEEDED —'},'Already accepted starter')
check(15013,{'Starter also needed later','NEEDED'}, {'START ITEM NO LONGER NEEDED'},'Starter plus objective')
check(15014,{'Completed item starter','SAFE TO DELETE'},nil,'Completed starter')
check(15015,{'Future reuse','Completed former use','KEEP'}, {'SAFE TO DELETE'},'Shared completed/future item')
check(15018,{'Direct item-start only','STARTS QUEST','KEEP'},nil,'Unpaired item starter')
check(15020,{'Repeatable completed item','KEEP'}, {'SAFE TO DELETE'},'Database repeatable flag')
check(15022,{'Live native bag quest','Future quest same native item','NEEDED'},nil,'Native quest plus future DB relation after scan')
check(15848,{'Ghost-o-plasm Round Up','NEEDED'},nil,'Ghost Magnets')
check(271745,{'Reward from: Open the Maw','QUEST REWARD','FUTURE USE UNKNOWN'},
 {'SAFE TO DELETE','NEEDED','KEEP','Have 1 / Need','FUTURE QUEST'},'Bloody Map after scan')
assert(tooltip(15101)=='','Opposite-faction reward visible after scan')
assert(tooltip(15008)=='','Ordinary equipment reward must not appear after scan')
assert(tooltip(15009)=='','Generic related item visible after full scan')
print('ALL QUEST ITEM RELATION PATH TESTS PASSED')