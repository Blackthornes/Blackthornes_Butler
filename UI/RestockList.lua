-- Blackthornes Butler -- UI/RestockList.lua
-- KEEP IN YOUR BAGS on the Settings Keep page (the restock list,
-- Logic/Restock.lua; the owner said "build 1-10", 2026-11-26, from the
-- mockup butler-improve-2-restock): a row a line with ITEM OR KIND, a
-- KEEP box and HAVE, and a last row to drop an item on or pick a kind.
-- Typing 0 takes a line off. Dark glass rows, as every list.

local _, ns = ...
local L = ns.L

local RestockList = ns.NewModule("RestockList")

local Theme = ns.Theme
local Widgets = ns.Widgets
local Items = ns.Items

local ROW = 26
local HEADER = 18
local ICON = 18
local KEEP_LEFT = 196
local KEEP_WIDTH = 44
local NAME_WIDTH = 160

RestockList.ICONS = {
    food = [[Interface\Icons\INV_Misc_Food_15]],
    water = [[Interface\Icons\INV_Drink_07]],
}

--- A line's icon: the item's own, or the kind's.
function RestockList.Icon(item)
    if RestockList.ICONS[item] then return RestockList.ICONS[item] end
    local icon = Items.Call({ "C_Item.GetItemIconByID", "GetItemIcon" }, item)
    return icon or [[Interface\Icons\INV_Misc_QuestionMark]]
end

--- Build the list under `head` (the section) in `list` (a frame the page
--- placed), `width` wide.
function RestockList:Build(head, list, width)
    self.list, self.width = list, width
    local who = Theme.CreateLabel(head, "tiny", "muted", "RIGHT")
    who:SetPoint("TOPRIGHT", 0, 0)
    who:SetText(L["This character"])

    local function Heading(text, x, justify)
        local label = Theme.CreateLabel(list, "tiny", "heading", justify)
        label:SetText(text)
        if justify == "RIGHT" then
            label:SetPoint("TOPRIGHT", list, "TOPLEFT", x, -3)
        else
            label:SetPoint("TOPLEFT", x, -3)
        end
    end
    Heading(L["ITEM OR KIND"], 8 + ICON + 6)
    Heading(L["KEEP"], KEEP_LEFT)
    Heading(L["HAVE"], width - 8, "RIGHT")
    list.rows = {}

    -- The last row: drop an item here, or click to pick a kind.
    local add = CreateFrame("Button", nil, list)
    add:SetWidth(width)
    add:SetHeight(ROW + 4)
    add:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    add.fill = Theme.Fill(add, "glass")
    add.slot = add:CreateTexture(nil, "ARTWORK")
    add.slot:SetSize(ICON, ICON)
    add.slot:SetPoint("LEFT", 8, 0)
    add.slot:SetTexture([[Interface\PaperDoll\UI-Backpack-EmptySlot]])
    add.text = Theme.CreateLabel(add, "small", "dim")
    add.text:SetPoint("LEFT", add.slot, "RIGHT", 6, 0)
    add.text:SetPoint("RIGHT", -8, 0)
    add.text:SetWordWrap(true)
    add.text:SetText(L["Drop an item here, or pick a kind"])
    add:SetScript("OnClick", function() RestockList:AddClicked() end)
    add:SetScript("OnReceiveDrag", function() RestockList:AddClicked() end)
    add:SetScript("OnEnter", function(self) self.fill:SetColorTexture(Theme.Unpack("glassHover")) end)
    add:SetScript("OnLeave", function(self) self.fill:SetColorTexture(Theme.Unpack("glass")) end)
    list.add = add
end

--- The item on the cursor goes on the list; with nothing held, a menu of
--- the kinds not on it yet.
function RestockList:AddClicked()
    local restock = ns.Restock
    if not restock then return end
    local held = ns.KeepAcrossUI and ns.KeepAcrossUI.Cursor()
    if held then
        Items.Call({ "ClearCursor" })
        restock:Add(held)
        return
    end
    local lines = {}
    for _, kind in ipairs(restock.KINDS) do
        if not restock:Count(kind) then
            lines[#lines + 1] = { text = restock.Label(kind), run = function() restock:Add(kind) end }
        end
    end
    if ns.RowMenu then ns.RowMenu:Open(lines) end
end

local function SaveKeep(row)
    if not row.item then return end
    local text = row.keep.editBox:GetText()
    if text == nil or text == "" then return end
    local count = tonumber(text) or 0
    if count == row.count then return end
    ns.Restock:Set(row.item, count)
end

local function Row(list, index, width)
    local row = list.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, list)
    row:SetWidth(width)
    row.fill = Theme.Fill(row, "glass")
    row.line = row:CreateTexture(nil, "BORDER")
    row.line:SetPoint("BOTTOMLEFT")
    row.line:SetPoint("BOTTOMRIGHT")
    row.line:SetHeight(1)
    row.line:SetColorTexture(Theme.Unpack("border", 0.6))
    row.edge = row:CreateTexture(nil, "ARTWORK")
    row.edge:SetPoint("TOPLEFT")
    row.edge:SetPoint("BOTTOMLEFT")
    row.edge:SetWidth(2)
    row.edge:SetColorTexture(Theme.Unpack("accent"))
    row.edge:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", 8, 0)
    row.name = Theme.CreateLabel(row, "normal", "text")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(NAME_WIDTH)
    row.name:SetWordWrap(true)
    row.keep = Widgets.CreateSearchBox(row, "", nil, function() SaveKeep(row) end, { plain = true })
    row.keep:SetSize(KEEP_WIDTH, 20)
    row.keep:SetPoint("LEFT", row, "LEFT", KEEP_LEFT, 0)
    local edit = row.keep.editBox
    edit:SetMaxLetters(3)
    edit:SetJustifyH("RIGHT")
    if edit.SetNumeric then edit:SetNumeric(true) end
    edit:HookScript("OnEditFocusLost", function() SaveKeep(row) end)
    row.have = Theme.CreateLabel(row, "normal", "text", "RIGHT")
    row.have:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnEnter", function(self)
        self.fill:SetColorTexture(Theme.Unpack("glassHover"))
        self.edge:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local shown = type(self.item) == "number" and pcall(GameTooltip.SetItemByID, GameTooltip, self.item)
        if not shown then GameTooltip:AddLine(ns.Restock.Label(self.item), Theme.Unpack("accentHi")) end
        GameTooltip:AddLine(L["0 takes it off the list."], Theme.Unpack("dim"))
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.fill:SetColorTexture(Theme.Unpack(self.band))
        self.edge:Hide()
        GameTooltip:Hide()
    end)
    list.rows[index] = row
    return row
end

local function TextHeight(label, least)
    local ok, height = pcall(label.GetStringHeight, label)
    height = ok and tonumber(height) or nil
    return math.max(least, height and (height + 8) or least)
end

--- Draw the list again from Restock's lines. Only while Settings shows.
function RestockList:Sync()
    local list, restock = self.list, ns.Restock
    if not (list and restock) then return end
    local settings = ns.SettingsUI
    if settings and settings.frame and settings.frame.IsShown and not settings.frame:IsShown() then
        list.stale = true
        return
    end
    list.stale = nil
    local y = HEADER
    local lines = restock:MyLines()
    for index, line in ipairs(lines) do
        local row = Row(list, index, self.width)
        row.item, row.count = line.item, line.keep
        row.band = (index % 2 == 0) and "glassAlt" or "glass"
        row.fill:SetColorTexture(Theme.Unpack(row.band))
        row.icon:SetTexture(self.Icon(line.item))
        local name = restock.Label(line.item)
        if not restock.IsKind(line.item) then name = Items:ColorName(name, line.item) or name end
        row.name:SetText(name)
        local edit = row.keep.editBox
        if not (edit.HasFocus and edit:HasFocus()) then row.keep:SetText(tostring(line.keep)) end
        local have = restock:Have(line.item)
        row.have:SetText(tostring(have))
        row.have:SetTextColor(Theme.Unpack(have < line.keep and "warn" or "text"))
        local height = TextHeight(row.name, ROW)
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        row:Show()
        y = y + height
    end
    for index = #lines + 1, #list.rows do list.rows[index]:Hide() end
    local add = list.add
    add.fill:SetColorTexture(Theme.Unpack((#lines + 1) % 2 == 0 and "glassAlt" or "glass"))
    add:ClearAllPoints()
    add:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
    y = y + (add:GetHeight() or ROW)

    local height = math.ceil(y + 2)
    if list.fixedHeight ~= height then
        list.fixedHeight = height
        list:SetHeight(height)
        if settings and settings.pages and settings.pages.fitted then settings.pages:Fit() end
    end
end
