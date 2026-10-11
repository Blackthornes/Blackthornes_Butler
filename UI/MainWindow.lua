-- Blackthornes Butler -- UI/MainWindow.lua
-- The Butler window: every item in your bags and what to do with it, in
-- groups (Sell, Look at it, Keep), each with its count and what it is worth.
--
-- It is what a click on the minimap button and a bare /bbutler open, and it
-- comes up by itself at every vendor and goes when the vendor closes (the
-- "Open at a vendor" setting). The Sell button (Logic/Selling.lua) sits over
-- its foot while a vendor is open.
--
-- It has a second view, All characters (Logic/Everyone.lua; /bbutler all,
-- the header's All characters button): every character's items in one
-- list with a search box, who has each and whether it is in their bags,
-- bank or mail. A click on an item opens a line per character under it.
--
-- Smooth play: the list is set again only when the bags or a verdict changed
-- (Bags.version, Verdicts.version; Everyone.version in All characters), and
-- only while the window is up. Only the rows on screen exist
-- (Widgets.CreateRowList).

local _, ns = ...

local UI = ns.NewModule("UI")

-- Which list the window shows: "bags" (what to do with each item) or "all"
-- (every character's items). Bags each time it opens at a vendor.
UI.view = "bags"
-- Items opened in All characters: { [itemID] = true }, for the session.
UI.open = {}

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

-- The mailbox and bank buttons' widths; Fill mail carries a name.
local ERRAND_WIDTH = 140
local MAIL_WIDTH = 180

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
        UI.openedFor = nil
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

    -- At a mailbox or the bank (Logic/Errands.lua): plain buttons in the
    -- Sell button's place, which only shows at a vendor.
    local function Run(fn)
        return function()
            local _, message = fn(ns.Errands)
            if message then ns.Print(message) end
        end
    end
    self.mailButton = Widgets.CreateButton(frame, "Fill mail", Run(ns.Errands.FillMail),
        { width = MAIL_WIDTH, height = 24, primary = true })
    self.mailButton:SetPoint("BOTTOMRIGHT", -UI.SELL_INSET_X, UI.SELL_INSET_Y)
    self.mailButton.tooltipText = "Fills the game's Send Mail page. Check it, then press Send."
    self.mailButton:Hide()

    self.bankButton = Widgets.CreateButton(frame, "Move to bank", Run(ns.Errands.MoveToBank),
        { width = ERRAND_WIDTH, height = 24, primary = true })
    self.bankButton:SetPoint("BOTTOMRIGHT", -UI.SELL_INSET_X, UI.SELL_INSET_Y)
    self.bankButton.tooltipText = "Puts your Always bank items in the bank, a stack at a time"
    self.bankButton:Hide()

    self.takeButton = Widgets.CreateButton(frame, "Take from bank", Run(ns.Errands.TakeFromBank),
        { width = ERRAND_WIDTH, height = 24 })
    self.takeButton.tooltipText = "Takes out what your craft queue still needs, in whole stacks"
    self.takeButton:Hide()

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

    -- All characters' search, in the subtitle's place.
    local search = Widgets.CreateSearchBox(header, "Search all characters", function()
        UI:Refresh()
    end)
    search:SetPoint("LEFT", header, "LEFT", 48, -2)
    search:SetWidth(230)
    search:Hide()
    self.search = search

    -- Below the close gem on the corner.
    local settings = Widgets.CreateButton(header, "Settings", function()
        if ns.SettingsUI then ns.SettingsUI:Toggle() end
    end, { width = 70, height = 20 })
    settings:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 4)

    -- Between the two lists.
    local view = Widgets.CreateButton(header, "All characters", function()
        UI:SetView(UI.view == "all" and "bags" or "all")
    end, { width = 110, height = 20 })
    view:SetPoint("RIGHT", settings, "LEFT", -6, 0)
    view.tooltipText = "Every character's items, and where each one is"
    self.viewButton = view
end

--- Show one list or the other: "bags" or "all".
function UI:SetView(view)
    view = view == "all" and "all" or "bags"
    local changed = view ~= self.view
    self.view = view
    if not self.frame then return end

    local all = view == "all"
    self.subtitle:SetShown(not all)
    self.search:SetShown(all)
    if not all then self.search:ClearFocus() end
    self.viewButton:SetText(all and "Your bags" or "All characters")
    self.viewButton.tooltipText = all and "What to do with each item in your bags"
        or "Every character's items, and where each one is"

    if changed then
        self.drawnKey = nil
        GameTooltip:Hide()
        if all then ns.Everyone:Changed() end
        if ns.Selling then ns.Selling:Update() end
        self:UpdateErrands()
        self:Refresh(true)
    end
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
    row.worth:SetTextColor(Theme.Unpack("text"))
    if data.type == "everyone" then return UI.UpdateItemRow(row, data) end
    if data.type == "holder" then return UI.UpdateHolderRow(row, data) end

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

--- An item in All characters: its name, who has it and how many in all.
function UI.UpdateItemRow(row, data)
    local item = data.item
    row.fold:Hide()
    row.icon:Show()
    row.icon:SetTexture(item.icon or [[Interface\Icons\INV_Misc_QuestionMark]])
    local color = QUALITY[item.quality or 1] or QUALITY[1]
    row.name:SetTextColor(color[1], color[2], color[3])
    row.name:SetText(item.name)
    row.reason:SetText(ns.Everyone.Summary(item))
    row.worth:SetText(tostring(item.total))
end

--- One character's share of an opened item, set in under it.
function UI.UpdateHolderRow(row, data)
    local holder = data.holder
    local character = holder.character
    row.fold:Hide()
    row.icon:Hide()
    local name = "    " .. character.short
    if character.isCurrent then
        name = name .. " (you)"
    elseif character.linked then
        name = name .. " (other account)"
    end
    row.name:SetTextColor(Theme.Unpack("text"))
    row.name:SetText(name)
    row.reason:SetText(ns.Everyone.Where(holder))
    row.worth:SetTextColor(Theme.Unpack("muted"))
    row.worth:SetText(ns.Everyone.Age(ns.Everyone.Seen(holder)))
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
    if data.type == "everyone" or data.type == "holder" then
        local itemID = data.item.itemID
        self.open[itemID] = not self.open[itemID] or nil
        self.openVersion = (self.openVersion or 0) + 1
        self:Refresh()
        return
    end
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
    if data.type == "everyone" or data.type == "holder" then
        return self:EnterEveryone(data)
    end
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
    GameTooltip:AddLine("Right-click to always keep, sell or bank it", Theme.Unpack("muted"))
    GameTooltip:Show()
end

--- An item in All characters: the item's own tooltip, then who has it.
function UI:EnterEveryone(data)
    local item = data.item
    pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. item.itemID)
    GameTooltip:AddLine(" ")
    local r, g, b = Theme.Unpack("accent")
    GameTooltip:AddLine(("Butler: %d on %s"):format(item.total,
        Plural(#item.holders, "character", "characters")), r, g, b)
    for _, holder in ipairs(item.holders) do
        GameTooltip:AddDoubleLine(holder.character.short, ns.Everyone.Where(holder), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(data.type == "holder" and "Click to close"
        or (data.open and "Click to close" or "Click to see each character"), Theme.Unpack("muted"))
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
    -- Over the Sell button, which shares this layer.
    menu:SetFrameLevel(50)
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
    menu.bank = Widgets.CreateButton(menu, "Always bank", function() Pick("bank") end,
        { width = MENU_WIDTH - 16, height = 20 })
    menu.bank:SetPoint("TOPLEFT", menu.sell, "BOTTOMLEFT", 0, -4)
    menu.decide = Widgets.CreateButton(menu, "Let Butler decide", function() Pick(nil) end,
        { width = MENU_WIDTH - 16, height = 20 })
    menu.decide:SetPoint("TOPLEFT", menu.bank, "BOTTOMLEFT", 0, -4)

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
    menu.bank:SetText(choice == "bank" and "Always bank (now)" or "Always bank")
    menu.decide:SetShown(choice ~= nil)
    menu:SetHeight(choice ~= nil and 136 or 112)

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
    if self.view == "all" then return self:RefreshAll(force) end

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

    if ns.Errands.mailOpen or ns.Errands.bankOpen then
        self:UpdateErrands()
    else
        self:UpdateFooter()
    end
end

--- All characters: built again when the bags moved (once Butler's own read
--- of them is done), set again when the list, the search or an opened item
--- changed.
function UI:RefreshAll(force)
    local everyone = ns.Everyone
    if not ns.Bags.scanning and (everyone.building or everyone:IsStale()) then
        everyone:Fresh(function() UI:Refresh() end)
    end

    local search = self.search:GetText() or ""
    local key = ("all:%d:%s:%d"):format(everyone.version, search, self.openVersion or 0)
    if force or key ~= self.drawnKey then
        -- The same search keeps its place; a new one starts at the top.
        local keep = self.drawnKey ~= nil and search == self.drawnSearch
        self.drawnKey, self.drawnSearch = key, search
        local lines, shown = everyone:Lines(search, self.open)
        self.shownItems = shown
        self.list:SetData(lines, keep)
    end

    local text = ""
    if #everyone.sorted == 0 and (everyone.building or ns.Bags.scanning or everyone:IsStale()) then
        text = "Reading every character's items..."
    elseif #everyone.sorted == 0 then
        text = everyone:FromTradeskills() and "No items on record yet."
            or "Your bags are empty. Blackthornes Tradeskills keeps your other characters' items."
    elseif (self.shownItems or 0) == 0 then
        text = ('Nothing matches "%s".'):format(search)
    end
    self.emptyLabel:SetText(text)
    self.emptyLabel:SetShown(text ~= "")

    self:UpdateFooter()
end

function UI:UpdateFooter()
    if self.view == "all" then
        local everyone = ns.Everyone
        local text
        if not everyone:FromTradeskills() then
            text = "Only your bags. Load Blackthornes Tradeskills to add your other characters."
        else
            text = ("%s on %s. Bank and mail as each last saw them."):format(
                Plural(#everyone.sorted, "item", "items"),
                Plural(everyone:Holders(), "character", "characters"))
        end
        self.footer:SetText(text)
        return
    end
    local sell = ns.Verdicts:Group("sell")
    local text = ""
    if self.errandText then
        text = self.errandText
    elseif self.sellShown then
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
    self.sellRoom = shown and (width or 150) or nil
    self:FootRoom()
    if self:IsShown() then self:UpdateFooter() end
end

--- The footer's words stop short of whatever buttons sit at the foot, and
--- the version label gives way to them.
function UI:FootRoom()
    local room = math.max(self.sellRoom or 0, self.errandRoom or 0)
    self.versionLabel:SetShown(room == 0)
    self.footer:SetPoint("RIGHT", self.frame, "RIGHT", -(PADDING + (room > 0 and room + 12 or 90)), 0)
end

--- The mailbox and bank buttons, from what Errands offers now. Only on
--- Your bags.
function UI:UpdateErrands()
    if not self.frame then return end
    local offers = (self:IsShown() and self.view ~= "all") and ns.Errands:Offers() or { toBank = 0, fromBank = 0 }

    local mail = offers.mail
    self.mailButton:SetShown(mail ~= nil)
    if mail then self.mailButton:SetText(("Fill mail to %s"):format(mail.to)) end

    self.bankButton:SetShown(offers.toBank > 0)
    self.bankButton:SetText(("Move %d to bank"):format(offers.toBank))
    self.takeButton:SetShown(offers.fromBank > 0)
    self.takeButton:SetText("Take from bank")
    self.takeButton:ClearAllPoints()
    if offers.toBank > 0 then
        self.takeButton:SetPoint("RIGHT", self.bankButton, "LEFT", -6, 0)
    else
        self.takeButton:SetPoint("BOTTOMRIGHT", -UI.SELL_INSET_X, UI.SELL_INSET_Y)
    end

    local count = (mail and 1 or 0) + (offers.toBank > 0 and 1 or 0) + (offers.fromBank > 0 and 1 or 0)
    -- A button grows to fit a long label, so measure what is shown.
    local room = mail and (self.mailButton:GetWidth() or MAIL_WIDTH) or 0
    if offers.toBank > 0 then room = room + (self.bankButton:GetWidth() or ERRAND_WIDTH) end
    if offers.fromBank > 0 then room = room + (room > 0 and 6 or 0) + (self.takeButton:GetWidth() or ERRAND_WIDTH) end
    self.errandRoom = count > 0 and room or nil
    if mail then
        self.errandText = "Fills the Send Mail page. You press Send."
    elseif count > 0 then
        self.errandText = "Moves whole stacks, one at a time."
    else
        self.errandText = nil
    end
    self:FootRoom()
    if self:IsShown() then self:UpdateFooter() end
end

--------------------------------------------------------------------------------
-- At a vendor
--------------------------------------------------------------------------------

-- Whether the window waits for something to sell before it comes up at a
-- vendor. The owner asked (2026-10-10) for it at every vendor "for now",
-- and may want the wait back: setting this true restores it.
UI.ONLY_WITH_SALES = false

--- A vendor opened: come up by itself when the player wants that ("Open at
--- a vendor").
function UI:AtVendor()
    if self:IsShown() or not (ns.db and ns.db.openAtVendor) then return end
    if UI.ONLY_WITH_SALES then
        local sell = ns.Verdicts:Group("sell")
        if not (sell and sell.count > 0) then return end
    end
    self:Show("bags")
    self.openedByVendor = true
end

--- A mailbox ("mail") or the bank ("bank") opened: come up on Your bags
--- when the player wants that and there is something to do there.
function UI:AtPlace(place)
    if self:IsShown() then return self:UpdateErrands() end
    local setting = place == "mail" and "openAtMailbox" or "openAtBank"
    if not (ns.db and ns.db[setting]) then return end
    if not ns.Errands:HasWork(place) then return end
    self:Show("bags")
    self.openedFor = place
end

--- The mailbox or bank closed: a window that came up for it goes with it.
function UI:LeftPlace(place)
    if self.openedFor == place then
        self.openedFor = nil
        self:Hide()
    else
        self:UpdateErrands()
    end
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

--- Bring the window up, on `view` ("bags" or "all") when one is given.
function UI:Show(view)
    self:Build()
    if view then self:SetView(view) end
    if not self.frame:IsShown() then
        -- Ask the other addons afresh each time the window opens: a goal
        -- met, a craft queued or a level gained since the last look.
        ns.Verdicts:Forget()
        ns.Everyone:Changed()
        self:RestorePosition()
        self.frame:Show()
        ns.Motion:Open(self.frame)
        -- A light runs round the portrait as it opens.
        if ns.Titanforged then ns.Titanforged:Opened(self.frame) end
        -- The window rises a few pixels as it opens: place the Sell button
        -- again once it has landed.
        C_Timer.After(0.25, function()
            if ns.Selling then ns.Selling:Update() end
        end)
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

ns.RegisterCommand("all", "every character's items in one list, with where each one is", function()
    if UI:IsShown() and UI.view == "all" then
        UI:Hide()
    else
        UI:Show("all")
    end
end)
