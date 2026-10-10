-- Blackthornes Butler -- UI/MainWindow.lua
-- The Butler window: every item in your bags and what to do with it, in
-- groups (Sell, Look at it, Keep), each with its count and what it is worth.
--
-- It is what a click on the minimap button and a bare /bbutler open, and it
-- comes up by itself at a vendor when there is something to sell (the
-- "Open at a vendor" setting). The Sell button (Logic/Selling.lua) sits over
-- its foot while a vendor is open.
--
-- Smooth play: the list is set again only when the bags or a verdict changed
-- (Bags.version, Verdicts.version), and only while the window is up. Only
-- the rows on screen exist (Widgets.CreateRowList).

local _, ns = ...

local UI = ns.NewModule("UI")

local Theme = ns.Theme
local Widgets = ns.Widgets
local Items = ns.Items

local PADDING = 18
-- From the window's top to the gold rule under the header row.
local HEADER = 44
-- The metal rim sits on the window's edge and reaches this far inward, with
-- room to spare (UI/Titanforged.lua).
local EDGE_PAD = 11
local WIDTH = 560
local HEIGHT = 440
local ROW_HEIGHT = 22
-- From the well's foot to the window's.
local FOOT = 40

-- Where the Sell button sits: in from the window's right edge and up from
-- its foot (Selling:Place).
UI.SELL_INSET_X = PADDING
UI.SELL_INSET_Y = 9

-- The game's item quality colours.
local QUALITY = {
    [0] = { 0.616, 0.616, 0.616 },
    [1] = { 1, 1, 1 },
    [2] = { 0.118, 1, 0 },
    [3] = { 0, 0.439, 0.867 },
    [4] = { 0.639, 0.208, 0.933 },
    [5] = { 1, 0.502, 0 },
}

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

function UI:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "BlackthornesButlerWindow", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    Theme.Fill(frame, "window")

    -- The house frame (UI/Titanforged.lua): a gold rim with corner gems, the
    -- satchel in a round portrait, the name on a plate and a red close gem.
    if ns.Titanforged then
        local trim = ns.Titanforged:Dress(frame, {
            title = "Blackthornes Butler",
            portrait = true,
            close = function() UI:Hide() end,
        })
        self.trim = trim

        -- Kept on the screen whole: the portrait and plate reach out past
        -- the top left, and the corner gems past every edge.
        local left, right, top, bottom = ns.Titanforged.Reach(trim)
        if frame.SetClampRectInsets then
            frame:SetClampRectInsets(-left, right, top, -bottom)
        end
    else
        Theme.Border(frame, "borderLit")
    end

    -- The Sell button is placed by screen position, so it hides while the
    -- window moves and comes back where the window lands.
    frame:SetScript("OnDragStart", function(self)
        UI.dragging = true
        if ns.Selling then ns.Selling:Update() end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.dragging = false
        UI:SavePosition()
        if ns.Selling then ns.Selling:Update() end
    end)
    frame:SetScript("OnHide", function()
        UI.dragging = false
        UI.openedByVendor = false
        UI:HideMenu()
        if ns.Selling then ns.Selling:Update() end
    end)

    -- Escape closes it, like the game's own windows.
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "BlackthornesButlerWindow")
    end

    self.frame = frame
    self:BuildHeader()

    -- The list's well, sunk into the window like Pets' and Equipment's.
    local well = Theme.CreatePanel(frame, "panel", "border")
    well:SetPoint("TOPLEFT", PADDING, -(HEADER + 10))
    well:SetPoint("BOTTOMRIGHT", -PADDING, FOOT)
    if Theme.Recess then Theme.Recess(well) end
    self.well = well

    self.list = Widgets.CreateRowList(well, {
        rowHeight = ROW_HEIGHT,
        fadeKey = "panel",
        createRow = function(row) UI.CreateRow(row) end,
        updateRow = function(row, data) UI.UpdateRow(row, data) end,
        onClick = function(data, button) UI:Clicked(data, button) end,
        onEnter = function(row, data) UI:Enter(row, data) end,
        onLeave = function() GameTooltip:Hide() end,
    })
    self.list:SetPoint("TOPLEFT", 6, -6)
    self.list:SetPoint("BOTTOMRIGHT", -6, 6)

    local empty = Theme.CreateLabel(well, "normal", "muted", "CENTER")
    empty:SetPoint("CENTER", 0, 0)
    empty:SetWidth(WIDTH - 4 * PADDING)
    empty:SetWordWrap(true)
    self.emptyLabel = empty

    -- The installed version, small and faint in the bottom right corner,
    -- so a player can see at a glance which one they run. The Sell button
    -- takes its place at a vendor.
    local version = Theme.CreateLabel(frame, "tiny", "dim", "RIGHT")
    version:SetPoint("BOTTOMRIGHT", -PADDING, 14)
    version:SetText(ns.VersionLabel())
    self.versionLabel = version

    local footer = Theme.CreateLabel(frame, "small", "muted")
    footer:SetPoint("BOTTOMLEFT", PADDING, 14)
    footer:SetPoint("RIGHT", frame, "RIGHT", -(PADDING + 90), 0)
    self.footer = footer

    frame:Hide()
    return frame
end

--- The header row. The window's name is on the plate across the top edge
--- and the close gem sits on the top right corner (UI/Titanforged.lua), so
--- the row holds a line on what is shown and the Settings button, clear of the
--- portrait on the left.
function UI:BuildHeader()
    local frame = self.frame

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", EDGE_PAD, -EDGE_PAD)
    header:SetPoint("TOPRIGHT", -EDGE_PAD, -EDGE_PAD)
    header:SetHeight(HEADER - EDGE_PAD)

    -- A gold rule under it, bright at the left and fading out to the right.
    local rule = header:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    rule:SetHeight(1)
    Theme.SetGradientAlpha(rule, "HORIZONTAL", "accent", 0.6, 0.05)

    -- Past the portrait, which reaches 48 pixels into the window.
    local subtitle = Theme.CreateLabel(header, "small", "muted")
    subtitle:SetPoint("LEFT", header, "LEFT", 48, -4)
    self.subtitle = subtitle

    -- Below the close gem on the corner.
    local settings = Widgets.CreateButton(header, "Settings", function()
        if ns.SettingsUI then ns.SettingsUI:Toggle() end
    end, { width = 70, height = 20 })
    settings:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 4)
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

--- A row's pieces, built once: the item's icon and name, the reason, and
--- what the stack is worth. A group's heading uses the same pieces.
function UI.CreateRow(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 6, ROW_HEIGHT - 6)
    row.icon:SetPoint("LEFT", 6, 0)
    if row.icon.SetTexCoord then row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end

    row.fold = Theme.CreateLabel(row, "normal", "accent", "CENTER")
    row.fold:SetPoint("CENTER", row, "LEFT", 14, 0)
    row.fold:SetWidth(16)

    row.name = Theme.CreateLabel(row, "small", "text")
    row.name:SetPoint("LEFT", 28, 0)
    row.name:SetWidth(190)

    row.worth = Theme.CreateLabel(row, "small", "text", "RIGHT")
    row.worth:SetPoint("RIGHT", -6, 0)
    row.worth:SetWidth(96)

    row.reason = Theme.CreateLabel(row, "small", "muted")
    row.reason:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.reason:SetPoint("RIGHT", row.worth, "LEFT", -8, 0)
end

local function Plural(count, one, many)
    return ("%d %s"):format(count, count == 1 and one or many)
end

function UI.UpdateRow(row, data)
    if data.type == "header" then
        local group = data.group
        row.icon:Hide()
        row.fold:Show()
        row.fold:SetText(data.folded and "+" or "-")
        row.name:SetTextColor(Theme.Unpack("accent"))
        row.name:SetText(group.label:upper())
        row.reason:SetText(Plural(group.count, "item", "items"))
        row.worth:SetText(group.worth > 0 and Items.FormatMoney(group.worth) or "")
        return
    end

    row.fold:Hide()
    row.icon:Show()
    row.icon:SetTexture(data.icon or [[Interface\Icons\INV_Misc_QuestionMark]])
    local color = QUALITY[data.quality or 1] or QUALITY[1]
    row.name:SetTextColor(color[1], color[2], color[3])
    row.name:SetText(data.count > 1 and ("%s x%d"):format(data.name, data.count) or data.name)
    row.reason:SetText(data.reason or "")
    row.worth:SetText((data.worth or 0) > 0 and Items.FormatMoney(data.worth) or "")
end

--- The rows to show: each group's heading, then its items unless folded.
--- Groups with nothing in them are left out.
function UI:Lines()
    local lines = {}
    local folded = self:Folded()
    for _, group in ipairs(ns.Verdicts:Groups()) do
        if group.count > 0 then
            local isFolded = folded[group.verdict] == true
            lines[#lines + 1] = { type = "header", group = group, folded = isFolded }
            if not isFolded then
                for _, row in ipairs(group.rows) do lines[#lines + 1] = row end
            end
        end
    end
    return lines
end

--- Which groups are folded, per character: Keep starts folded, since there
--- is nothing to do there.
function UI:Folded()
    local char = ns.charDB or {}
    if type(char.folded) ~= "table" then char.folded = { keep = true } end
    return char.folded
end

--------------------------------------------------------------------------------
-- Mouse
--------------------------------------------------------------------------------

function UI:Clicked(data, button)
    if data.type == "header" then
        local folded = self:Folded()
        folded[data.group.verdict] = not folded[data.group.verdict] or nil
        self:Refresh(true)
        return
    end
    if button == "RightButton" then
        self:ShowMenu(data)
    end
end

function UI:Enter(row, data)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if data.type == "header" then
        GameTooltip:AddLine(data.group.label, Theme.Unpack("accent"))
        GameTooltip:AddLine(data.folded and "Click to show these items" or "Click to fold these away", 1, 1, 1, true)
        GameTooltip:Show()
        return
    end

    local slot = data.slots[1]
    local shown = slot and pcall(GameTooltip.SetBagItem, GameTooltip, slot.bag, slot.slot)
    if not shown and data.link then pcall(GameTooltip.SetHyperlink, GameTooltip, data.link) end

    GameTooltip:AddLine(" ")
    local r, g, b = Theme.Unpack("accent")
    GameTooltip:AddLine(("Butler: %s"):format(ns.Verdicts.LABELS[data.verdict] or data.verdict), r, g, b)
    if data.reason and data.reason ~= "" then
        GameTooltip:AddLine(data.reason, 1, 1, 1, true)
    end
    GameTooltip:AddLine("Right-click to always keep or always sell it", Theme.Unpack("muted"))
    GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- The right-click menu
--
-- A small window of Butler's own, never the game's dropdown menus: Always
-- keep, Always sell, and Let Butler decide once either is picked.
--------------------------------------------------------------------------------

local MENU_WIDTH = 170

function UI:BuildMenu()
    if self.menu then return self.menu end

    local menu = CreateFrame("Frame", "BlackthornesButlerMenu", UIParent)
    menu:SetSize(MENU_WIDTH, 112)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    Theme.Fill(menu, "window")
    Theme.Border(menu, "metal")

    menu.title = Theme.CreateLabel(menu, "small", "accent")
    menu.title:SetPoint("TOPLEFT", 8, -8)
    menu.title:SetPoint("TOPRIGHT", -8, -8)

    local function Pick(choice)
        local data = UI.menu.data
        UI:HideMenu()
        if data then ns.Verdicts:SetChoice(data.itemID, choice) end
    end

    menu.keep = Widgets.CreateButton(menu, "Always keep", function() Pick("keep") end,
        { width = MENU_WIDTH - 16, height = 20 })
    menu.keep:SetPoint("TOPLEFT", 8, -26)
    menu.sell = Widgets.CreateButton(menu, "Always sell", function() Pick("sell") end,
        { width = MENU_WIDTH - 16, height = 20 })
    menu.sell:SetPoint("TOPLEFT", menu.keep, "BOTTOMLEFT", 0, -4)
    menu.decide = Widgets.CreateButton(menu, "Let Butler decide", function() Pick(nil) end,
        { width = MENU_WIDTH - 16, height = 20 })
    menu.decide:SetPoint("TOPLEFT", menu.sell, "BOTTOMLEFT", 0, -4)

    -- Gone once the mouse has been off it for a moment, as the game's menus
    -- go. Only runs while the menu is up.
    menu:SetScript("OnUpdate", function(frame, elapsed)
        local ok, over = pcall(frame.IsMouseOver, frame)
        frame.away = (ok and over) and 0 or (frame.away or 0) + (elapsed or 0)
        if frame.away > 1.5 then UI:HideMenu() end
    end)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "BlackthornesButlerMenu")
    end

    menu:Hide()
    self.menu = menu
    return menu
end

function UI:ShowMenu(data)
    local menu = self:BuildMenu()
    menu.data = data
    menu.away = 0
    menu.title:SetText(data.name)

    local choice = ns.Verdicts:Choice(data.itemID)
    menu.keep:SetText(choice == "keep" and "Always keep (now)" or "Always keep")
    menu.sell:SetText(choice == "sell" and "Always sell (now)" or "Always sell")
    menu.decide:SetShown(choice ~= nil)
    menu:SetHeight(choice ~= nil and 112 or 88)

    local x, y = 0, 0
    if type(GetCursorPosition) == "function" then
        x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale() or 1
        x, y = x / scale, y / scale
    end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 10, y + 10)
    menu:Show()
end

function UI:HideMenu()
    if self.menu then
        self.menu.data = nil
        self.menu:Hide()
    end
end

--------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------

--- Bring the window up to date. The list is set again only when the bags,
--- a verdict or a fold changed (`force` for a fold).
function UI:Refresh(force)
    if not self:IsShown() then return end

    local key = ("%d:%d"):format(ns.Bags.version, ns.Verdicts.version)
    if force or key ~= self.drawnKey then
        local first = self.drawnKey == nil
        self.drawnKey = key
        self.list:SetData(self:Lines(), not first)
    end

    local total = 0
    for _, entry in pairs(ns.Bags.slots) do total = total + 1 end
    self.subtitle:SetText(total > 0 and ("Your bags: %s"):format(Plural(total, "stack", "stacks")) or "Your bags")

    if total == 0 and (ns.Bags.scanning or ns.Bags.stale) then
        self.emptyLabel:SetText("Reading your bags...")
    elseif total == 0 then
        self.emptyLabel:SetText("Your bags are empty.")
    else
        self.emptyLabel:SetText("")
    end
    self.emptyLabel:SetShown(self.emptyLabel:GetText() ~= "")

    self:UpdateFooter()
end

function UI:UpdateFooter()
    local sell = ns.Verdicts:Group("sell")
    local text = ""
    if self.sellShown then
        text = "Sold items stay in the vendor's Buyback tab."
    elseif sell and sell.count > 0 then
        text = ("To sell: %s, %s. Open a vendor to sell them."):format(
            Plural(sell.count, "item", "items"), Items.FormatMoney(sell.worth))
    else
        text = "Nothing to sell right now."
    end
    self.footer:SetText(text)
end

--- The Sell button came up over the window's foot, or went.
function UI:SellShown(shown, width)
    if not self.frame then return end
    self.sellShown = shown and true or false
    self.versionLabel:SetShown(not shown)
    -- The footer's words stop short of the button, however wide its label.
    local room = shown and (width or 150) + 12 or 90
    self.footer:SetPoint("RIGHT", self.frame, "RIGHT", -(PADDING + room), 0)
    if self:IsShown() then self:UpdateFooter() end
end

--------------------------------------------------------------------------------
-- At a vendor
--------------------------------------------------------------------------------

--- A vendor opened: come up by itself when there is something to sell and
--- the player wants that ("Open at a vendor").
function UI:AtVendor()
    if self:IsShown() or not (ns.db and ns.db.openAtVendor) then return end
    local sell = ns.Verdicts:Group("sell")
    if not (sell and sell.count > 0) then return end
    self:Show()
    self.openedByVendor = true
end

--- The vendor closed: a window that came up for it goes with it.
function UI:LeftVendor()
    if self.openedByVendor then
        self.openedByVendor = false
        self:Hide()
    elseif ns.Selling then
        ns.Selling:Update()
    end
end

--------------------------------------------------------------------------------
-- Position and visibility
--------------------------------------------------------------------------------

function UI:SavePosition()
    if not (ns.db and self.frame) then return end
    local point, _, relativePoint, x, y = self.frame:GetPoint()
    ns.db.point, ns.db.relativePoint, ns.db.x, ns.db.y = point, relativePoint, x, y
end

function UI:RestorePosition()
    if not self.frame then return end
    local db = ns.db or {}
    self.frame:ClearAllPoints()
    self.frame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER",
        db.x or 0, db.y or 40)
end

function UI:IsShown()
    return self.frame ~= nil and self.frame:IsShown() == true
end

function UI:Show()
    self:Build()
    if not self.frame:IsShown() then
        self:RestorePosition()
        self.frame:Show()
        ns.Motion:Open(self.frame)
        -- A light runs round the portrait as it opens.
        if ns.Titanforged then ns.Titanforged:Opened(self.frame) end
    end
    self:Refresh()
    -- Read the bags if they changed while the window was closed; the list
    -- follows when the read is done.
    ns.Bags:Fresh(function()
        UI:Refresh()
        if ns.Selling then ns.Selling:Update() end
    end)
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

function UI:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

ns.RegisterCommand("window", "open the Butler window (so does /bbutler on its own)", function()
    UI:Toggle()
end)
