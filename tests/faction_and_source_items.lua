-- Mock Forever regression: faction filtering + quest-provided item recognition.
_G.QuestItemTrackerDB=nil
_G.DEFAULT_CHAT_FRAME={AddMessage=function() end}
_G.SlashCmdList={}
_G.NUM_BAG_SLOTS=4
_G.NUM_BANKBAGSLOTS=7
_G.BANK_CONTAINER=-1
_G.UnitName=function() return 'Tester' end
_G.GetRealmName=function() return 'Forever' end
_G.GetBuildInfo=function() return '1.60','x','x',16001 end
_G.GetQuestDifficultyColor=function() return {r=1,g=0.5,b=0} end
local faction='Horde'
_G.UnitFactionGroup=function() return faction end
local ally=4294967373
local horde=8589934770
_G.LibQuestieDB={RequireContract=function(v) return v==4 end,Enum={factionRaceMasks={Alliance=ally,Horde=horde}}}
local names={ [100]='Horde Finished',[200]='Alliance Future',[300]='Neutral Work',[6134]='Ghost-o-plasm Round Up',[400]='Alliance Skyborne',[500]='Horde Skyborne',[601]='Spell tool',[602]='Required source',[603]='Item starter',[604]='Event reference',[605]='Reward-only',[606]='Repeatable item'}
local levels={ [100]=18,[200]=19,[300]=20,[6134]=39,[400]=60,[500]=60,[601]=30,[602]=30,[603]=30,[604]=30,[605]=30,[606]=30}
local raceMasks={ [100]=horde,[200]=ally,[300]=0,[6134]=0,[400]=4294967296,[500]=8589934592}
_G.QuestDB={
 GetAllIds=function()return {100,200,300,400,500,601,602,603,604,605,606,6134} end,
 name=function(id)return names[id] end,
 questLevel=function(id)return levels[id] end,
 requiredRaces=function(id)return raceMasks[id] end,
 objectives=function(id)
  if id==100 or id==200 then return {nil,nil,{{9001,'Mixed item',3}}} end
  if id==300 then return {nil,nil,{{9003,'Neutral item',2}}} end
  if id==400 or id==500 then return {nil,nil,{{9004,'Skyborne item',2}}} end
  if id==601 then return {[6]={{8,'Cast spell',9101}}} end
  if id==606 then return {[3]={{9107,'Repeat item',2}}} end
  return {nil,nil,{{15849,'Ghost-o-Plasm',8}}}
 end,
 requiredSourceItems=function(id)return id==602 and {9102} or nil end,
 startedBy=function(id)return id==603 and {[3]={9103}} or nil end,
 extraObjectives=function(id)return id==604 and {{{},3,'Event',0,{{'item',9105}}}} or nil end,
 specialFlags=function(id)return id==606 and 1 or 0 end,
 sourceItemId=function(id)return id==6134 and 15848 or 0 end,
}
_G.ItemDB={relatedQuests=function(id)
 if id==9001 then return {100,200} end
 if id==9003 then return {300} end
 if id==9004 then return {400,500} end
 if id==9101 then return {601} end
 if id==9103 then return {603} end
 if id==9105 then return {604} end
 if id==9107 then return {606} end
 -- Item 15848 has no reverse relation: the active-quest fallback must work.
 return nil
 end, startQuest=function(id)return id==9104 and 603 or 0 end, questRewards=function(id)return id==9106 and {605} end}
_G.C_Item={GetItemName=function(id)return ({[9001]='Mixed Item',[9003]='Neutral Item',[9004]='Skyborne Item',[15848]='Crate of Ghost Magnets',[6948]='Hearthstone',[9101]='Spell tool',[9102]='Required source',[9103]='Quest starter',[9104]='Item starter via itemDB',[9105]='Event item',[9106]='Reward-only',[9107]='Repeat item'})[id] end}
_G.GetItemInfo=function(id)return C_Item.GetItemName(id) end
local completed={[100]=true,[606]=true}
_G.C_QuestLog={
 GetNumQuestLogEntries=function()return 2 end,
 GetInfo=function(i) if i==1 then return {questID=6134,isHeader=false,title=names[6134],level=39,isComplete=false} end if i==2 then return {questID=602,isHeader=false,title=names[602],level=30,isComplete=false} end end,
 GetQuestObjectives=function()return {} end,
 GetAllCompletedQuestIDs=function()return {100,606} end,
 IsQuestFlaggedCompleted=function(id)return completed[id] or false end,
 IsRepeatableQuest=function()return false end,
 IsQuestReplayable=function()return false end,
 IsQuestTrivial=function()return false end,
 GetQuestDifficultyLevel=function(id)return levels[id] end,
 GetTitleForQuestID=function(id)return names[id] end,
}
_G.BankFrame={IsShown=function()return false end}
local itemcounts={[9001]=1,[9003]=2,[9004]=1,[15848]=1}
local inventory={{id=9001,count=1},{id=9003,count=2},{id=9004,count=1},{id=15848,count=1}}
_G.C_Container={
 GetContainerNumSlots=function(b)return b==0 and #inventory or 0 end,
 GetContainerItemID=function(b,slot)return b==0 and inventory[slot] and inventory[slot].id end,
 GetContainerItemInfo=function(b,slot)return b==0 and inventory[slot] and {stackCount=inventory[slot].count} end,
}
local frames={}
local function Frame(kind,name,parent)
 local f={kind=kind,name=name,parent=parent,scripts={},events={},shown=true}
 function f:RegisterEvent(x) self.events[x]=true end
 function f:SetScript(k,v)self.scripts[k]=v end
 function f:Show()self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
 function f:Hide()self.shown=false end
 function f:IsShown()return self.shown end
 function f:SetChecked(x)self.checked=x end
 function f:GetChecked()return self.checked end
 function f:SetText(x)self.text=x end
 function f:SetSize()end
 function f:SetPoint()end
 function f:ClearAllPoints()end
 function f:GetCenter()return 570,460 end
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
function Minimap:GetCenter()return 500,500 end
local typed
_G.Enum={TooltipDataType={Item=222}}
_G.TooltipDataProcessor={AddTooltipPostCall=function(_,cb)typed=cb end}
_G.GameTooltip={lines={},scripts={}}
function GameTooltip:HookScript(event,cb)self.scripts[event]=cb end
function GameTooltip:AddLine(line)self.lines[#self.lines+1]=line end
function GameTooltip:GetItem()return nil,nil end
function GameTooltip:Show()self.shown=true end
function GameTooltip:Hide()self.shown=false end
function GameTooltip:SetBagItem()end
function GameTooltip:SetHyperlink()end
function GameTooltip:SetOwner()end
function GameTooltip:ClearLines()self.lines={} end
_G.hooksecurefunc=function(obj,key,hook)
 local func=obj[key]; obj[key]=function(self,...)local ret=func(self,...); hook(self,...);return ret end
end
assert(loadfile('QuestItemTracker/QuestItemTracker.lua'))('QuestItemTracker')
local main,button,panel
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then main=f end end
assert(main,'main frame not found')
main.scripts.OnEvent(main,'PLAYER_LOGIN')
assert(typed,'typed hook missing')
local function tooltip(id)
 GameTooltip:ClearLines()
 if GameTooltip.scripts.OnTooltipCleared then GameTooltip.scripts.OnTooltipCleared(GameTooltip) end
 typed(GameTooltip,{id=id,type=222})
 return table.concat(GameTooltip.lines,'\n')
end
-- Source-given crate is recognized immediately, with ItemDB.relatedQuests() nil,
-- before QuestieDB's background index has had an OnUpdate tick.
local early=tooltip(15848)
assert(early:find('Ghost-o-plasm Round Up',1,true), 'crate not recognized during index warmup: '..early)
assert(early:find('NEEDED',1,true), 'crate incorrectly marked no longer needed while active')
assert(not early:find('SAFE TO DELETE',1,true),'warmup must not say safe to delete')
for _,f in ipairs(frames) do
 if f~=main and f.scripts.OnUpdate then
  for i=1,20 do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,0.016) end end
 end
end
local final=tooltip(15848)
assert(final:find('Ghost-o-plasm Round Up',1,true),'index did not register quest-giver-provided sourceItemId')
assert(final:find('NEEDED',1,true),'provided active item not marked NEEDED')
assert(tooltip(6948)=='','ordinary item was decorated')
local filtered=tooltip(9001)
assert(filtered:find('Horde Finished',1,true),'Horde quest absent: '..filtered)
assert(not filtered:find('Alliance Future',1,true),'Alliance quest leaked into Horde tooltip')
assert(filtered:find('SAFE TO DELETE',1,true),'opposing unfinished quest incorrectly forced KEEP: '..filtered)
assert(tooltip(9003):find('Neutral Work',1,true),'unrestricted quest must show on both factions')
local sky=tooltip(9004)
assert(sky:find('Horde Skyborne',1,true) and not sky:find('Alliance Skyborne',1,true),'high-bit mask intersects incorrectly')
for _,f in ipairs(frames) do if f.name=='QITMinimapButton' then button=f end end
assert(button and button.scripts.OnClick,'minimap missing')
button.scripts.OnClick(button,'LeftButton')
for _,f in ipairs(frames) do if f.name=='QITOptionsPanel' then panel=f end end
assert(panel and panel:IsShown(),'settings panel missing')
local checks={}
for _,f in ipairs(frames) do if f.kind=='CheckButton' then checks[#checks+1]=f end end
assert(#checks==7,'expected 7 settings switches, got '..#checks)
assert(checks[1]:GetChecked()==true,'faction filtering should default on')
checks[1]:SetChecked(false);checks[1].scripts.OnClick(checks[1])
local unfiltered=tooltip(9001)
assert(unfiltered:find('Horde Finished',1,true) and unfiltered:find('Alliance Future',1,true),'filter switch did not restore both quest entries')
assert(unfiltered:find('KEEP',1,true),'unfiltered future Alliance quest did not keep item')
checks[1]:SetChecked(true);checks[1].scripts.OnClick(checks[1])
faction='Alliance'
local alliance=tooltip(9001)
assert(alliance:find('Alliance Future',1,true) and not alliance:find('Horde Finished',1,true),'Alliance view did not filter Horde quest')
assert(alliance:find('KEEP',1,true),'Alliance future item should be kept')
local allianceSky=tooltip(9004)
assert(allianceSky:find('Alliance Skyborne',1,true) and not allianceSky:find('Horde Skyborne',1,true),'Alliance Skyborne mask incorrect')
-- Item-bearing quest paths that previously fell through QIT's lookup.
assert(tooltip(9101):find('Spell tool',1,true),'spell-use item not indexed')
local neededSource=tooltip(9102)
assert(neededSource:find('Required source',1,true) and neededSource:find('NEEDED',1,true),'requiredSourceItems wrongly treated as a starter')
assert(tooltip(9103):find('STARTS QUEST',1,true),'quest-side item starter missing')
assert(tooltip(9104):find('KEEP',1,true),'ItemDB.startQuest missing')
local event=tooltip(9105)
assert(event:find('Event reference',1,true) and event:find('REVIEW',1,true) and not event:find('SAFE TO DELETE',1,true),'event reference incorrectly declared safe')
assert(tooltip(9106)=='','reward-only item should not be decorated')
local repeatable=tooltip(9107)
assert(repeatable:find('KEEP',1,true) and not repeatable:find('SAFE TO DELETE',1,true),'QuestieDB repeatable flag was ignored')
print('FACTION + PROVIDED-ITEM TESTS PASSED')