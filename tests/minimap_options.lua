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
  if key=='Version' then return '0.7-beta.11' end
end}
_G.DEFAULT_CHAT_FRAME = {AddMessage=function(_, message) print('CHAT: '..message) end}
_G.SlashCmdList = {}
_G.NUM_BAG_SLOTS = 4
_G.NUM_BANKBAGSLOTS = 7
_G.BANK_CONTAINER = -1
_G.UnitName=function() return 'Tester' end
_G.GetRealmName=function() return 'Forever' end
_G.GetBuildInfo=function() return '1.60','x','x',16001 end
_G.GetQuestDifficultyColor=function(level)
  if level == 6 then return {r=0.55,g=0.55,b=0.55} end
  return {r=1,g=0.5,b=0}
end
_G.C_Item={GetItemName=function(id) return ({[4894]='Plainstrider Kidney',[6948]='Hearthstone',[43000]='Single Turn-in Item',[43001]='Long Turn-in Item'})[id] end}
_G.GetItemInfo=function(id) return C_Item.GetItemName(id) end
_G.LibQuestieDB={
  RequireContract=function(v) return v==4 end,
  Support={Get=function(name)
    assert(name=='ZoneDB')
    return {private={areaIdToUiMapId='return {[12]=1429,[1637]=1454,[1519]=1453}'}}
  end},
}
_G.QuestDB={
  GetAllIds=function() return {821,822,700,701,901,902,1001,1002,1003,1004,1005} end,
  name=function(id)
    return ({[700]="Grey Forager",[701]="Grey Farmer",[901]="Repeatable Hunt",
      [902]="Repeatable Offering",[821]="Chen's Empty Keg",
      [822]="Long Turn-In",
      [1001]="A Donation of Wool",[1002]="A Donation of Wool",
      [1003]="A Donation of Wool",[1004]="A Donation of Wool",
      [1005]="A Donation of Wool"})[id]
  end,
  questLevel=function(id) return (id>=1001 and id<=1005) and 60 or ((id==700 or id==701) and 6 or 15) end,
  specialFlags=function(id) return (id==901 or id==902) and 1 or 0 end,
  objectives=function(id)
    local items={{4894,'Plainstrider Kidney',id==700 and 2 or 5}}
    if id==821 then items[#items+1]={43000,'Single Turn-in Item',1} end
    if id==822 then items[#items+1]={43001,'Long Turn-in Item',1} end
    return {nil,nil,items}
  end,
  requiredSourceItems=function() return nil end,
  finishedBy=function(id)
    if id>=1001 and id<=1005 then return {{3000+id-1000}} end
    if id==821 then return {{2001}} end
    if id==822 then return {{2002}} end
  end,
}
_G.ItemDB={relatedQuests=function(id)
  if id==4894 then return {821,700,701,901,902,1001,1002,1003,1004,1005} end
  if id==43000 then return {821} end
  if id==43001 then return {822} end
end}
_G.C_Map={GetAreaInfo=function(area) return ({[12]='Elwynn Forest',[17]='The Barrens',[1637]='Orgrimmar',[1519]='Stormwind City'})[area] end}
_G.NpcDB={
  name=function(id)
    if id==2001 then return 'Brewmaster Test' end
    if id==2002 then return 'Brewmaster Drohn' end
    if id>=3001 and id<=3005 then return 'Quartermaster '..(id-3000) end
  end,
  zoneID=function(id)
    if id==2001 then return 12 end
    if id==2002 then return 17 end
    return 1637
  end,
  spawns=function(id)
    if id==2001 then return {[12]={{42.5,67.2}}} end
    if id==2002 then return {[17]={{40.0,60.0}}} end
    if id>=3001 and id<=3005 then
      local n=id-3000
      return {[1637]={{10+15*n,10+15*n}}}
    end
  end,
}
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
  function f:GetName() return self.name end
  function f:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
  function f:Hide() self.shown=false end
  function f:IsShown() return self.shown end
  function f:SetChecked(v) self.checked=v end
  function f:GetChecked() return self.checked end
  function f:Disable() self.disabled=true end
  function f:Enable() self.disabled=false end
  function f:IsEnabled() return not self.disabled end
  function f:SetText(v) self.text=v end
  function f:SetSize(w,h) self.w=w; self.h=h end
  function f:SetHitRectInsets(...) self.hitInsets={...} end
  function f:SetPoint(...) self.points[#self.points+1]={...} end
  function f:ClearAllPoints() self.points={} end
  function f:GetCenter() return self.cx or 570, self.cy or 460 end
  function f:StartMoving() self.moving=true end
  function f:StopMovingOrSizing() self.moving=false end
  function f:SetFrameStrata() end
  function f:SetFrameLevel(level) self.level=level end
  function f:SetClampedToScreen() end
  function f:EnableMouse(enabled) self.mouseEnabled=enabled end
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
  if kind=='GameTooltip' then
    f.lines={}
    function f:SetOwner(owner,anchor) self.owner=owner; self.anchor=anchor end
    function f:AddLine(line)
      self.lines[#self.lines+1]=line
      local index=#self.lines
      _G[name..'TextLeft'..index]={
        GetText=function() return line end,
        GetTop=function() return 600-(index-1)*16 end,
        GetBottom=function() return 586-(index-1)*16 end,
      }
    end
    function f:ClearLines() self.lines={} end
    function f:NumLines() return #self.lines end
    function f:GetLeft() return 200 end
    function f:GetRight() return 520 end
    function f:GetEffectiveScale() return 1 end
    function f:IsShown() return self.shown end
  end
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
local shiftDown=false
_G.IsShiftKeyDown=function() return shiftDown end
_G.GetCursorPosition=function() return cursorX,cursorY end
local typedHook
local typedHooks={}
_G.Enum={TooltipDataType={Item=222,Spell=333}}
_G.TooltipDataProcessor={AddTooltipPostCall=function(kind,fn)
  typedHooks[kind]=fn
  if kind==222 then typedHook=fn end
end}
_G.GameTooltip={lines={},scripts={}}
function GameTooltip:GetLeft() return 200 end
function GameTooltip:GetTop() return 600 end
function GameTooltip:GetRight() return 520 end
function GameTooltip:GetEffectiveScale() return 1 end
function GameTooltip:IsShown() return self.shown end
function UIParent:GetWidth() return 1200 end
function UIParent:GetEffectiveScale() return 1 end
function GameTooltip:HookScript(event,fn) self.scripts[event]=fn end
local nativeHeightChanges=0
local function tooltipFontString(value,index)
  return {text=value,index=index,height=14,
    GetText=function(self)return self.text end,
    SetText=function(self,v)self.text=v end,
    GetHeight=function(self)return self.height end,
    SetHeight=function(self,v)nativeHeightChanges=nativeHeightChanges+1;self.height=v end,
    GetAlpha=function(self)return self.alpha or 1 end,
    SetAlpha=function(self,v)self.alpha=v end,
    GetTop=function(self)return 600-(self.index-1)*16 end,
    GetBottom=function(self)return 586-(self.index-1)*16 end,
  }
end
function GameTooltip:GetName()return "GameTooltip" end
function GameTooltip:NumLines()return #self.lines end
function GameTooltip:AddLine(line)
  self.lines[#self.lines+1]=line
  local index=#self.lines
  -- Reuse named FontStrings, as WoW Forever does when a tooltip changes
  -- from an ID-heavy item to a regular spell or Hearthstone.
  local left=_G["GameTooltipTextLeft"..index]
  local right=_G["GameTooltipTextRight"..index]
  if left then left:SetText(line) else
    _G["GameTooltipTextLeft"..index]=tooltipFontString(line,index)
  end
  if right then right:SetText("") else
    _G["GameTooltipTextRight"..index]=tooltipFontString("",index)
  end
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
local loadQIT = dofile('tests/load_addon.lua'); loadQIT()
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
assert(typedHook and typedHooks[333],
  'both item and spell data hooks must be installed on Forever')
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
assert(tocText:find('## LoadSavedVariablesFirst: 1',1,true),
  'SavedVariables must be available before QITF Lua initialization')

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
    if f.text=='v0.7-beta.11' then versionLabel=f; panelVersionCount=panelVersionCount+1 end
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
assert(#checks==6,'expected six settings switches')
assert(checks[1]:GetChecked(),'faction filter should be enabled by default')
assert(not checks[2]:GetChecked(),'IDs must be hidden by default')
assert(checks[3]:GetChecked() and checks[4]:GetChecked(),
  'levels and bag/bank counts should be enabled by default')
assert(checks[5]:GetChecked(),'turn-in name and zone should be on by default')
assert(not checks[6]:GetChecked(),'turn-in coordinates should be off by default')

-- Every setting explains its purpose when hovered, without technical jargon.
-- The expanded hit area lets players hover (and click) on the label as well.
local expectedHelps={
  {'Only show my faction quests','other faction'},
  {'Show IDs','item and spell IDs'},
  {'Show quest levels','quest'},
  {'Show bag / bank breakdown','bags and bank'},
  {'Show turn-in NPC and zone','quest-finisher'},
  {'Show turn-in coordinates','Off by default'},
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
  GameTooltip:Show() -- the WoW UI, not QITF, owns visibility
  return table.concat(GameTooltip.lines,'\n')
end
-- One relevant quest should show a quiet inline location.
local singleTurnIn=tooltip(43000)
assert(singleTurnIn:find('Turn in:',1,true),'single quest should show inline turn-in')
assert(singleTurnIn:find('Brewmaster Test',1,true)
  and singleTurnIn:find('Elwynn Forest',1,true),
  'single quest must show complete finisher name and zone')
assert(not singleTurnIn:find('(42.5, 67.2)',1,true),
  'turn-in coordinates should be off by default')
checks[6]:SetChecked(true); checks[6].scripts.OnClick(checks[6])
assert(tooltip(43000):find('(42.5, 67.2)',1,true),
  'turn-in coordinates should appear when enabled')
checks[6]:SetChecked(false); checks[6].scripts.OnClick(checks[6])
checks[5]:SetChecked(false); checks[5].scripts.OnClick(checks[5])
assert(not tooltip(43000):find('Turn in:',1,true),
  'turn-in details toggle must hide name and zone')
checks[5]:SetChecked(true); checks[5].scripts.OnClick(checks[5])


-- Long names must wrap at the NPC/zone boundary instead of ellipsizing
-- The Barrens; this does not depend on the source bag tooltip width.
local longTurnIn=tooltip(43001)
assert(longTurnIn:find('Brewmaster Drohn',1,true)
   and longTurnIn:find('The Barrens',1,true),
   'long turn-in location must include complete NPC and zone names')
assert(not longTurnIn:find('Brewmaster Drohn — The Barrens',1,true),
   'long NPC/zone line should break cleanly after the NPC')
local sawNpcLine, sawZoneLine=false,false
for _, line in ipairs(GameTooltip.lines) do
  if line:find('Brewmaster Drohn',1,true) then sawNpcLine=true end
  if line:find('The Barrens',1,true) then
    sawZoneLine=true
    assert(not line:find('Brewmaster Drohn',1,true),
      'The Barrens must be on a separate clean line')
  end
end
assert(sawNpcLine and sawZoneLine,'long turn-in wrapping lines missing')

-- Three or more quest associations: destinations live in a side bubble,
-- not stacked on the item tooltip. The five donation quests stay grouped.
local busy=tooltip(4894)
assert(not busy:find('Turn in:',1,true),
  'crowded item must not add inline turn-in lines')
assert(busy:find('(5 quests)',1,true),'five faction quests should stay collapsed')
assert(not busy:find('Closest:',1,true),
  'no installed navigation addon must mean no nearest turn-in hint')
local donationLine
for index, line in ipairs(GameTooltip.lines) do
  if line:find('A Donation of Wool',1,true) then donationLine=index; break end
end
assert(donationLine,'donation row missing from crowded tooltip')
cursorX,cursorY=300,593-(donationLine-1)*16
assert(type(GameTooltip.scripts.OnUpdate)=='function','turn-in hover updater not installed')
GameTooltip.scripts.OnUpdate(GameTooltip,0.2)
local bubble
for _,f in ipairs(frames) do
  if f.name=='QITTurnInHoverBubble' then bubble=f end
end
assert(bubble and bubble.shown,'hovering a crowded quest row must show a side bubble')
local bubbleText=table.concat(bubble.qitLines,' ')
for i=1,5 do
  assert(bubbleText:find('Quartermaster '..i,1,true),
    'collapsed faction row lost one of its turn-in locations')
end
cursorX,cursorY=100,500
GameTooltip.scripts.OnUpdate(GameTooltip,0.2)
assert(not bubble.shown,'side bubble must hide after leaving quest row')


-- A compatible navigation addon may add ONE closest suggestion using read-only
-- position and quest-finisher spawn data, not any waypoint side effects.
local hbd={
  GetPlayerWorldPosition=function() return 400,400,1 end,
  GetWorldCoordinatesFromZone=function(_,x,y,map)
    if map==1454 then return x*1000,y*1000,1 end
  end,
}
_G.LibStub=function(name,optional)
  if name=='HereBeDragons-2.0' then return hbd end
end
_G.TomTom={
  GetCurrentPlayerPosition=function() return 1454,0.4,0.4 end,
  AddWaypoint=function() error('QIT must never create a waypoint') end,
  SetCrazyArrow=function() error('QIT must never change navigation') end,
}
local withNavigation=tooltip(4894)
assert(withNavigation:find('Closest:',1,true),
  'TomTom with usable world coordinates should show a nearest hint')
assert(withNavigation:find('Quartermaster 2 — Orgrimmar',1,true),
  'nearest hint should choose the actually nearest known NPC and city')
assert(not withNavigation:find('Turn in:',1,true),
  'nearest hint must not expand the busy tooltip')
_G.TomTom=nil
assert(not tooltip(4894):find('Closest:',1,true),
  'removing the navigation provider should remove the nearest hint')
_G.LibStub=nil

-- Shift pins the original item information independently of the bag tooltip.
local pinController
for _, f in ipairs(frames) do
  if f.name == 'QITPinController' then pinController = f end
end
assert(pinController, 'independent pin controller must be installed')
-- Forever may return 1/nil from GetChecked. Test the real checkbox path
-- instead of only writing SavedVariables by hand.
checks[2].GetChecked=function(self) return self.checked and 1 or nil end
checks[2]:SetChecked(true);checks[2].scripts.OnClick(checks[2])
assert(QuestItemTrackerDB.settings.showIDs==true,
  'Forever checked value 1 must save Show IDs as true')
local beforePin=tooltip(4894)
assert(beforePin:find('Item ID: 4894',1,true)
    and beforePin:find('Quest ID: 821',1,true),
  'Show IDs on must render QITF identifiers')
-- The original tooltip was captured while IDs were ON. Switching them OFF
-- before Shift pinning must still remove the technical ID rows in the pin.
checks[2]:SetChecked(false);checks[2].scripts.OnClick(checks[2])
assert(QuestItemTrackerDB.settings.showIDs==false,
  'Forever unchecked value nil must save Show IDs as false')
-- Simulate a custom bag UI whose native tooltip stops receiving OnUpdate.
local oldTooltipUpdate=GameTooltip.scripts.OnUpdate
GameTooltip.scripts.OnUpdate=nil
shiftDown=true
pinController.scripts.OnUpdate(pinController,0.15)
local pinned
for _,f in ipairs(frames) do
  if f.name=='QITPinnedItemInfo' then pinned=f end
end
assert(pinned and pinned:IsShown(),'Shift must create and show an independent info panel')
assert(pinned.mouseEnabled==true,
  'pinned panel must accept mouse for quest-row hover')
assert(bubble.mouseEnabled==false,
  'destination bubble must not steal hover from pinned quest rows')
local pinPoint=pinned.points[#pinned.points]
assert(pinPoint and pinPoint[2]==UIParent
    and (pinPoint[1]=='TOPLEFT' or pinPoint[1]=='TOPRIGHT'),
    'pin must anchor independently alongside the source tooltip')
assert(pinPoint[4]~=200,
    'pin must not overlap the original tooltip')
assert(pinned.kind=='Frame', 'pin must be a plain independent Frame, not GameTooltip')
assert(pinned.qitLines[1]:find('Pinned',1,true)
   and not pinned.qitLines[1]:find('SHIFT PINNED',1,true),
   'pin should use the concise Pinned label')
local trimCount=0
for _, f in ipairs(frames) do
  if f.kind=='Texture' and f.parent==pinned and f.color
    and f.color[1]>0.45 and f.color[1]>f.color[2]
    and f.color[2]>f.color[3] then
      trimCount=trimCount+1
  end
end
assert(trimCount==4,'pinned panel should have four aged-gold border edges')
local snapshot=table.concat(pinned.qitLines,'\n')
assert(not snapshot:find('Item ID:',1,true)
   and not snapshot:find('Quest ID:',1,true),
   'Show IDs off must strip QITF item/quest IDs even from older captures')
assert(snapshot:find('A Donation of Wool',1,true)
  and snapshot:find('(5 quests)',1,true),
  'pinned panel must preserve the original grouped quest information')
-- Simulate the normal bag tooltip closing and being reused for another item.
GameTooltip:Hide()
if GameTooltip.scripts.OnHide then GameTooltip.scripts.OnHide(GameTooltip) end
tooltip(43000)
assert(pinned:IsShown() and table.concat(pinned.qitLines,'\n')==snapshot,
  'moving to another bag item must not replace the Shift-pinned item')
local groupedHit
for _, f in ipairs(frames) do
  if f.parent==pinned and f.scripts.OnEnter then
    assert(f.mouseEnabled==true,'pinned row must accept mouse input')
    f.scripts.OnEnter(f)
    local detail=bubble.qitLines and table.concat(bubble.qitLines,' ') or ''
    if bubble.shown and detail:find('Quartermaster 1',1,true)
      and detail:find('Quartermaster 5',1,true) then
      groupedHit=f
      break
    end
    f.scripts.OnLeave(f)
  end
end
assert(groupedHit,'grouped donation quest must have a usable hit target and all finishers')
groupedHit.scripts.OnLeave(groupedHit)
assert(not bubble.shown,'leaving pinned quest row must close bubble')
shiftDown=false
pinController.scripts.OnUpdate(pinController,0.2)
assert(not pinned:IsShown() and not bubble.shown,
  'releasing Shift must close pinned panel and its side bubble')
-- A player enters the diagnostic command only AFTER releasing Shift.
local pinOutput
local oldPrint=DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage=function(_,line) pinOutput=line end
SlashCmdList.QUESTITEMTRACKER('pin')
DEFAULT_CHAT_FRAME.AddMessage=oldPrint
assert(pinOutput and pinOutput:find('successes=1',1,true)
  and pinOutput:find('released=Shift released',1,true)
  and pinOutput:find('last=Pinned item 4894',1,true),
  '/qit pin must preserve the last pin result after Shift is released')
cursorX,cursorY=100,500
-- Shift already held BEFORE item hover must pin on the item callback too.
-- When Show IDs is enabled, the pinned view must include those same IDs.
checks[2]:SetChecked(true);checks[2].scripts.OnClick(checks[2])
shiftDown=true
tooltip(4894)
assert(pinned:IsShown(),'holding Shift before hover must pin immediately')
local pinWithIDs=table.concat(pinned.qitLines,'\n')
assert(pinWithIDs:find('Item ID: 4894',1,true)
   and pinWithIDs:find('Quest ID: 821',1,true),
   'Show IDs on must show item and quest IDs inside the pinned panel')
shiftDown=false
pinController.scripts.OnUpdate(pinController,0.2)
assert(not pinned:IsShown(),'release after immediate pin must work')
checks[2]:SetChecked(false);checks[2].scripts.OnClick(checks[2])
GameTooltip.scripts.OnUpdate=oldTooltipUpdate

-- The active UI owns any technical-ID rows that it adds. QITF's
-- standard hooks must NEVER mutate its named tooltip FontStrings.
-- Verify text, height and reuse without requiring an external provider.
local function withExternalIDs(itemID)
  GameTooltip:ClearLines()
  if GameTooltip.scripts.OnTooltipCleared then
    GameTooltip.scripts.OnTooltipCleared(GameTooltip)
  end
  GameTooltip:AddDoubleLine('ItemID', tostring(itemID))
  GameTooltip:AddDoubleLine('IconID', '132919')
  typedHook(GameTooltip,{id=itemID,type=222})
  GameTooltip:Show()
  return _G.GameTooltipTextLeft1,_G.GameTooltipTextRight1,
         _G.GameTooltipTextLeft2,_G.GameTooltipTextRight2
end
local beforeNativeHeight=nativeHeightChanges
local a,b,c,d=withExternalIDs(4894)
assert(a:GetText()=='ItemID' and b:GetText()=='4894'
  and c:GetText()=='IconID' and d:GetText()=='132919',
  'QITF must not edit identifier rows owned by another UI')
assert(a:GetHeight()==14 and b:GetHeight()==14
  and c:GetHeight()==14 and d:GetHeight()==14,
  'external ID fontstrings must retain native height')
GameTooltip:Show()
GameTooltip:AddDoubleLine('SpellID','20484')
local index=GameTooltip:NumLines()
assert(_G['GameTooltipTextLeft'..index]:GetText()=='SpellID'
  and _G['GameTooltipTextRight'..index]:GetText()=='20484',
  'QITF must not rewrite spell/action tooltip IDs')
-- Recycle the very same named fontstrings for ordinary prose.
GameTooltip:ClearLines()
if GameTooltip.scripts.OnTooltipCleared then
  GameTooltip.scripts.OnTooltipCleared(GameTooltip)
end
GameTooltip:AddLine('Hearthstone')
GameTooltip:AddLine('Use: Returns you to The Crossroads.')
GameTooltip:AddDoubleLine('ItemID','6948')
typedHook(GameTooltip,{id=6948,type=222})
GameTooltip:Show()
assert(_G.GameTooltipTextLeft2:GetText()=='Use: Returns you to The Crossroads.'
  and _G.GameTooltipTextLeft2:GetHeight()==14,
  'reused Hearthstone description must remain untouched and full-height')
assert(_G.GameTooltipTextLeft3:GetText()=='ItemID'
  and _G.GameTooltipTextRight3:GetText()=='6948',
  'QITF must not erase external item identifiers')
assert(nativeHeightChanges==beforeNativeHeight,
  'QITF must not call SetHeight on shared tooltip FontStrings')

checks[2]:SetChecked(true);checks[2].scripts.OnClick(checks[2])
a,b,c,d=withExternalIDs(4894)
assert(a:GetText()=='ItemID' and b:GetText()=='4894'
  and c:GetText()=='IconID' and d:GetText()=='132919',
  'showing QITF IDs must not alter external identifiers')
assert(a:GetHeight()==14 and c:GetHeight()==14,
  'showing QITF IDs must not alter native font height')
local ownIDs=table.concat(GameTooltip.lines,'\n')
assert(ownIDs:find('Item ID: 4894',1,true),'QIT item ID did not follow unified option')
assert(ownIDs:find('Quest ID: 821',1,true),'quest ID did not follow unified option')
checks[2]:SetChecked(false);checks[2].scripts.OnClick(checks[2])
-- The UI-provider contract: an exposed ID-handling capability gets the
-- entire ID presentation, QITF's option is disabled, and no native tooltip
-- line is edited. Removing that UI restores the player's saved QITF choice.
_G.EllesmereUI = {SpellIDOn=function() return true end}
panel:Hide();panel:Show()
assert(checks[2]:IsEnabled()==false and not checks[2]:GetChecked(),
  'external ID provider must disable and uncheck QITF Show IDs')
local handledLabel
for _, f in ipairs(frames) do
  if f.kind=='FontString' and f.parent==panel
     and f.text and f.text:find('Handled by UI',1,true) then
    handledLabel=f;break
  end
end
assert(handledLabel,'external ID provider must be indicated as Handled by UI')
checks[2]:SetChecked(true)
checks[2].scripts.OnClick(checks[2])
assert(QuestItemTrackerDB.settings.showIDs==false,
  'a disabled Show IDs checkbox must not change saved preferences')
local externalBefore=nativeHeightChanges
withExternalIDs(4894)
local qitExternal=table.concat(GameTooltip.lines,'\n')
assert(not qitExternal:find('Item ID: 4894',1,true)
  and not qitExternal:find('Quest ID: 821',1,true),
  'QITF must not add duplicate IDs while a UI provider owns ID display')
assert(nativeHeightChanges==externalBefore
  and _G.GameTooltipTextLeft1:GetText()=='ItemID',
  'an external ID provider must retain its untouched tooltip rows')
GameTooltip:ClearLines()
GameTooltip:AddLine('Arcane Shot')
typedHooks[333](GameTooltip,{id=3044,type=333})
assert(table.concat(GameTooltip.lines,'\n')=='Arcane Shot',
  'a UI provider must disable QITF-generated stock spell identifiers')
_G.EllesmereUI=nil
panel:Hide();panel:Show()
assert(checks[2]:IsEnabled()==true and not checks[2]:GetChecked(),
  'stock UI must restore working QITF ID switch and saved state')
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
assert(clean:find('|cffc88b73Quest Item Tracker Forever|r',1,true),
  'QITF header must use weathered copper, not crafting-reagent blue')
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
assert(clean:find('|cff8c8c8cGrey Forager',1,true),
  'low-level quest name did not use WoW native difficulty color')
assert(clean:find('|cffff8000Chen',1,true),
  'normal quest name did not use WoW native difficulty color')
assert(clean:find('Have 5 / Need 5',1,true),'Have/Need was lost')
assert(clean:find('(Level 15)',1,true),'quest level should appear by default')
assert(not clean:find('Quest ID:',1,true) and not clean:find('Item ID:',1,true),'IDs visible by default')
assert(clean:find('Bags: 3 | Bank: 2',1,true),'default bank counts missing')
assert(tooltip(6948)=='','ordinary item must not have IDs when off')
GameTooltip:ClearLines()
GameTooltip:AddLine('Arcane Shot')
typedHooks[333](GameTooltip,{id=3044,type=333})
assert(table.concat(GameTooltip.lines,'\n')=='Arcane Shot',
  'Show IDs off must not add a spell ID')
assert(not tooltip(4894):find('FUTURE QUEST',1,true),
  'redundant future quest labels should remain hidden')
checks[2]:SetChecked(true);checks[2].scripts.OnClick(checks[2])
local detailed=tooltip(4894)
assert(detailed:find('Quest ID: 821',1,true),'quest ID setting failed')
assert(detailed:find('Quest IDs: 1001, 1002, 1003, 1004, 1005',1,true),
  'collapsed quest IDs must remain accessible when enabled')
assert(detailed:find('Item ID: 4894',1,true),'item ID setting failed')
local ordinaryID=tooltip(6948)
assert(ordinaryID=='Item ID: 6948',
  'Show IDs on must add an item ID to ordinary items without quest uses')
typedHook(GameTooltip,{id=6948,type=222})
assert(#GameTooltip.lines==1,
  'multiple item callbacks must not duplicate the native item ID row')
GameTooltip:ClearLines()
GameTooltip:AddLine('Arcane Shot')
typedHooks[333](GameTooltip,{id=3044,type=333})
typedHooks[333](GameTooltip,{id=3044,type=333})
assert(table.concat(GameTooltip.lines,'\n')=='Arcane Shot\nSpell ID: 3044',
  'Show IDs on must add exactly one native spell ID without altering spell text')
-- A protected/forbidden native tooltip may reject AddLine. The item and
-- spell typed callbacks must contain that failure instead of throwing into WoW.
local originalAddLine=GameTooltip.AddLine
local originalChat=DEFAULT_CHAT_FRAME.AddMessage
local tooltipErrors={}
DEFAULT_CHAT_FRAME.AddMessage=function(_,message)
  tooltipErrors[#tooltipErrors+1]=message
end
GameTooltip:ClearLines()
GameTooltip.AddLine=function() error('mock protected tooltip line') end
local itemSafe=pcall(typedHook,GameTooltip,{id=6948,type=222})
local spellSafe=pcall(typedHooks[333],GameTooltip,{id=3044,type=333})
GameTooltip.AddLine=originalAddLine
DEFAULT_CHAT_FRAME.AddMessage=originalChat
assert(itemSafe and spellSafe,'native ID callback errors must never escape into the UI')
assert(#tooltipErrors==1 and tooltipErrors[1]:find('Tooltip error',1,true),
  'native tooltip errors should be reported only once')
for _,i in ipairs({3,4}) do
 checks[i]:SetChecked(false);checks[i].scripts.OnClick(checks[i])
end
local compact=tooltip(4894)
assert(not compact:find('(Level 15)',1,true),'level-off setting failed')
assert(not compact:find('Bags:',1,true),'breakdown-off setting failed')
assert(compact:find('Have 5 / Need 5',1,true),'essential Have/Need changed')
assert(QuestItemTrackerDB.settings.showIDs==true,'unified setting not persisted')
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
assert(tooltip(6948)=='',
  'reset must hide ordinary stock item identifiers too')
GameTooltip:ClearLines()
GameTooltip:AddLine('Arcane Shot')
typedHooks[333](GameTooltip,{id=3044,type=333})
assert(table.concat(GameTooltip.lines,'\n')=='Arcane Shot',
  'reset must hide stock spell identifiers too')
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
local diskDatabase=cloneSavedVariables(oldDatabase)
assert(diskDatabase~=oldDatabase,
  'reload test must not reuse the original in-memory database table')
assert(diskDatabase.settings.minimapPosition
  and diskDatabase.settings.minimapPosition.x<0
  and diskDatabase.settings.minimapPosition.y<0,
  'serialized SavedVariables lost the last dragged icon location')

-- Reproduce the real bug: an addon Lua file executes before the client's
-- account-wide SavedVariables table gets injected. The original code kept
-- the throwaway DB local forever, causing all future writes to disappear.
_G.QuestItemTrackerDB=nil
dofile('tests/load_addon.lua')()
local throwawayDatabase=QuestItemTrackerDB
assert(type(throwawayDatabase)=='table' and throwawayDatabase~=diskDatabase,
  'delayed SavedVariables scenario must create a distinct temporary table')
_G.QuestItemTrackerDB=diskDatabase
local reloadMain,reloadButton
for i=beforeReload+1,#frames do
  local f=frames[i]
  if f.events.PLAYER_LOGIN then reloadMain=f end
end
assert(reloadMain,'addon reload did not create login handler')
reloadMain.scripts.OnEvent(reloadMain,'ADDON_LOADED','QuestItemTracker')
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

-- A new drag must write to the *loaded global* SavedVariables database,
-- not the throwaway table that was alive before ADDON_LOADED.
cursorX,cursorY=610,530
reloadButton.scripts.OnDragStart(reloadButton)
reloadButton.scripts.OnUpdate(reloadButton)
reloadButton.scripts.OnDragStop(reloadButton)
assert(QuestItemTrackerDB==diskDatabase and
  QuestItemTrackerDB.settings.minimapPosition.x>0 and
  QuestItemTrackerDB.settings.minimapPosition.y>0,
  'drag after reload must update the persisted global SavedVariables table')
assert(throwawayDatabase.settings.minimapPosition==nil,
  'new drag accidentally wrote to the pre-load temporary DB')
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