-- Blackthornes Butler -- UI/GoldGoals.lua
-- The purse at the bottom of the Butler window (the owner said build it,
-- 2026-10-13, "the purse section goes at the bottom of Butler"): GOLD
-- GOALS with the purse, a segment per goal lit as it is met, and a row per
-- goal with a glowing bar of the purse against its price
-- (Logic/GoldGoals.lua). In All characters the same place lists every
-- character with their segments.
--
-- Dark glass rows as every list in the house. The bar is green and says
-- Ready once it can be paid, gold while saving and dim while the goal is
-- levels away. A click on the heading folds it to the heading and the
-- segments (per character, `folded.goldGoals`).

local _, ns = ...
local L = ns.L

local GoalsUI = ns.NewModule("GoldGoalsUI")

local Theme = ns.Theme
local Items = ns.Items

local HEAD = 22
local SEGMENTS = 12
local GOAL_ROW = 40
local CHARACTER_ROW = 30
-- Characters shown in All characters before "and N more".
GoalsUI.MOST_CHARACTERS = 4

local COLORS = {
    ready = "good",
    saving = "accentHi",
    far = "metal",
}

local function Money(copper)
    return Items.FormatMoney(copper or 0)
end

--------------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------------

--- A bar: a dark track, a fill that glows in its colour.
local function CreateBar(parent, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(height)
    bar.track = Theme.Fill(bar, "well")
    Theme.Border(bar, "border", 0.8)
    local fill = CreateFrame("Frame", nil, bar)
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", 1, 1)
    fill:SetWidth(1)
    fill.texture = fill:CreateTexture(nil, "ARTWORK")
    fill.texture:SetAllPoints(fill)
    Theme.Halo(fill, 4, 0, "accentHi")
    bar.fill = fill
    bar:SetScript("OnSizeChanged", function(self) GoalsUI.SetBar(self, self.p, self.state) end)
    return bar
end

--- Fill a bar to `p` (0 to 1) in the state's colour.
function GoalsUI.SetBar(bar, p, state)
    bar.p, bar.state = p or 0, state or "saving"
    local width = (tonumber(bar:GetWidth()) or 0) - 2
    local fill = bar.fill
    if bar.p <= 0 or width <= 0 then
        fill:Hide()
        return
    end
    fill:Show()
    fill:SetWidth(math.max(1, width * math.min(1, bar.p)))
    local key = COLORS[bar.state] or "accentHi"
    -- The fill brightens toward its end; a goal levels away stays dim.
    Theme.SetGradientAlpha(fill.texture, "HORIZONTAL", key, bar.state == "far" and 0.35 or 0.55,
        bar.state == "far" and 0.55 or 1)
    Theme.SetHalo(fill, bar.state == "far" and 0 or 0.45, key)
end

--- A row of segments, one per goal.
local function CreateSegments(parent, height)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(height)
    holder.parts = {}
    return holder
end

function GoalsUI.SetSegments(holder, goals)
    local count = math.max(1, #goals)
    local gap = 4
    local width = tonumber(holder:GetWidth()) or 0
    local each = (width - gap * (count - 1)) / count
    for index = 1, math.max(count, #holder.parts) do
        local part = holder.parts[index]
        if index <= count then
            if not part then
                part = CreateFrame("Frame", nil, holder)
                part.texture = Theme.Fill(part, "glassAlt")
                Theme.Halo(part, 3, 0, "accentHi")
                holder.parts[index] = part
            end
            part:ClearAllPoints()
            part:SetPoint("TOPLEFT", (each + gap) * (index - 1), 0)
            part:SetSize(math.max(1, each), tonumber(holder:GetHeight()) or 6)
            local goal = goals[index]
            local state = goal and goal.state
            if state == "ready" then
                part.texture:SetColorTexture(Theme.Unpack("good"))
                Theme.SetHalo(part, 0.4, "good")
            elseif state == "saving" and (goal.have or 0) > 0 then
                part.texture:SetColorTexture(Theme.Unpack("accentHi"))
                Theme.SetHalo(part, 0.35, "accentHi")
            else
                part.texture:SetColorTexture(Theme.Unpack("glassAlt"))
                Theme.SetHalo(part, 0, "accentHi")
            end
            part:Show()
        elseif part then
            part:Hide()
        end
    end
    holder.goals = goals
end

--- A dark glass row, `index` deciding its band.
local function CreateRow(parent, height)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(height)
    row.stripe = Theme.Fill(row, "glass")
    row.line = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.line:SetPoint("BOTTOMLEFT")
    row.line:SetPoint("BOTTOMRIGHT")
    row.line:SetHeight(1)
    row.line:SetColorTexture(Theme.Unpack("border", 0.6))
    row.hover = Theme.Fill(row, "glassHover", nil, "BORDER")
    row.hover:Hide()
    row.edge = row:CreateTexture(nil, "ARTWORK")
    row.edge:SetPoint("TOPLEFT")
    row.edge:SetPoint("BOTTOMLEFT")
    row.edge:SetWidth(2)
    row.edge:SetColorTexture(Theme.Unpack("accentHi"))
    row.edge:Hide()
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        self.edge:Show()
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GoalsUI:Enter(self)
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        self.edge:SetShown(self.active == true)
        if GameTooltip then GameTooltip:Hide() end
    end)
    return row
end

local function Band(row, index)
    row.stripe:SetColorTexture(Theme.Unpack(index % 2 == 0 and "glassAlt" or "glass"))
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

function GoalsUI:Build(window)
    if self.panel then return self.panel end
    local panel = Theme.CreatePanel(window, "panel", "border")
    if Theme.Recess then Theme.Recess(panel) end
    self.panel = panel

    local head = CreateFrame("Button", nil, panel)
    head:SetPoint("TOPLEFT", 6, -4)
    head:SetPoint("TOPRIGHT", -6, -4)
    head:SetHeight(HEAD)
    head:SetScript("OnClick", function() GoalsUI:ToggleFold() end)
    head:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GoalsUI:EnterHead()
    end)
    head:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.head = head

    head.fold = Theme.CreateLabel(head, "normal", "accent", "CENTER")
    head.fold:SetPoint("LEFT", 2, 0)
    head.fold:SetWidth(14)
    head.title = Theme.CreateLabel(head, "small", "accent")
    head.title:SetPoint("LEFT", 20, 0)
    head.title:SetText(L["GOLD GOALS"])
    head.purse = Theme.CreateLabel(head, "small", "text", "RIGHT")
    head.purse:SetPoint("RIGHT", -2, 0)
    head.purse:SetPoint("LEFT", head.title, "RIGHT", 12, 0)

    local segments = CreateSegments(panel, 6)
    segments:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 2, -2)
    segments:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -2, -2)
    self.segments = segments

    self.rows = {}
    return panel
end

function GoalsUI:GoalRow(index)
    local row = self.rows[index]
    if row then return row end
    row = CreateRow(self.panel, GOAL_ROW)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", 6, 0)
    if row.icon.SetTexCoord then row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    row.value = Theme.CreateLabel(row, "small", "text", "RIGHT")
    row.value:SetPoint("TOPRIGHT", -8, -4)
    row.label = Theme.CreateLabel(row, "small", "text")
    row.label:SetPoint("TOPLEFT", 38, -4)
    row.label:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
    row.bar = CreateBar(row, 8)
    row.bar:SetPoint("TOPLEFT", 38, -19)
    row.bar:SetPoint("TOPRIGHT", -8, -19)
    row.detail = Theme.CreateLabel(row, "tiny", "muted")
    row.detail:SetPoint("TOPLEFT", 38, -29)
    row.detail:SetPoint("RIGHT", -8, 0)
    -- The All characters row: the name, a status and mini segments.
    row.mini = CreateSegments(row, 5)
    row.mini:SetPoint("TOPLEFT", 8, -19)
    row.mini:SetPoint("TOPRIGHT", -8, -19)
    self.rows[index] = row
    return row
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function GoalsUI:IsFolded()
    local folded = ns.UI and ns.UI.Folded and ns.UI:Folded()
    return folded and folded.goldGoals == true
end

function GoalsUI:ToggleFold()
    local folded = ns.UI:Folded()
    folded.goldGoals = not (folded.goldGoals == true)
    self.drawnKey = nil
    if ns.UI then ns.UI:Refresh(true) end
end

--- "7g 10s / 12g 20s", or Ready.
function GoalsUI.ValueText(goal)
    if goal.state == "ready" then
        return L["Ready"], "good"
    end
    return L.Format("%s / %s", Money(goal.have), Money(goal.cost)), goal.state == "far" and "muted" or "text"
end

--- The line under a goal's bar.
GoalsUI.AFTER = {
    class = L["After the class spells"],
    profession = L["After the profession training"],
    riding = L["After riding"],
}

function GoalsUI.DetailText(goal, previous)
    local text
    if goal.state == "ready" then
        return (goal.cost or 0) > 0 and L.Format("%s, and your purse covers it.", Money(goal.cost))
            or L["Price after a trainer visit."]
    elseif goal.state == "far" then
        local levels = math.max(1, goal.level - (ns.GoldGoals.Level() or 0))
        text = levels == 1 and L.Format("%s to go. 1 level away.", Money(goal.short))
            or L.Format("%s to go. %d levels away.", Money(goal.short), levels)
    else
        text = L.Format("%s to go.", Money(goal.short))
    end
    local after = previous and GoalsUI.AFTER[previous.kind]
    if after then return L.Format("%s, %s", after, text) end
    return text
end

--- Lay the panel out and draw it. Returns its height, 0 when hidden.
function GoalsUI:Draw(view)
    local GG = ns.GoldGoals
    if not (self.panel and GG and GG:IsOn()) then
        if self.panel then self.panel:Hide() end
        return 0
    end
    local folded = self:IsFolded()
    local rows, height = {}, 0
    if view == "all" then
        local everyone = GG:Everyone()
        local shown = math.min(#everyone, self.MOST_CHARACTERS)
        for index = 1, shown do rows[index] = everyone[index] end
        self.more = #everyone - shown
        self.head.title:SetText(L["GOLD GOALS"])
        self.head.purse:SetText(#everyone == 1 and L["1 character"] or L.Format("%d characters", #everyone))
        self.result = GG:Goals()
        GoalsUI.SetSegments(self.segments, self.result.goals)
        height = CHARACTER_ROW
    else
        local result = GG:Goals()
        self.result = result
        if #result.goals == 0 then
            self.panel:Hide()
            return 0
        end
        for index, goal in ipairs(result.goals) do rows[index] = goal end
        self.head.title:SetText(L["GOLD GOALS"])
        local purse = L.Format("purse %s", Money(result.purse))
        if (result.aside or 0) > 0 then
            purse = L.Format("purse %s, %s set aside", Money(result.purse), Money(result.aside))
        end
        self.head.purse:SetText(purse)
        GoalsUI.SetSegments(self.segments, result.goals)
        height = GOAL_ROW
    end
    self.head.fold:SetText(folded and "+" or "-")

    local top = 4 + HEAD + 2 + 6 + 6
    local count = folded and 0 or #rows
    for index, row in ipairs(self.rows) do
        if index > count then row:Hide() end
    end
    for index = 1, count do
        local row = self:GoalRow(index)
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 6, -(top + (index - 1) * height))
        row:SetPoint("TOPRIGHT", -6, -(top + (index - 1) * height))
        Band(row, index)
        row.data = rows[index]
        row.view = view
        if view == "all" then
            self:DrawCharacter(row, rows[index])
        else
            self:DrawGoal(row, rows[index], rows[index - 1])
        end
        row:Show()
    end
    local total = top + count * height + 6
    self.panel:SetHeight(total)
    self.panel:Show()
    return total
end

function GoalsUI:DrawGoal(row, goal, previous)
    row.icon:Show()
    row.icon:SetTexture(ns.GoldGoals.ICONS[goal.kind] or ns.GoldGoals.ICONS.class)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", 38, -4)
    row.label:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
    row.mini:Hide()
    row.bar:Show()
    row.detail:Show()
    row.label:SetText(goal.label)
    row.label:SetTextColor(Theme.Unpack(goal.state == "far" and "muted" or "text"))
    local value, key = GoalsUI.ValueText(goal)
    row.value:SetText(value)
    row.value:SetTextColor(Theme.Unpack(key))
    local cost = goal.cost or 0
    GoalsUI.SetBar(row.bar, cost > 0 and (goal.have or 0) / cost or (goal.state == "ready" and 1 or 0), goal.state)
    row.detail:SetText((GoalsUI.DetailText(goal, previous)))
    row.active = goal.state == "saving"
    row.edge:SetShown(row.active)
end

function GoalsUI:DrawCharacter(row, entry)
    row.icon:Hide()
    row.bar:Hide()
    row.detail:Hide()
    row.mini:Show()
    local name = entry.name or "?"
    local who = entry.isCurrent and L.Format("%s (you), %d %s", name, entry.level or 0, entry.className or "")
        or L.Format("%s, %d %s", name, entry.level or 0, entry.className or "")
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", 8, -4)
    row.label:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
    row.label:SetText(who)
    row.label:SetTextColor(Theme.Unpack("text"))
    local goals = entry.goals or {}
    local status, key
    if #goals == 0 then
        status, key = L["nothing to save for"], "muted"
    elseif entry.next and entry.next.state == "saving" then
        status, key = L.Format("%d of %d met, %s short for %s", entry.met or 0, #goals, Money(entry.next.short),
            entry.next.label), "warn"
    else
        status, key = L.Format("%d of %d met", entry.met or 0, #goals), "muted"
    end
    row.value:SetText(status)
    row.value:SetTextColor(Theme.Unpack(key))
    GoalsUI.SetSegments(row.mini, goals)
    row.active = entry.isCurrent == true
    row.edge:SetShown(row.active)
end

--------------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------------

function GoalsUI:EnterHead()
    GameTooltip:AddLine(L["Gold goals"], 1, 1, 1)
    GameTooltip:AddLine(L["Your purse fills the goals in order: class spells, then profession training, then riding. Each bar shows what's left after the goals above it."], Theme.Muted(true))
    local result = self.result
    if result and (result.aside or 0) > 0 then
        GameTooltip:AddLine(L.Format("%s is set aside for your other characters by the gold fund.", Money(result.aside)),
            Theme.Muted(true))
    end
    if (self.more or 0) > 0 then
        GameTooltip:AddLine(L.Format("And %d more characters. /bbutler goals lists them all.", self.more),
            Theme.Muted(true))
    end
    GameTooltip:AddLine(self:IsFolded() and L["Click to open."] or L["Click to fold."], Theme.Unpack("muted"))
    GameTooltip:Show()
end

function GoalsUI:Enter(row)
    local data = row.data
    if not data then return end
    if row.view == "all" then
        GameTooltip:AddLine(data.name or "?", 1, 1, 1)
        for _, goal in ipairs(data.goals or {}) do
            local value = GoalsUI.ValueText(goal)
            GameTooltip:AddDoubleLine(goal.label, value, 1, 1, 1, 1, 1, 1)
        end
        if #(data.goals or {}) == 0 then GameTooltip:AddLine(L["nothing to save for"], Theme.Unpack("muted")) end
        if not data.isCurrent then
            GameTooltip:AddLine(L["As that character last saw it."], Theme.Muted(true))
        end
        GameTooltip:Show()
        return
    end
    local goal = data
    GameTooltip:AddLine(goal.label, 1, 1, 1, true)
    local CT = ns.ClassTraining
    if goal.kind == "class" and goal.spells and CT then
        for _, spell in ipairs(goal.spells) do
            GameTooltip:AddDoubleLine(CT.Label(spell.entry), spell.cost and Money(spell.cost) or L["not priced yet"],
                1, 1, 1, 1, 1, 1)
        end
    elseif goal.kind == "profession" then
        for _, rank in ipairs(goal.ranks or {}) do
            GameTooltip:AddDoubleLine(rank.name, Money(rank.cost), 1, 1, 1, 1, 1, 1)
        end
        for _, recipe in ipairs(goal.recipes or {}) do
            GameTooltip:AddDoubleLine(recipe.count == 1 and L.Format("%s: 1 recipe", recipe.name)
                or L.Format("%s: %d recipes", recipe.name, recipe.count), Money(recipe.cost), 1, 1, 1, 1, 1, 1)
        end
        if #(goal.recipes or {}) == 0 and not (ns.Sisters and ns.Sisters.Butler("ts")) then
            GameTooltip:AddLine(L["With Blackthornes Tradeskills, the trainers' recipes you can learn are counted too."],
                Theme.Muted(true))
        end
    elseif goal.kind == "riding" and goal.riding then
        GameTooltip:AddDoubleLine(goal.riding.name, Money(goal.riding.cost), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine(L["The training only, not the mount."], Theme.Muted(true))
    end
    GameTooltip:AddDoubleLine(L["In all"], Money(goal.cost), 1, 0.82, 0, 1, 1, 1)
    if goal.guessed or (goal.unknown or 0) > 0 then
        GameTooltip:AddLine(L["Prices and skills may update when you visit your trainer for the first time."],
            Theme.Muted(true))
    end
    if goal.state == "ready" then
        GameTooltip:AddLine(L["You have enough gold for it."], 0.31, 0.88, 0.42, true)
    elseif goal.state == "far" then
        GameTooltip:AddLine(L.Format("You can train it at level %d.", goal.level), Theme.Muted(true))
    end
    GameTooltip:Show()
end
