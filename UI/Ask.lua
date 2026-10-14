-- Blackthornes Butler -- UI/Ask.lua
-- The Ask Butler window: a box to type a question in, a few to click, and
-- the answer under them (Logic/Ask.lua works it out).
--
-- `/bbutler ask` opens it (with a question after it, asks it too), as do
-- the Butler window's Ask button and a Settings button. Shift-click an item
-- while the box has the keyboard and its link goes in. It wears the plate
-- and close gem, its answer lines are dark glass, and it has the house size
-- grip (askScale, account wide; its place in askPoint, askRelPoint, askX
-- and askY). Never rename them.

local _, ns = ...
local L = ns.L

local AskUI = ns.NewModule("AskUI")

local Theme = ns.Theme
local Widgets = ns.Widgets

local WIDTH, HEIGHT = 420, 380
local PADDING = 16
local LINES = 9
local SCALE_MIN, SCALE_MAX = 0.6, 1.5
local GRIP_SIZE = 20

local function ClampScale(value)
    value = tonumber(value)
    if not value or value ~= value then return 1 end
    return math.floor(math.max(SCALE_MIN, math.min(SCALE_MAX, value)) * 100 + 0.5) / 100
end
AskUI.ClampScale = ClampScale

function AskUI:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "BlackthornesButlerAsk", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetScale(ClampScale(ns.db and ns.db.askScale or 1))
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        AskUI:SavePosition()
    end)
    Theme.Fill(frame, "window")

    if ns.Titanforged then
        self.trim = ns.Titanforged:Dress(frame, {
            title = L["Ask Butler"],
            close = function() AskUI:Hide() end,
        })
        local left, right, top, bottom = ns.Titanforged.Reach(self.trim)
        if frame.SetClampRectInsets then frame:SetClampRectInsets(-left, right, top, -bottom) end
    else
        Theme.Border(frame, "borderLit")
    end

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "BlackthornesButlerAsk")
    end
    self.frame = frame

    local box = Widgets.CreateSearchBox(frame, L["Ask me something, then press Enter"], nil, function(text)
        AskUI:Ask(text)
    end)
    box:SetPoint("TOPLEFT", PADDING, -30)
    box:SetPoint("TOPRIGHT", -PADDING, -30)
    if box.editBox and box.editBox.SetMaxLetters then box.editBox:SetMaxLetters(200) end
    self.box = box

    -- Questions to click, two a row: each fills the box and asks it.
    self.examples = {}
    local half = (WIDTH - 2 * PADDING - 6) / 2
    for index, text in ipairs(ns.Ask.EXAMPLES) do
        local button = Widgets.CreateButton(frame, text, function()
            AskUI.box:SetText(text)
            AskUI:Ask(text)
        end, { width = half, height = 20 })
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        button:SetPoint("TOPLEFT", PADDING + column * (half + 6), -62 - row * 24)
        self.examples[index] = button
    end

    -- The answer, in a well: its title in gold, then a dark glass line for
    -- each thing it says.
    local well = Theme.CreatePanel(frame, "panel", "border")
    well:SetPoint("TOPLEFT", PADDING, -118)
    well:SetPoint("BOTTOMRIGHT", -PADDING, 46)
    if Theme.Recess then Theme.Recess(well) end
    self.well = well

    local title = Theme.CreateLabel(well, "normal", "gilt", "LEFT")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetPoint("RIGHT", well, "RIGHT", -10, 0)
    title:SetWordWrap(true)
    self.title = title

    self.lines = {}
    for index = 1, LINES do
        local line = CreateFrame("Frame", nil, well)
        line.background = Theme.Fill(line, index % 2 == 1 and "glass" or "glassAlt")
        local rule = line:CreateTexture(nil, "BORDER")
        rule:SetPoint("BOTTOMLEFT")
        rule:SetPoint("BOTTOMRIGHT")
        rule:SetHeight(1)
        rule:SetColorTexture(Theme.Unpack("border", 0.6))
        line.label = Theme.CreateLabel(line, "small", "text", "LEFT")
        line.label:SetPoint("LEFT", 8, 0)
        line.label:SetPoint("RIGHT", -8, 0)
        line.label:SetWordWrap(true)
        line:Hide()
        self.lines[index] = line
    end

    local action = Widgets.CreateButton(frame, "", function()
        if AskUI.answer then ns.Ask:Run(AskUI.answer.action) end
    end, { width = 110, height = 24, primary = true })
    action:SetPoint("BOTTOMRIGHT", -PADDING, 14)
    action:Hide()
    self.action = action

    local hint = Theme.CreateLabel(frame, "tiny", "dim", "LEFT")
    hint:SetPoint("BOTTOMLEFT", PADDING, 20)
    hint:SetPoint("RIGHT", action, "LEFT", -8, 0)
    hint:SetText(L["Shift-click an item to put it in the question."])

    self:BuildSizeGrip()
    self:HookLinks()
    self:RestorePosition()
    frame:Hide()
    return frame
end

--- Shift-click puts an item's link in the box while it has the keyboard.
function AskUI:HookLinks()
    if type(hooksecurefunc) ~= "function" then return end
    local function Take(link)
        local edit = AskUI.box and AskUI.box.editBox
        if not (edit and AskUI.frame:IsShown() and type(link) == "string") then return end
        local ok, focused = pcall(edit.HasFocus, edit)
        if ok and focused then pcall(edit.Insert, edit, link) end
    end
    if type(_G.ChatEdit_InsertLink) == "function" then
        pcall(hooksecurefunc, "ChatEdit_InsertLink", Take)
    end
    local util = rawget(_G, "ChatFrameUtil")
    if type(util) == "table" and type(util.InsertLink) == "function" then
        pcall(hooksecurefunc, util, "InsertLink", Take)
    end
end

--- Ask a question and show the answer.
function AskUI:Ask(text)
    self:Build()
    self.asked = text
    self:Draw(ns.Ask:Answer(text))
    -- Butler reads the bags only while its window or a vendor is up: read
    -- them once and answer again with what they hold.
    if ns.Bags and ns.Bags.stale and not ns.Bags.scanning then
        ns.Bags:Scan(function()
            if AskUI.asked == text and AskUI:IsShown() then AskUI:Draw(ns.Ask:Answer(text)) end
        end)
    end
end

--- Lay out an answer: { title, lines, action }.
function AskUI:Draw(answer)
    self.answer = answer
    self.title:SetText(answer.title or "")
    local y = -8 - math.max(16, self.title:GetStringHeight() or 16) - 8
    local width = WIDTH - 2 * PADDING - 2
    for index, line in ipairs(self.lines) do
        local text = answer.lines[index]
        if text then
            line.label:SetWidth(width - 16)
            line.label:SetText(text)
            local height = math.max(22, (line.label:GetStringHeight() or 12) + 10)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", self.well, "TOPLEFT", 1, y)
            line:SetPoint("TOPRIGHT", self.well, "TOPRIGHT", -1, y)
            line:SetHeight(height)
            line:Show()
            y = y - height
        else
            line:Hide()
        end
    end
    local action = answer.action
    if action and action.label then
        self.action:SetText(action.label)
        self.action:Show()
    else
        self.action:Hide()
    end
end

--------------------------------------------------------------------------------
-- Size and place
--------------------------------------------------------------------------------

function AskUI:SetScale(value)
    local scale = ClampScale(value)
    if ns.db then ns.db.askScale = scale end
    if self.frame then self.frame:SetScale(scale) end
end

--- The house grip below the bottom right corner: drag for size, right-click
--- for the normal size. Only the scale changes; nothing is laid out again.
function AskUI:BuildSizeGrip()
    local frame = self.frame
    local grip = Theme.CreatePanel(frame, "panel", "borderLit")
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -6, -10)
    grip:SetFrameLevel((frame:GetFrameLevel() or 0) + 20)
    grip:EnableMouse(true)
    for row = 0, 2 do
        for column = 2 - row, 2 do
            local dot = grip:CreateTexture(nil, "ARTWORK")
            dot:SetSize(3, 3)
            dot:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -3 - (2 - column) * 5, 3 + (2 - row) * 5)
            dot:SetColorTexture(Theme.Unpack("accent"))
        end
    end
    self.sizeGrip = grip

    local function Track(self)
        local cx, cy = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        if not (cx and cy and type(uiScale) == "number" and uiScale > 0) then return end
        cx, cy = cx / uiScale, cy / uiScale
        local scale = ClampScale(((cx - self.left) / WIDTH + (self.top - cy) / HEIGHT) / 2)
        if math.abs(scale - (frame:GetScale() or 1)) < 0.005 then return end
        frame:SetScale(scale)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.left / scale, self.top / scale)
    end
    local function Stop(self)
        if not self.sizing then return end
        self.sizing = false
        self:SetScript("OnUpdate", nil)
        if ns.db then ns.db.askScale = ClampScale(frame:GetScale()) end
        AskUI:SavePosition()
    end
    grip:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            AskUI:SetScale(1)
            return
        end
        local scale = frame:GetScale() or 1
        local left, top = frame:GetLeft(), frame:GetTop()
        if not (type(left) == "number" and type(top) == "number") then return end
        self.left, self.top = left * scale, top * scale
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        self.sizing = true
        self:SetScript("OnUpdate", Track)
    end)
    grip:SetScript("OnMouseUp", Stop)
    grip:SetScript("OnHide", Stop)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(("%d%%"):format(math.floor((frame:GetScale() or 1) * 100 + 0.5)), Theme.Unpack("accentHi"))
        GameTooltip:AddLine(L["Drag to make the window bigger or smaller."], 1, 1, 1, true)
        GameTooltip:AddLine(L["Right-click: back to the normal size."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function AskUI:SavePosition()
    if not (ns.db and self.frame) then return end
    local point, _, relativePoint, x, y = self.frame:GetPoint()
    ns.db.askPoint, ns.db.askRelPoint, ns.db.askX, ns.db.askY = point, relativePoint, x, y
end

function AskUI:RestorePosition()
    if not self.frame then return end
    local db = ns.db or {}
    self.frame:ClearAllPoints()
    self.frame:SetPoint(db.askPoint or "CENTER", UIParent, db.askRelPoint or "CENTER", db.askX or 0, db.askY or 80)
end

--------------------------------------------------------------------------------
-- Showing
--------------------------------------------------------------------------------

function AskUI:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

--- Bring the window up, with the help answer the first time, the box
--- ready to type in.
function AskUI:Show()
    self:Build()
    if not self.answer then self:Draw(ns.Ask:Help()) end
    self.frame:Show()
    self.box:SetFocus()
end

function AskUI:Hide()
    if self.frame then self.frame:Hide() end
end

function AskUI:Toggle()
    if self:IsShown() then self:Hide() else self:Show() end
end

ns.RegisterCommand("ask", L["ask Butler a question, such as /bbutler ask what is Linen Cloth worth"], function(rest)
    if rest and rest:match("%S") then
        AskUI:Show()
        AskUI.box:SetText(rest)
        AskUI:Ask(rest)
    else
        AskUI:Toggle()
    end
end)
