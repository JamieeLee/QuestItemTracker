-- Standalone simulated WoW Forever client for the QIT minimap settings UI.
_G.QuestItemTrackerDB = nil
local questieInstalled, questieEnabled, questieLoaded = true, true, true
_G.C_AddOns = {
  DoesAddOnExist=function(name)
    assert(name=='QuestieDB')
    return questieInstalled
  end,
  GetAddOnEnableState=function(name)
    assert(name=='QuestieDB')
    return questieEnabled and 2 or 0
  end,
  IsAddOnLoaded=function(name)
    assert(name=='QuestieDB')
    return questieLoaded
  end,
  GetAddOnInfo=function(name)
    assert(name=='QuestieDB')
    local reason=not questieInstalled and 'MISSING'
      or (not questieEnabled and 'DISABLED' or nil)
    return name,'QuestieDB','',questieEnabled,reason,'INSECURE'
  end,
  GetAddOnMetadata=function(addon,key)
  assert(addon=='QuestItemTracker','version metadata must target the internal addon name')
  if key=='Version' then return '0.5' end
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
  function f:HookScript(event,fn)
    local previous=self.scripts[event]
    self.scripts[event]=function(...)
      if previous then previous(...) end
      fn(...)
    end
  end
  function f:GetScript(event) return self.scripts[event] end
  function f:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
  function f:Hide() self.shown=false end
  function f:IsShown() return self.shown end
  function f:SetChecked(v) self.checked=v end
  function f:GetChecked() return self.checked end
  function f:SetText(v) self.text=v end
  function f:SetSize(w,h) self.w=w; self.h=h end
  function f:SetHitRectInsets(...) self.hitInsets={...} end
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
  function f:SetVertexColor(r,g,b,a) self.vertexColor={r,g,b,a} end
  function f:SetTextColor(r,g,b,a) self.textColor={r,g,b,a} end
  function f:SetColorTexture(r,g,b,a) self.color={r,g,b,a} end
  function f:SetTexCoord() end
  function f:CreateTexture() return MockFrame('Texture',nil,self) end
  function f:CreateFontString() return MockFrame('FontString',nil,self) end
  frames[#frames+1]=f
  return f
end
_G.CreateFrame=MockFrame
_G.UIParent=MockFrame('Frame','UIParent')
_G.Minimap=MockFrame('Frame','Minimap')
Minimap:SetSize(140,140)
function Minimap:GetCenter() return 500,500 end
function Minimap:GetWidth() return self.w end
function Minimap:GetHeight() return self.h end
function Minimap:GetEffectiveScale() return 1 end
local minimapShape='ROUND'
_G.GetMinimapShape=function() return minimapShape end
local cursorX,cursorY=590,540
_G.GetCursorPosition=function() return cursorX,cursorY end
local typedHook
_G.Enum={TooltipDataType={Item=222}}
_G.TooltipDataProcessor={AddTooltipPostCall=function(_,fn) typedHook=fn end}
_G.GameTooltip={lines={},scripts={}}
function GameTooltip:HookScript(event,fn) self.scripts[event]=fn end
local function tooltipFontString(value)
  return {text=value,height=14,
    GetText=function(self)return self.text end,
    SetText=function(self,v)self.text=v end,
    GetHeight=function(self)return self.height end,
    SetHeight=function(self,v)self.height=v end,
  }
end
function GameTooltip:GetName()return "GameTooltip" end
function GameTooltip:NumLines()return #self.lines end
function GameTooltip:AddLine(line)
  self.lines[#self.lines+1]=line
  _G["GameTooltipTextLeft"..#self.lines]=tooltipFontString(line)
  _G["GameTooltipTextRight"..#self.lines]=tooltipFontString("")
end
function GameTooltip:AddDoubleLine(left,right)
  self:AddLine(left)
  _G["GameTooltipTextRight"..#self.lines]:SetText(right)
end
function GameTooltip:GetItem() return nil,nil end
function GameTooltip:Show() self.shown=true end
function GameTooltip:Hide() self.shown=false end
function GameTooltip:SetBagItem() end
function GameTooltip:SetHyperlink() end
function GameTooltip:SetOwner(owner,anchor) self.owner=owner; self.anchor=anchor end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:SetText(text) self.title=text end
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
local function checkButtonOnRim(radiusX,radiusY)
  local p=button.points[#button.points]
  assert(p and p[1]=='CENTER' and p[2]==Minimap and p[3]=='CENTER',
    'QITF minimap button must anchor to the minimap center')
  local normalized=(p[4]/radiusX)^2+(p[5]/radiusY)^2
  assert(math.abs(normalized-1)<0.002,
    'QITF minimap button must stay on the outer rim, not inside the map')
  return p
end
local startRim=checkButtonOnRim(75,75)
assert(startRim[4]>0 and startRim[5]<0,
  'default minimap position should be lower-right')
-- The approved badge has its own rim and ribbon; adding a tracking border
-- or the original book would cover its tiny FOREVER lettering.
local badge, extraBorders=0,0
for _, f in ipairs(frames) do
  if f.parent==button and f.kind=='Texture' then
    if f.texture=='Interface\\AddOns\\QuestItemTracker\\Media\\QITForeverBadge' then
      assert(f.w==30 and f.h==30 and f.points[1][1]=='CENTER',
        'the approved QITF badge must be centered at minimap button size')
      badge=badge+1
    elseif f.texture=='Interface\\Minimap\\UI-Minimap-Background'
        or f.texture=='Interface\\Minimap\\MiniMap-TrackingBorder' then
      extraBorders=extraBorders+1
    end
  end
end
assert(badge==1 and extraBorders==0,
  'minimap needs one approved QITF badge without overlaying extra border artwork')
button.scripts.OnClick(button,'LeftButton')
local panel
for _, f in ipairs(frames) do if f.name=='QITOptionsPanel' then panel=f end end
assert(panel and panel:IsShown(),'minimap button did not open settings')

-- The out-of-box QITF theme should feel like Warcraft, not neon-blue UI.
-- Native templates (close, reset, checkboxes) remain available for UI skins.
local panelTextures={}
for _,f in ipairs(frames) do
  if f.kind=='Texture' and f.parent==panel and f.color then
    panelTextures[#panelTextures+1]=f
  end
end
local hasWarmTrim,hasCharcoal,hasQuietBand,hasGoldStripe=false,false,false,false
for _,f in ipairs(panelTextures) do
  local r,g,b=f.color[1],f.color[2],f.color[3]
  if r>g and g>b and r>0.3 and r<0.6 then hasWarmTrim=true end
  if r<0.09 and g<0.09 and b<0.09 then hasCharcoal=true end
  if r>g and g>b and r>0.1 and r<0.2 then hasQuietBand=true end
  if r>0.6 and r>g and g>b then hasGoldStripe=true end
end
assert(hasWarmTrim and hasCharcoal and hasQuietBand and hasGoldStripe,
  'default settings frame needs warm gold trim, charcoal base, and quiet title accent')
local nativeClose=false
for _,f in ipairs(frames) do
  if f.kind=='Button' and f.parent==panel and f.scripts.OnClick and
     f~=panel then
    nativeClose=true
  end
end
assert(nativeClose,'settings must retain its standard close button')

-- A small dot with a plain-English reason when QuestieDB is missing or disabled.
local statusLight
for _,f in ipairs(frames) do
  if f.name=='QITQuestieDBStatus' then statusLight=f end
end
assert(statusLight and statusLight.parent==panel and statusLight.dot,
  'dependency light missing or placed outside settings panel')
assert(statusLight.dot.kind=='Texture' and statusLight.dot.texture==
  'Interface\\AddOns\\QuestItemTracker\\Media\\StatusCircle',
  'dependency light should use the dedicated round texture, not a square font glyph')
assert(statusLight.w==20 and statusLight.h==20,
  'dependency light must stay small and unobtrusive')
assert(statusLight.dot.vertexColor and statusLight.dot.vertexColor[2]>0.8,
  'working QuestieDB must show a green status light')

local function testStatusHover(title,needle)
  GameTooltip:ClearLines()
  GameTooltip.shown=false
  statusLight.scripts.OnEnter(statusLight)
  assert(GameTooltip.shown and GameTooltip:GetOwner()==statusLight,
    'dependency light must show its help on hover')
  assert(GameTooltip.title==title,
    'dependency hover has wrong title: '..tostring(GameTooltip.title))
  assert(table.concat(GameTooltip.lines,' '):find(needle,1,true),
    'dependency help did not explain what to do')
  statusLight.scripts.OnLeave(statusLight)
  assert(not GameTooltip.shown,'dependency help must close on mouse leave')
end
testStatusHover('Quest Item Tracker Forever is ready','QuestieDB: Installed and enabled')

local previousLib,previousQuestDB=LibQuestieDB,QuestDB

-- The user disabled QuestieDB in WoW, so QIT loads without a database.
questieEnabled,questieLoaded=false,false
LibQuestieDB=nil
panel:Hide();panel:Show()
assert(statusLight.dot.vertexColor[1]>0.9 and statusLight.dot.vertexColor[2]<0.5,
  'disabled QuestieDB must show a red status light')
testStatusHover('Quest Item Tracker Forever needs attention','QuestieDB: Installed but disabled')

-- The raw GitHub ZIP was installed without reading QuestieDB requirements.
questieInstalled=false
panel:Hide();panel:Show()
assert(statusLight.dot.vertexColor[1]>0.9,'missing QuestieDB must stay red')
testStatusHover('Quest Item Tracker Forever needs attention','QuestieDB: Not installed')

-- QuestieDB is installed but not loaded.
questieInstalled,questieEnabled=true,true
panel:Hide();panel:Show()
testStatusHover('Quest Item Tracker Forever needs attention','QuestieDB: Installed but not loaded')

-- A mismatched QuestieDB contract has a different, actionable explanation.
questieLoaded=true
LibQuestieDB={RequireContract=function() return false, 'mismatched database' end}
panel:Hide();panel:Show()
testStatusHover('Quest Item Tracker Forever needs attention','compatible version')

-- Once QuestieDB loads correctly, QIT returns to green without a reload.
LibQuestieDB,QuestDB=previousLib,previousQuestDB
main.scripts.OnEvent(main,'ADDON_LOADED','QuestieDB')
assert(statusLight.dot.vertexColor[2]>0.8,'light did not turn green when QuestieDB loaded')
testStatusHover('Quest Item Tracker Forever is ready','QuestieDB: Installed and enabled')

local toc=assert(io.open('QuestItemTracker/QuestItemTracker.toc','r'))
local tocText=toc:read('*a'); toc:close()
assert(tocText:find('## OptionalDeps: QuestieDB',1,true) and
  not tocText:find('## Dependencies: QuestieDB',1,true),
  'QIT must be able to load without QuestieDB to show the red warning')

local initialPoint=panel.points[#panel.points]
assert(initialPoint and initialPoint[1]=='CENTER' and initialPoint[2]==UIParent and
    initialPoint[3]=='CENTER' and initialPoint[4]==0 and initialPoint[5]==45,
    'new installs must use the original centered window position')
assert(QuestItemTrackerDB.settings.optionsPanelPosition==nil,
    'opening a fresh panel must not create a saved position')
local seenTitle, versionLabel, panelVersionCount = false, nil, 0
for _, f in ipairs(frames) do
  if f.kind=='FontString' and f.parent==panel then
    if f.text=='Quest Item Tracker Forever' then seenTitle=true end
    if f.text=='v0.5' then versionLabel=f; panelVersionCount=panelVersionCount+1 end
  end
end
assert(seenTitle, 'settings title changed unexpectedly')
assert(versionLabel and panelVersionCount==1, 'settings version must come from TOC exactly once')
assert(versionLabel.textColor and versionLabel.textColor[1]<0.8, 'version should be a subtle muted label')
local iconPath='Interface\\AddOns\\QuestItemTracker\\Media\\QITForeverBadge'
local matchedIcon=false
for _, f in ipairs(frames) do
  if f.kind=='Texture' and f.parent==button and f.texture==iconPath then
    matchedIcon=true
  end
end
assert(matchedIcon,'minimap button must use the approved QITF FOREVER badge')
local checks={}
for _, f in ipairs(frames) do if f.kind=='CheckButton' then checks[#checks+1]=f end end
assert(#checks==7,'expected seven settings switches')
assert(checks[1]:GetChecked(),'faction filter should be enabled by default')
assert(not checks[7]:GetChecked(),'future labels must be hidden by default')
assert(not checks[2]:GetChecked(),'other addon IDs must stay visible by default')
assert(checks[3]:GetChecked()==false and checks[4]:GetChecked()==false,'QIT IDs must be off by default')
assert(checks[5]:GetChecked() and checks[6]:GetChecked(),'levels/count breakdown must be on by default')

-- Every setting explains its purpose when hovered, without technical jargon.
-- The expanded hit area lets players hover (and click) on the label as well.
local expectedHelps={
  {'Only show my faction quests','opposite faction'},
  {'Hide IDs from other addons','off by default'},
  {'Show QITF quest IDs','quest ID'},
  {'Show QITF item IDs','item'},
  {'Show quest levels','Level 60'},
  {'Show bag / bank breakdown','bags and bank'},
  {'Show future quest labels','KEEP or NEEDED'},
}
for i, expected in ipairs(expectedHelps) do
  local check=checks[i]
  assert(check.hitInsets and check.hitInsets[2]<0,
    'toggle '..i..' must be hoverable over its label')
  assert(check.scripts.OnEnter and check.scripts.OnLeave,
    'toggle '..i..' must offer an on-hover explanation')
  GameTooltip:ClearLines()
  GameTooltip.shown=false
  check.scripts.OnEnter(check)
  assert(GameTooltip:GetOwner()==check and GameTooltip.shown,
    'hovering toggle '..i..' must open a tooltip owned by that toggle')
  assert(GameTooltip.title==expected[1],
    'hovering toggle '..i..' should name the setting')
  assert(table.concat(GameTooltip.lines,' '):find(expected[2],1,true),
    'hovering toggle '..i..' did not explain its effect')
  check.scripts.OnLeave(check)
  assert(not GameTooltip.shown,
    'hover help must disappear when leaving toggle '..i)
end

local function tooltip(id)
  GameTooltip:ClearLines()
  if GameTooltip.scripts.OnTooltipCleared then GameTooltip.scripts.OnTooltipCleared(GameTooltip) end
  typedHook(GameTooltip,{id=id,type=222})
  return table.concat(GameTooltip.lines,'\n')
end
-- Simulate the inventory UI's ItemID and IconID rows above our QIT section.
local function withExternalIDs()
  GameTooltip:ClearLines()
  GameTooltip:AddDoubleLine('ItemID','4894')
  GameTooltip:AddDoubleLine('IconID','132919')
  typedHook(GameTooltip,{id=4894,type=222})
  return _G.GameTooltipTextLeft1,_G.GameTooltipTextRight1,
         _G.GameTooltipTextLeft2,_G.GameTooltipTextRight2
end
local a,b,c,d=withExternalIDs()
assert(a:GetText()=='ItemID' and b:GetText()=='4894' and c:GetText()=='IconID' and d:GetText()=='132919',
  'external IDs must remain visible when suppression is off')
checks[2]:SetChecked(true);checks[2].scripts.OnClick(checks[2])
a,b,c,d=withExternalIDs()
assert(a:GetText()=='' and b:GetText()=='' and c:GetText()=='' and d:GetText()=='',
  'opt-in suppression must hide both sides of external metadata rows')
assert(a:GetHeight()==0 and c:GetHeight()==0,'hidden ID rows must not occupy full height')
-- QIT's own IDs are independently controlled, even while external IDs are hidden.
checks[3]:SetChecked(true);checks[3].scripts.OnClick(checks[3])
checks[4]:SetChecked(true);checks[4].scripts.OnClick(checks[4])
a,b,c,d=withExternalIDs()
local ownIDs=table.concat(GameTooltip.lines,'\\n')
assert(ownIDs:find('Item ID: 4894',1,true),'QIT item ID was suppressed')
assert(ownIDs:find('Quest ID: 821',1,true),'QIT quest ID was suppressed')
assert(a:GetText()=='' and c:GetText()=='','external metadata visible while suppression enabled')
checks[3]:SetChecked(false);checks[3].scripts.OnClick(checks[3])
checks[4]:SetChecked(false);checks[4].scripts.OnClick(checks[4])
checks[2]:SetChecked(false);checks[2].scripts.OnClick(checks[2])
a,b,c,d=withExternalIDs()
assert(a:GetText()=='ItemID' and c:GetText()=='IconID',
  'turning off external suppression must leave the other addon metadata alone')
-- This toggle changes only tooltip presentation, never quest-matching logic.
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
checks[7]:SetChecked(true);checks[7].scripts.OnClick(checks[7])
local detailedFuture=tooltip(4894)
assert(detailedFuture:find('FUTURE QUEST',1,true),'optional future quest status not restored')
assert(detailedFuture:find('LOW-LEVEL QUESTS',1,true) and not detailedFuture:find('FUTURE USE · GREY QUEST',1,true),
  'grey quests should stay grouped even when detailed status labels are enabled')
assert(detailedFuture:find('REPEATABLE QUESTS',1,true) and occurrences(detailedFuture,'REPEATABLE QUEST')==1,
  'repeatable heading should not duplicate its per-quest label in detailed mode')
assert(detailedFuture:find('No current quest needs',1,true),'optional future footer not restored')
checks[7]:SetChecked(false);checks[7].scripts.OnClick(checks[7])
assert(not tooltip(4894):find('FUTURE QUEST',1,true),'future status does not turn off')
for _,i in ipairs({3,4}) do
  checks[i]:SetChecked(true);checks[i].scripts.OnClick(checks[i])
end
local detailed=tooltip(4894)
assert(detailed:find('Quest ID: 821',1,true),'quest ID setting failed')
assert(detailed:find('Quest IDs: 1001, 1002, 1003, 1004, 1005',1,true),
  'collapsed quest IDs must remain accessible when enabled')
assert(detailed:find('Item ID: 4894',1,true),'item ID setting failed')
for _,i in ipairs({5,6}) do
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
-- Cursor drag follows the minimap rim live, and the direction persists.
cursorX,cursorY=450,610
button.scripts.OnDragStart(button)
assert(type(button.scripts.OnUpdate)=='function',
  'minimap button should orbit during drag instead of moving freely')
button.scripts.OnUpdate(button)
-- A live position must be present in SavedVariables *before* mouse release.
-- This protects clients that miss the final drag-stop callback.
local liveSaved=QuestItemTrackerDB.settings.minimapPosition
assert(type(liveSaved)=='table' and liveSaved.x<0 and liveSaved.y>0,
  'live minimap drag must persist current position before drag stop')
local dragged=checkButtonOnRim(75,75)
assert(dragged[4]<0 and dragged[5]>0,
  'drag must follow cursor into upper-left quadrant')
button.scripts.OnDragStop(button)
assert(button.scripts.OnUpdate==nil,
  'drag must stop updating when released')
assert(type(QuestItemTrackerDB.settings.minimapX)=='number','minimap position not saved')
assert(type(QuestItemTrackerDB.settings.minimapY)=='number','minimap position not saved')
local savedDrop=QuestItemTrackerDB.settings.minimapPosition
assert(type(savedDrop)=='table' and type(savedDrop.x)=='number'
    and type(savedDrop.y)=='number' and savedDrop.x<0 and savedDrop.y>0,
  'drag release must commit the final rim position to SavedVariables')

-- Some Forever UI layouts send mouse release without a drag-stop event.
-- This fallback must commit the drop without affecting normal clicks.
cursorX,cursorY=610,530
button.scripts.OnDragStart(button)
button.scripts.OnUpdate(button)
button.scripts.OnMouseUp(button,'LeftButton')
assert(button.scripts.OnUpdate==nil and not button.qitDragging,
  'mouse release must finalize the drag even if OnDragStop was not fired')
savedDrop=QuestItemTrackerDB.settings.minimapPosition
assert(type(savedDrop)=='table' and savedDrop.x>0 and savedDrop.y>0,
  'mouse release fallback did not commit the final location')
local oldDirectionX=QuestItemTrackerDB.settings.minimapX
local oldDirectionY=QuestItemTrackerDB.settings.minimapY

-- The ring grows or shrinks with UI skins; don't reuse fixed pixel offsets.
Minimap:SetSize(200,200)
assert(type(Minimap.scripts.OnSizeChanged)=='function',
  'minimap resize must trigger a new button position')
Minimap.scripts.OnSizeChanged(Minimap,200,200)
checkButtonOnRim(105,105)
assert(QuestItemTrackerDB.settings.minimapX==oldDirectionX and
  QuestItemTrackerDB.settings.minimapY==oldDirectionY,
  'resizing the map must not change the saved drag direction')

minimapShape='SQUARE'
Minimap.scripts.OnSizeChanged(Minimap,200,200)
local square=button.points[#button.points]
assert(math.max(math.abs(square[4]),math.abs(square[5]))>104,
  'square minimap skins should place the icon along the outer square perimeter')
minimapShape='ROUND'
Minimap:SetSize(140,140)
Minimap.scripts.OnSizeChanged(Minimap,140,140)
checkButtonOnRim(75,75)

-- Unlike closing/reopening one Frame, a UI reload recreates the frame.
-- Preserve only account-wide SavedVariables, then load addon Lua again.
local function cloneSavedVariables(value, seen)
  if type(value)~='table' then return value end
  seen=seen or {}
  if seen[value] then return seen[value] end
  local copy={}
  seen[value]=copy
  for key,item in pairs(value) do
    copy[cloneSavedVariables(key,seen)]=cloneSavedVariables(item,seen)
  end
  return copy
end
panel.cx, panel.cy = 895, 625
panel.scripts.OnDragStart(panel)
panel.scripts.OnDragStop(panel)
local position=QuestItemTrackerDB.settings.optionsPanelPosition
assert(position and position.x==325 and position.y==165,
  'dragging must save panel center offsets relative to UIParent')
assert(not panel.moving,'settings drag left the frame in moving state')
panel:Hide()
panel:Show()
assert(panel:IsShown() and QuestItemTrackerDB.settings.optionsPanelPosition.x==325,
  'closing and reopening must not lose saved positioning')

-- Mimic a client that misses both release callbacks: movement worked,
-- but /reload was invoked before OnDragStop or OnMouseUp. Position must persist.
cursorX,cursorY=390,440
button.scripts.OnDragStart(button)
button.scripts.OnUpdate(button)
local unsignaledDrop=QuestItemTrackerDB.settings.minimapPosition
assert(unsignaledDrop and unsignaledDrop.x<0 and unsignaledDrop.y<0,
  'missing release callback must not lose the current saved button position')
-- Simulate WoW writing the SavedVariables table to disk, then creating an
-- entirely new Lua environment on /reload (not just reopening the options).
local beforeReloadPoint=button.points[#button.points]
local beforeReload=#frames
local oldDatabase=QuestItemTrackerDB
_G.QuestItemTrackerDB=cloneSavedVariables(oldDatabase)
assert(QuestItemTrackerDB~=oldDatabase,
  'reload test must not reuse the original in-memory database table')
assert(QuestItemTrackerDB.settings.minimapPosition
  and QuestItemTrackerDB.settings.minimapPosition.x<0
  and QuestItemTrackerDB.settings.minimapPosition.y<0,
  'serialized SavedVariables lost the last dragged icon location')
assert(loadfile('QuestItemTracker/QuestItemTracker.lua'))('QuestItemTracker')
local reloadMain,reloadButton
for i=beforeReload+1,#frames do
  local f=frames[i]
  if f.events.PLAYER_LOGIN then reloadMain=f end
end
assert(reloadMain,'addon reload did not create login handler')
reloadMain.scripts.OnEvent(reloadMain,'PLAYER_LOGIN')
for i=beforeReload+1,#frames do
  local f=frames[i]
  if f.name=='QITMinimapButton' then reloadButton=f end
end
assert(reloadButton,'minimap button missing after UI reload')
local reloadedPoint=reloadButton.points[#reloadButton.points]
assert(reloadedPoint and math.abs(reloadedPoint[4]-beforeReloadPoint[4])<0.01
  and math.abs(reloadedPoint[5]-beforeReloadPoint[5])<0.01,
  'minimap badge must return to its dropped position after /reload')
reloadButton.scripts.OnClick(reloadButton,'LeftButton')
local restoredPanel
for i=beforeReload+1,#frames do
  local f=frames[i]
  if f.name=='QITOptionsPanel' then restoredPanel=f end
end
assert(restoredPanel and restoredPanel:IsShown(),'settings did not open after UI reload')
local restoredPoint=restoredPanel.points[#restoredPanel.points]
assert(restoredPoint and restoredPoint[1]=='CENTER' and restoredPoint[2]==UIParent and
    restoredPoint[3]=='CENTER' and restoredPoint[4]==325 and restoredPoint[5]==165,
    'saved panel position was not applied after a real addon reload')

-- Reset defaults also clears the stored position and centers the live panel.
local reloadedReset
for i=beforeReload+1,#frames do
  local f=frames[i]
  if f.kind=='Button' and f.text=='Reset defaults' and f.parent==restoredPanel then
    reloadedReset=f
  end
end
assert(reloadedReset,'reset control missing after reload')
reloadedReset.scripts.OnClick(reloadedReset)
local defaultPoint=restoredPanel.points[#restoredPanel.points]
assert(QuestItemTrackerDB.settings.optionsPanelPosition==nil and
    defaultPoint and defaultPoint[4]==0 and defaultPoint[5]==45,
    'reset defaults must clear saved panel position and recenter the window')
print('MINIMAP SETTINGS TESTS PASSED')