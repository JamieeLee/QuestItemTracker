-- QITF-owned information panels. These are ordinary Frames, deliberately NOT
-- GameTooltip children; UI skins and item-tooltip refreshes must not own them.
local _, NS = ...
local S = assert(NS.state)
local api = assert(NS.api)
local SafeCall = assert(api.SafeCall)

local function Solid(texture, r, g, b, a)
    if type(texture.SetColorTexture) == "function" then
        texture:SetColorTexture(r, g, b, a)
    elseif type(texture.SetTexture) == "function" then
        texture:SetTexture(r, g, b, a)
    end
end

local function NewPanel(name, width, interactive)
    if type(CreateFrame) ~= "function" or not UIParent then return nil end
    local frame = CreateFrame("Frame", name, UIParent)
    if not frame or type(frame.CreateFontString) ~= "function" then return nil end
    width = width or 320
    frame:SetSize(width, 35)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(500)
    frame:EnableMouse(interactive == true)
    if type(frame.SetClampedToScreen) == "function" then
        frame:SetClampedToScreen(true)
    end

    local backdropOk = false
    if type(frame.SetBackdrop) == "function" then
        backdropOk = pcall(frame.SetBackdrop, frame, {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end
    if backdropOk then
        if type(frame.SetBackdropColor) == "function" then
            frame:SetBackdropColor(0.04, 0.04, 0.04, 0.97)
        end
        if type(frame.SetBackdropBorderColor) == "function" then
            frame:SetBackdropBorderColor(0.65, 0.55, 0.38, 0.92)
        end
    else
        local texture = frame:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints(frame)
        Solid(texture, 0.04, 0.04, 0.04, 0.96)
    end

    local panel = { frame = frame, width = width, labels = {}, hitFrames = {} }
    function panel:Render(lines, interactiveRows, onEnter, onLeave)
        local y = 12
        frame.qitLines = {}
        for i, line in ipairs(lines) do
            local label = self.labels[i]
            if not label then
                label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                self.labels[i] = label
            end
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -y)
            label:SetWidth(width - 24)
            if type(label.SetJustifyH) == "function" then label:SetJustifyH("LEFT") end
            if type(label.SetJustifyV) == "function" then label:SetJustifyV("TOP") end
            if type(label.SetWordWrap) == "function" then label:SetWordWrap(true) end
            if type(label.SetTextColor) == "function" then
                label:SetTextColor(line.r or 0.95, line.g or 0.95, line.b or 0.95, 1)
            end
            label:SetText(line.text or "")
            label:Show()
            frame.qitLines[i] = line.text or ""
            local height = tonumber(SafeCall(label.GetStringHeight, label)) or 15
            if height < 15 then height = 15 end
            -- For custom panel text this row's hit box follows the measured
            -- font height rather than guessing GameTooltipTextLeftN indices.
            local row = interactiveRows and interactiveRows[i]
            local hit = self.hitFrames[i]
            if row then
                if not hit then
                    hit = CreateFrame("Frame", nil, frame)
                    hit:EnableMouse(true)
                    self.hitFrames[i] = hit
                end
                hit:ClearAllPoints()
                hit:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -y)
                hit:SetSize(width - 24, height)
                hit:SetScript("OnEnter", function() if onEnter then onEnter(row) end end)
                hit:SetScript("OnLeave", function() if onLeave then onLeave(row) end end)
                hit:Show()
            elseif hit then
                hit:Hide()
            end
            y = y + height + 2
        end
        for i = #lines + 1, #self.labels do
            self.labels[i]:Hide()
            if self.hitFrames[i] then self.hitFrames[i]:Hide() end
        end
        frame:SetSize(width, y + 11)
    end
    frame:Hide()
    return panel
end

api.NewInfoPanel = NewPanel
