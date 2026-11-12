-- Standalone simulated WoW Forever client for the QIT minimap settings UI.
_G.QuestItemTrackerDB = nil
_G.C_AddOns = {GetAddOnMetadata=function(addon,key)
  assert(addon=='QuestItemTracker','version metadata must target the internal addon name')
  if key=='Version' then return '0.4' end
end}
_G.DEFAULT_CHAT_FRAME = {AddMessage=function(_, message) print('CHAT: '..message) end}
_G.SlashCmdList = {}
_G.NUM_BAG_SLOTS = 4
_G.NUM_BANKBAGSLOTS = 7
_G.BANK_CONTAINER = -1
_G.UnitName=function() return 'Tester' end
_G.GetRealmName=function() return 'Forever' end
_G.GetBuildInfo=function() return '1.60','x','x',16001 end
_G.GetQuestDifficultyColor=function() return {r=1,g=0.5,b=0} end
_G.C_Item={GetItemName=function(id) return ({[4894]='Plainstrider Kidney',[6948]='Hearthstone'})[id] end}
_G.GetItemInfo=function(id) return C_Item.GetItemName(id) end
_G.LibQuestieDB={RequireContract=function(v) return v==4 end}
_G.QuestDB={
  GetAllIds=function() return {821,700,701,901,902,1001,1002,1003,1004,1005} end,
  name=function(id)
    return ({[700]="Grey Forager",[701]="Grey Farmer",[901]="Repeatable Hunt",
      [902]="Repeatable Offering",[821]="Chen's Empty Keg",
      [1001]="A Donation of Wool",[1002]="A Donation of Wool",
      [1003]="A Donation of Wool",[1004]="A Donation of Wool",
      [1005]="A Donation of Wool"})[id]
  end,
  questLevel=function(id) return (id>=1001 and id<=1005) and 60 or ((id==700 or id==701) and 6 or 15) end,
  specialFlags=function(id) return (id==901 or id==902) and 1 or 0 end,
  objectives=function(id) return {nil,nil,{{4894,'Plainstrider Kidney',id==700 and 2 or 5}}} end,
  requiredSourceItems=function() return nil end,
}
_G.ItemDB={relatedQuests=function(id) if id==4894 then return {821,700,701,901,902,1001,1002,1003,1004,1005} end end}
_G.C_QuestLog={
  GetNumQuestLogEntries=function() return 0 end,
  GetInfo=function() end,
  GetQuestObjectives=function() return {} end,
  GetAllCompletedQuestIDs=function() return {} end,
  IsQuestFlaggedCompleted=function() return false end,
  IsRepeatableQuest=function() return false end,
  IsQuestReplayable=function() return false end,
  IsQuestTrivial=function(id) return id==700 or id==701 end,
  GetQuestDifficultyLevel=function() return 15 end,
  GetTitleForQuestID=function() return "Chen's Empty Keg" end,
}
_G.BankFrame={IsShown=function() return true end}
local contents={[0]={[1]={id=4894,count=3}},[-1]={[1]={id=4894,count=2}}}
_G.C_Container={
 GetContainerNumSlots=function(b) return contents[b] and #contents[b] or 0 end,
 GetContainerItemID=function(b,slot) return contents[b] and contents[b][slot] and contents[b][slot].id end,
 GetContainerItemInfo=function(b,slot) local it=contents[b] and contents[b][slot]; return it and {stackCount=it.count} end,
}

local frames={}
local function MockFrame(kind,name,parent)
  local f={kind=kind,name=name,parent=parent,scripts={},events={},points={},shown=true}
  function f:RegisterEvent(event) self.events[event]=true end
  function f:SetScript(event,fn) self.scripts[event]=fn end
  function f:GetScript(event) return self.scripts[event] end
  function f:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
  function f:Hide() self.shown=false end
  function f:IsShown() return self.shown end
  function f:SetChecked(v) self.checked=v end
  function f:GetChecked() return self.checked end
  function f:SetText(v) self.text=v end
  function f:SetSize(w,h) self.w=w; self.h=h end
  function f:SetPoint(...) self.points[#self.points+1]={...} end
  function f:ClearAllPoints() self.points={} end
  function f:GetCenter() return self.cx or 570, self.cy or 460 end
  function f:StartMoving() self.moving=true end
  function f:StopMovingOrSizing() self.moving=false end
  function f:SetFrameStrata() end
  function f:SetClampedToScreen() end
  function f:EnableMouse() end
  function f:SetMovable() end
  function f:RegisterForDrag() end
  function f:RegisterForClicks() end
  function f:SetHeight() end
  function f:SetWidth() end
  function f:SetAllPoints() end
  function f:SetTexture(texture) self.texture=texture end
  function f:SetTextColor(r,g,b,a) self.textColor={r,g,b,a} end
  function f:SetColorTexture() end
  function f:SetTexCoord() end
  function f:CreateTexture() return MockFrame('Texture',nil,self) end
  function f:CreateFontString() return MockFrame('FontString',nil,self) end
  frames[#frames+1]=f
  return f
end
_G.CreateFrame=MockFrame
_G.UIParent=MockFrame('Frame','UIParent')
_G.Minimap=MockFrame('Frame','Minimap')
function Minimap:GetCenter() return 500,500 end
local typedHook
_G.Enum={TooltipDataType={Item=222}}
_G.TooltipDataProcessor={AddTooltipPostCall=function(_,fn) typedHook=fn end}
_G.GameTooltip={lines={},scripts={}}
function GameTooltip:HookScript(event,fn) self.scripts[event]=fn end
function GameTooltip:AddLine(line) self.lines[#self.lines+1]=line end
function GameTooltip:GetItem() return nil,nil end
function GameTooltip:Show() self.shown=true end
function GameTooltip:Hide() self.shown=false end
function GameTooltip:SetBagItem() end
function GameTooltip:SetHyperlink() end
function GameTooltip:SetOwner() end
function GameTooltip:ClearLines() self.lines={} end
_G.hooksecurefunc=function(t,method,hook)
  local fn=t[method]
  t[method]=function(self,...) local r=fn(self,...);hook(self,...);return r end
end
local chunk=assert(loadfile('QuestItemTracker/QuestItemTracker.lua')); chunk('QuestItemTracker')
local main
for _, f in ipairs(frames) do if f.events.PLAYER_LOGIN then main=f;break end end
assert(main,'main event frame absent')
main.scripts.OnEvent(main,'PLAYER_LOGIN')
-- Exercise full-index behavior rather than the temporary warm-up tooltip.
for _, worker in ipairs(frames) do
  if worker ~= main and worker.scripts.OnUpdate then
    for i=1,15 do
      if worker.scripts.OnUpdate then worker.scripts.OnUpdate(worker,0.016) end
    end
  end
end
assert(typedHook,'typed tooltip hook not installed')
local button
for _, f in ipairs(frames) do if f.name=='QITMinimapButton' then button=f end end
assert(button,'minimap bubble not created at login')
assert(button.scripts.OnClick,'minimap bubble has no click behavior')
button.scripts.OnClick(button,'LeftButton')
local panel
for _, f in ipairs(frames) do if f.name=='QITOptionsPanel' then panel=f end end
assert(panel and panel:IsShown(),'minimap button did not open settings')
local seenTitle, versionLabel, panelVersionCount = false, nil, 0
for _, f in ipairs(frames) do
  if f.kind=='FontString' and f.parent==panel then
    if f.text=='Quest Item Tracker Forever' then seenTitle=true end
    if f.text=='v0.4' then versionLabel=f; panelVersionCount=panelVersionCount+1 end
  end
end
assert(seenTitle, 'settings title changed unexpectedly')
assert(versionLabel and panelVersionCount==1, 'settings version must come from TOC exactly once')
assert(versionLabel.textColor and versionLabel.textColor[1]<0.8, 'version should be a subtle muted label')
local iconPath='Interface\\AddOns\\QuestItemTracker\\Media\\QITIcon'
local matchedIcon=false
for _, f in ipairs(frames) do
  if f.kind=='Texture' and f.parent==button and f.texture==iconPath then
    matchedIcon=true
  end
end
assert(matchedIcon,'minimap button must use the custom matching quest-book icon')
local checks={}
for _, f in ipairs(frames) do if f.kind=='CheckButton' then checks[#checks+1]=f end end
assert(#checks==6,'expected six settings switches')
assert(checks[1]:GetChecked(),'faction filter should be enabled by default')
assert(not checks[6]:GetChecked(),'future labels must be hidden by default')
assert(checks[2]:GetChecked()==false and checks[3]:GetChecked()==false,'IDs must be off by default')
assert(checks[4]:GetChecked() and checks[5]:GetChecked(),'levels/count breakdown must be on by default')
local function tooltip(id)
  GameTooltip:ClearLines()
  if GameTooltip.scripts.OnTooltipCleared then GameTooltip.scripts.OnTooltipCleared(GameTooltip) end
  typedHook(GameTooltip,{id=id,type=222})
  return table.concat(GameTooltip.lines,'\n')
end
local clean=tooltip(4894)
assert(clean:find("Chen's Empty Keg",1,true),'quest name not shown')
assert(clean:find('Grey Forager',1,true),'grey quest name must remain visible')
assert(clean:find('LOW-LEVEL QUESTS',1,true),'low-level group heading missing')
assert(clean:find('FACTION TURN-INS',1,true),'faction donation heading missing')
assert(clean:find('A Donation of Wool',1,true),'donation quest missing')
assert(clean:find('(5 quests)',1,true),'five identical donation quests must be combined')
assert(not clean:find('A Donation of Wool',clean:find('A Donation of Wool',1,true)+1,true),
  'duplicate donation rows were not compacted')
assert(clean:find('REPEATABLE QUESTS',1,true),'repeatable group heading missing')
assert(clean:find('Grey Forager',1,true) and clean:find('Grey Farmer',1,true),
  'both low-level quest names must remain visible')
assert(clean:find('Repeatable Hunt',1,true) and clean:find('Repeatable Offering',1,true),
  'both repeatable quest names must remain visible')
local function occurrences(haystack, needle)
  local total, start=0,1
  while true do
    local index=haystack:find(needle,start,true)
    if not index then return total end
    total=total+1
    start=index+#needle
  end
end
assert(occurrences(clean,'REPEATABLE QUESTS')==1,'repeatable heading duplicated')
assert(occurrences(clean,'LOW-LEVEL QUESTS')==1,'low-level heading duplicated')
assert(occurrences(clean,'FACTION TURN-INS')==1,'faction heading duplicated')
assert(occurrences(clean,'REPEATABLE QUEST')==1,'repeatable status must not repeat per quest')
assert(occurrences(clean,'GREY QUEST')==0,'grey status must not repeat per quest')
assert(clean:find("Chen's Empty Keg",1,true)<clean:find('REPEATABLE QUESTS',1,true),
  'ordinary quests should be listed before repeatables')
assert(clean:find('REPEATABLE QUESTS',1,true)<clean:find('LOW-LEVEL QUESTS',1,true),
  'low-level group should be after repeatables')
assert(not clean:find('FUTURE QUEST',1,true) and not clean:find('FUTURE USE',1,true),'future status lines should be suppressed by default')
assert(not clean:find('No current quest needs',1,true),'redundant future footer must be suppressed')
assert(clean:find('|cffc0c0c0Grey Forager',1,true),'grey quest color code is malformed')
assert(clean:find('Have 5 / Need 5',1,true),'Have/Need was lost')
assert(clean:find('(Level 15)',1,true),'quest level should appear by default')
assert(not clean:find('Quest ID:',1,true) and not clean:find('Item ID:',1,true),'IDs visible by default')
assert(clean:find('Bags: 3 | Bank: 2',1,true),'default bank counts missing')
assert(tooltip(6948)=='','ordinary item was decorated')
checks[6]:SetChecked(true);checks[6].scripts.OnClick(checks[6])
local detailedFuture=tooltip(4894)
assert(detailedFuture:find('FUTURE QUEST',1,true),'optional future quest status not restored')
assert(detailedFuture:find('LOW-LEVEL QUESTS',1,true) and not detailedFuture:find('FUTURE USE · GREY QUEST',1,true),
  'grey quests should stay grouped even when detailed status labels are enabled')
assert(detailedFuture:find('REPEATABLE QUESTS',1,true) and occurrences(detailedFuture,'REPEATABLE QUEST')==1,
  'repeatable heading should not duplicate its per-quest label in detailed mode')
assert(detailedFuture:find('No current quest needs',1,true),'optional future footer not restored')
checks[6]:SetChecked(false);checks[6].scripts.OnClick(checks[6])
assert(not tooltip(4894):find('FUTURE QUEST',1,true),'future status does not turn off')
for _,i in ipairs({2,3}) do
  checks[i]:SetChecked(true);checks[i].scripts.OnClick(checks[i])
end
local detailed=tooltip(4894)
assert(detailed:find('Quest ID: 821',1,true),'quest ID setting failed')
assert(detailed:find('Quest IDs: 1001, 1002, 1003, 1004, 1005',1,true),
  'collapsed quest IDs must remain accessible when enabled')
assert(detailed:find('Item ID: 4894',1,true),'item ID setting failed')
for _,i in ipairs({4,5}) do
 checks[i]:SetChecked(false);checks[i].scripts.OnClick(checks[i])
end
local compact=tooltip(4894)
assert(not compact:find('(Level 15)',1,true),'level-off setting failed')
assert(not compact:find('Bags:',1,true),'breakdown-off setting failed')
assert(compact:find('Have 5 / Need 5',1,true),'essential Have/Need changed')
assert(QuestItemTrackerDB.settings.showQuestIDs==true,'settings not persisted')
button.scripts.OnClick(button,'LeftButton')
assert(not panel:IsShown(),'minimap click did not close settings')
SlashCmdList.QUESTITEMTRACKER('options')
assert(panel:IsShown(),'/qit options did not open settings')
local reset
for _, f in ipairs(frames) do if f.text=='Reset defaults' and f.kind=='Button' then reset=f end end
assert(reset,'reset button missing')
reset.scripts.OnClick(reset)
local restored=tooltip(4894)
assert(not restored:find('Quest ID:',1,true),'reset did not hide quest IDs')
assert(not restored:find('Item ID:',1,true),'reset did not hide item IDs')
assert(restored:find('(Level 15)',1,true),'reset did not show quest levels')
assert(restored:find('Bags: 3 | Bank: 2',1,true),'reset did not show breakdown')
assert(not restored:find('FUTURE QUEST',1,true),'reset did not hide future labels')
assert(restored:find('LOW-LEVEL QUESTS',1,true),'reset did not keep low-level group')
button.scripts.OnDragStart(button)
button.scripts.OnDragStop(button)
assert(type(QuestItemTrackerDB.settings.minimapX)=='number','minimap position not saved')
assert(type(QuestItemTrackerDB.settings.minimapY)=='number','minimap position not saved')
assert(not button.moving,'drag left the button in moving state')
print('MINIMAP SETTINGS TESTS PASSED')