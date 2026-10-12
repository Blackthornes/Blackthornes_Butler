-- Blackthornes Butler -- UI/MainWindow.lua
-- The Butler window: every item in your bags and what to do with it, in
-- groups (Sell, Look at it, Keep), each with its count and what it is worth.
--
-- It is what a click on the minimap button and a bare /bbutler open, and it
-- comes up by itself at every vendor and goes when the vendor closes (the
-- "Open at a vendor" setting). The Sell button (Logic/Selling.lua) sits over
-- its foot while a vendor is open, and the Disenchant button
-- (Logic/Disenchanting.lua) left of it while there is something to break.
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
local L = ns.L

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
local WIDTH = 620
local HEIGHT = 500
-- Tall enough for a reason or a name on two lines: words wrap, never cut
-- short with "..." (a player found a sell reason cut off, 2026-10-11).
local ROW_HEIGHT = 30
-- From the well's foot to the window's.
local FOOT = 40

-- Where the Sell button sits: in from the window's right edge and up from
-- its foot (Selling:Place).
UI.SELL_INSET_X = PADDING
UI.SELL_INSET_Y = 9

-- The mailbox and bank buttons' widths; Fill mail carries a name.
local ERRAND_WIDTH = 140
local MAIL_WIDTH = 180

-- The window's size, dragged at the grip below its bottom right corner as
-- in Tradeskills' window and Equipment's upgrade quest panel. Saved as
-- `windowScale`, account wide.
local SCALE_MIN = 0.6
local SCALE_MAX = 1.5
local GRIP_SIZE = 20

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
    frame:SetScale(self:GetWindowScale())
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
        -- Closed by the player (close gem, Escape, /bbutler, the minimap
        -- button), not by leaving the vendor, mailbox or bank it came up for.
        if UI.closingByItself then
            UI.closingByItself = false
        else
            UI:Say("close")
        end
        UI.dragging = false
        UI.openedByVendor = false
        UI.openedFor = nil
        UI:HideMenu()
        if ns.Selling then ns.Selling:Update() end
        if ns.Errands then ns.Errands:TellTradeskills(false) end
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
        -- Log out follows the next character's row as the list scrolls.
        onRefresh = function() if ns.Jobs then ns.Jobs:UpdateLogout() end end,
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
    self.mailButton = Widgets.CreateButton(frame, L["Fill mail"], Run(ns.Errands.FillMail),
        { width = MAIL_WIDTH, height = 24, primary = true })
    self.mailButton:SetPoint("BOTTOMRIGHT", -UI.SELL_INSET_X, UI.SELL_INSET_Y)
    self.mailButton.tooltipText = L["Fills the game's Send Mail page. Check it, then press Send."]
    self.mailButton:Hide()

    self.bankButton = Widgets.CreateButton(frame, L["Move to bank"], Run(ns.Errands.MoveToBank),
        { width = ERRAND_WIDTH, height = 24, primary = true })
    self.bankButton:SetPoint("BOTTOMRIGHT", -UI.SELL_INSET_X, UI.SELL_INSET_Y)
    self.bankButton.tooltipText = L["Puts your Always bank items in the bank, a stack at a time"]
    self.bankButton:Hide()

    self.takeButton = Widgets.CreateButton(frame, L["Take from bank"], Run(ns.Errands.TakeFromBank),
        { width = ERRAND_WIDTH, height = 24 })
    self.takeButton.tooltipText = L["Takes out what your craft queue still needs, in whole stacks"]
    self.takeButton:Hide()

    self:BuildSizeGrip()

    -- A new frame starts shown, so this Hide runs OnHide: it is no close by
    -- the player, and must not say Moroes's closing line (both lines played
    -- on the first open, 2026-10-11).
    self.closingByItself = true
    frame:Hide()
    self.closingByItself = false
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
    local search = Widgets.CreateSearchBox(header, L["Search all characters"], function()
        UI:Refresh()
    end)
    search:SetPoint("LEFT", header, "LEFT", 48, -2)
    search:SetWidth(230)
    search:Hide()
    self.search = search

    -- Below the close gem on the corner.
    local settings = Widgets.CreateButton(header, L["Settings"], function()
        if ns.SettingsUI then ns.SettingsUI:Toggle() end
    end, { width = 70, height = 20 })
    settings:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 4)

    -- Between the two lists.
    local view = Widgets.CreateButton(header, L["All characters"], function()
        UI:SetView(UI.view == "all" and "bags" or "all")
    end, { width = 110, height = 20 })
    view:SetPoint("RIGHT", settings, "LEFT", -6, 0)
    view.tooltipText = L["Every character's items, and where each one is"]
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
    self.viewButton:SetText(all and L["Your bags"] or L["All characters"])
    self.viewButton.tooltipText = all and L["What to do with each item in your bags"]
        or L["Every character's items, and where each one is"]

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
    row.name:SetPoint("LEFT", 34, 0)
    row.name:SetWidth(184)
    row.name:SetWordWrap(true)

    row.worth = Theme.CreateLabel(row, "small", "text", "RIGHT")
    row.worth:SetPoint("RIGHT", -6, 0)
    row.worth:SetWidth(96)

    row.reason = Theme.CreateLabel(row, "small", "muted")
    row.reason:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.reason:SetPoint("RIGHT", row.worth, "LEFT", -8, 0)
    row.reason:SetWordWrap(true)

    -- The Ammo row's Fill button and a job's Craft button sit where the
    -- worth goes (Logic/Ammo.lua, Logic/Jobs.lua).
    row.action = Widgets.CreateButton(row, L["Fill"], function() UI.RowAction(row.data) end, {
        primary = true, width = 80, height = 22,
    })
    row.action:SetPoint("RIGHT", -8, 0)
    row.action:Hide()
end

--- The row's button: Fill on the Ammo row, Craft on a job.
function UI.RowAction(data)
    if not data then return end
    if data.type == "ammo" then
        ns.Ammo:Buy()
    elseif data.type == "job" then
        ns.Jobs:Craft(data.step)
    end
end

local function Plural(count, one, many)
    return L.Format("%d %s", count, count == 1 and one or many)
end

function UI.UpdateRow(row, data)
    row.worth:SetTextColor(Theme.Unpack("text"))
    row.reason:SetTextColor(Theme.Unpack("muted"))
    if row.action then row.action:Hide() end
    if data.type == "ammo" then return UI.UpdateAmmoRow(row, data) end
    if data.type == "everyone" then return UI.UpdateItemRow(row, data) end
    if data.type == "holder" then return UI.UpdateHolderRow(row, data) end
    if data.type == "gold" then return UI.UpdateGoldRow(row, data) end
    if data.type == "job" then return UI.UpdateJobRow(row, data) end
    if data.type == "jobnext" then return UI.UpdateNextRow(row, data) end

    if data.type == "header" then
        local group = data.group
        row.icon:Hide()
        row.fold:Show()
        row.fold:SetText(data.folded and "+" or "-")
        row.name:SetTextColor(Theme.Unpack("accent"))
        row.name:SetText(group.label:upper())
        row.reason:SetText(Plural(group.count, group.one or L["item"], group.many or L["items"]))
        row.worth:SetText(group.worth > 0 and Items.FormatMoney(group.worth) or "")
        return
    end

    row.fold:Hide()
    row.icon:Show()
    row.icon:SetTexture(data.icon or [[Interface\Icons\INV_Misc_QuestionMark]])
    local color = QUALITY[data.quality or 1] or QUALITY[1]
    row.name:SetTextColor(color[1], color[2], color[3])
    row.name:SetText(data.count > 1 and L.Format("%s x%d", data.name, data.count) or data.name)
    row.reason:SetText(data.reason or "")
    -- Bought to disenchant reads in the tag's violet, as on Tradeskills' tab.
    if data.bought then
        row.reason:SetTextColor(0.73, 0.55, 1)
    else
        row.reason:SetTextColor(Theme.Unpack("muted"))
    end
    row.worth:SetText((data.worth or 0) > 0 and Items.FormatMoney(data.worth) or "")
end

--- A gold top-up: who it goes to, what they have and keep, and how much.
function UI.UpdateGoldRow(row, data)
    local entry = data.entry
    row.fold:Hide()
    row.icon:Show()
    row.icon:SetTexture([[Interface\Icons\INV_Misc_Coin_01]])
    row.name:SetTextColor(Theme.Unpack("text"))
    row.name:SetText(entry.to)
    row.reason:SetText(ns.Funds.Reason(entry))
    row.worth:SetText(Items.FormatMoney(entry.amount))
end

--- A step for the character playing: what to craft or mail, and why, with
--- a Craft button on a craft it has the materials for.
function UI.UpdateJobRow(row, data)
    local step = data.step
    local title, detail = ns.Jobs.StepText(step)
    row.fold:Hide()
    row.icon:Show()
    row.icon:SetTexture(ns.Jobs.Icon(step))
    row.name:SetTextColor(Theme.Unpack("text"))
    row.name:SetText(title)
    row.reason:SetText(detail)
    if step.kind == "craft" and not step.ready then row.reason:SetTextColor(Theme.Unpack("accent")) end
    row.worth:SetText("")
    if (step.kind == "craft" and step.ready) or (step.kind == "cooldown" and step.recipeID) then
        row.action:SetText(L["Craft"])
        row.action:Show()
    end
end

--- Another character with work waiting: who, and what they have to do.
function UI.UpdateNextRow(row, data)
    local job = data.job
    row.fold:Hide()
    row.icon:Show()
    row.icon:SetTexture([[Interface\Icons\Ability_Rogue_Disguise]])
    row.name:SetTextColor(Theme.Unpack(data.isNext and "accent" or "text"))
    row.name:SetText(data.isFirst and L.Format("First: %s", job.name)
        or data.isNext and L.Format("Next: %s", job.name) or L.Format("Then: %s", job.name))
    row.reason:SetText(ns.Jobs.Summary(job))
    row.worth:SetText("")
end

--- Filling the quiver or ammo pouch: the best ammo the vendor has, how
--- many fit and what they cost, and the Fill button when it can buy.
function UI.UpdateAmmoRow(row, data)
    local offer = data.offer
    row.fold:Hide()
    row.icon:Show()
    row.icon:SetTexture(offer.ammo.icon or [[Interface\Icons\INV_Ammo_Arrow_02]])
    row.name:SetTextColor(Theme.Unpack("text"))
    row.name:SetText(offer.ammo.name or L["Ammo"])
    row.reason:SetText(ns.Ammo.Reason(offer))
    if offer.state ~= "fill" then row.reason:SetTextColor(Theme.Unpack("accent")) end
    row.worth:SetText("")
    if offer.state == "fill" then
        row.action:SetText(ns.Ammo.buying and L["Buying..."] or L["Fill"])
        row.action:Show()
    end
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
        name = "    " .. L.Format("%s (you)", character.short)
    elseif character.linked then
        name = "    " .. L.Format("%s (other account)", character.short)
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
    -- At a vendor, filling a hunter's quiver or pouch comes first
    -- (Logic/Ammo.lua).
    local offer = ns.Ammo and ns.Ammo:Offer()
    if offer then
        local word = offer.bag and offer.bag.label or ns.Ammo.BAGS[offer.weapon.ammo].label
        local group = { verdict = "ammo", label = L["Ammo"], count = 1, worth = offer.cost or 0,
            one = word, many = word }
        local isFolded = folded.ammo == true
        lines[#lines + 1] = { type = "header", group = group, folded = isFolded }
        if not isFolded then lines[#lines + 1] = { type = "ammo", offer = offer } end
    end
    -- Jobs for the craft queue, here and on other characters
    -- (Logic/Jobs.lua).
    local jobRows = ns.Jobs and ns.Jobs:Lines() or {}
    if #jobRows > 0 then
        local group = { verdict = "jobs", label = L["Jobs"], count = #jobRows, worth = 0,
            one = L["step"], many = L["steps"] }
        local isFolded = folded.jobs == true
        lines[#lines + 1] = { type = "header", group = group, folded = isFolded }
        if not isFolded then
            for _, row in ipairs(jobRows) do lines[#lines + 1] = row end
        end
    end
    -- At a mailbox, the gold fund's top-ups come first (Logic/Funds.lua).
    if ns.Errands.mailOpen and ns.Funds then
        local plan = ns.Funds:Plan()
        if #plan > 0 then
            local worth = 0
            for _, entry in ipairs(plan) do worth = worth + entry.amount end
            local group = { verdict = "gold", label = L["Gold"], count = #plan, worth = worth,
                one = L["character"], many = L["characters"] }
            local isFolded = folded.gold == true
            lines[#lines + 1] = { type = "header", group = group, folded = isFolded }
            if not isFolded then
                for _, entry in ipairs(plan) do lines[#lines + 1] = { type = "gold", entry = entry } end
            end
        end
    end
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

-- The Ammo row's tooltip, one whole sentence per weapon (Logic/Ammo.lua's
-- internal words), so German can give each its own grammar.
UI.AMMO_BEST = {
    bow = L["The best ammo this vendor has for your bow at your level."],
    crossbow = L["The best ammo this vendor has for your crossbow at your level."],
    gun = L["The best ammo this vendor has for your gun at your level."],
}

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
    if data.type == "ammo" or data.type == "job" or data.type == "jobnext" then return end
    if button == "RightButton" and data.type ~= "gold" then
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
        GameTooltip:AddLine(data.folded and L["Click to show these"] or L["Click to fold these away"], 1, 1, 1, true)
        GameTooltip:Show()
        return
    end
    if data.type == "ammo" then
        local offer = data.offer
        local shown = offer.ammo.index and pcall(GameTooltip.SetMerchantItem, GameTooltip, offer.ammo.index)
        if not shown then GameTooltip:AddLine(offer.ammo.name or L["Ammo"], 1, 1, 1) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Butler: Ammo"], Theme.Unpack("accent"))
        GameTooltip:AddLine(ns.Ammo.Reason(offer), 1, 1, 1, true)
        GameTooltip:AddLine(UI.AMMO_BEST[offer.weapon.word] or L["The best ammo this vendor has for you at your level."],
            Theme.Unpack("muted"))
        GameTooltip:Show()
        return
    end
    if data.type == "job" then
        local step = data.step
        local title, detail = ns.Jobs.StepText(step)
        GameTooltip:AddLine(title, Theme.Unpack("accent"))
        GameTooltip:AddLine(detail, 1, 1, 1, true)
        if step.kind == "craft" or (step.kind == "cooldown" and step.recipeID) then
            GameTooltip:AddLine((step.ready or step.kind == "cooldown") and L["Craft makes it with your profession open; Tradeskills opens it otherwise."]
                or L["The Craft button comes once you have the materials."], Theme.Unpack("muted"))
        end
        GameTooltip:Show()
        return
    end
    if data.type == "jobnext" then
        local job = data.job
        GameTooltip:AddLine(job.name, Theme.Unpack("accent"))
        for _, step in ipairs(job.steps) do
            local line = ns.Jobs.Short(step)
            GameTooltip:AddLine(line:sub(1, 1):upper() .. line:sub(2), 1, 1, 1, true)
        end
        GameTooltip:AddLine(data.isNext and L["Log out on this line to switch to them."]
            or L["Do the steps above first."], Theme.Unpack("muted"))
        GameTooltip:Show()
        return
    end
    if data.type == "gold" then
        local entry = data.entry
        GameTooltip:AddLine(L.Format("Gold for %s", entry.to), Theme.Unpack("accent"))
        GameTooltip:AddLine(ns.Funds.Reason(entry), 1, 1, 1, true)
        GameTooltip:AddLine(L.Format("Fill mail sends %s. You press Send.", Items.FormatMoney(entry.amount)), 1, 1, 1, true)
        GameTooltip:AddLine(L["Gold is as last seen when they played. Set the amounts in Settings, Gold."],
            Theme.Unpack("muted"))
        GameTooltip:Show()
        return
    end

    local slot = data.slots[1]
    local shown = slot and pcall(GameTooltip.SetBagItem, GameTooltip, slot.bag, slot.slot)
    if not shown and data.link then pcall(GameTooltip.SetHyperlink, GameTooltip, data.link) end

    GameTooltip:AddLine(" ")
    local r, g, b = Theme.Unpack("accent")
    GameTooltip:AddLine(L.Format("Butler: %s", ns.Verdicts.LABELS[data.verdict] or data.verdict), r, g, b)
    if data.reason and data.reason ~= "" then
        GameTooltip:AddLine(data.reason, 1, 1, 1, true)
    end
    if data.bought then
        GameTooltip:AddLine(L.Format("%d bought on the auction house to disenchant", data.bought), 0.73, 0.55, 1)
    end
    GameTooltip:AddLine(L["Right-click to always keep, sell or bank it"], Theme.Unpack("muted"))
    GameTooltip:Show()
end

--- An item in All characters: the item's own tooltip, then who has it.
function UI:EnterEveryone(data)
    local item = data.item
    pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. item.itemID)
    GameTooltip:AddLine(" ")
    local r, g, b = Theme.Unpack("accent")
    GameTooltip:AddLine(L.Format("Butler: %d on %s", item.total,
        Plural(#item.holders, L["character"], L["characters"])), r, g, b)
    for _, holder in ipairs(item.holders) do
        GameTooltip:AddDoubleLine(holder.character.short, ns.Everyone.Where(holder), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(data.type == "holder" and L["Click to close"]
        or (data.open and L["Click to close"] or L["Click to see each character"]), Theme.Unpack("muted"))
    GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- The right-click menu
--
-- A small window of Butler's own, never the game's dropdown menus: Always
-- keep, Always sell, Always bank, Always mail to (which turns the menu into
-- a list of the player's characters), and Let Butler decide once one is
-- picked.
--------------------------------------------------------------------------------

local MENU_WIDTH = 170
local MENU_ROW = 24

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

    local function Pick(choice, to)
        local data = UI.menu.data
        UI:HideMenu()
        if data then ns.Verdicts:SetChoice(data.itemID, choice, to) end
    end
    menu.Pick = Pick

    menu.keep = Widgets.CreateButton(menu, L["Always keep"], function() Pick("keep") end,
        { width = MENU_WIDTH - 16, height = 20 })
    menu.keep:SetPoint("TOPLEFT", 8, -26)
    menu.sell = Widgets.CreateButton(menu, L["Always sell"], function() Pick("sell") end,
        { width = MENU_WIDTH - 16, height = 20 })
    menu.sell:SetPoint("TOPLEFT", menu.keep, "BOTTOMLEFT", 0, -4)
    menu.bank = Widgets.CreateButton(menu, L["Always bank"], function() Pick("bank") end,
        { width = MENU_WIDTH - 16, height = 20 })
    menu.bank:SetPoint("TOPLEFT", menu.sell, "BOTTOMLEFT", 0, -4)
    -- Bought to disenchant: Tradeskills keeps the mark, for the whole account.
    menu.bought = Widgets.CreateButton(menu, L["Bought to disenchant"], function()
        local data = UI.menu.data
        UI:HideMenu()
        if not data then return end
        local done, why = ns.Sisters:MarkBought(data.itemID, not data.bought, data.count)
        if not done then
            if why then ns.Print(why) end
            return
        end
        ns.Verdicts:Changed(true)
    end, { width = MENU_WIDTH - 16, height = 20 })
    menu.bought:SetPoint("TOPLEFT", menu.bank, "BOTTOMLEFT", 0, -4)
    menu.mail = Widgets.CreateButton(menu, L["Always mail to..."], function() UI:ShowMailMenu() end,
        { width = MENU_WIDTH - 16, height = 20 })
    menu.mail:SetPoint("TOPLEFT", menu.bank, "BOTTOMLEFT", 0, -4)
    menu.decide = Widgets.CreateButton(menu, L["Let Butler decide"], function() Pick(nil) end,
        { width = MENU_WIDTH - 16, height = 20 })
    -- An alt's upgrade under Mail: hold this one back from them, or every
    -- upgrade (the owner asked 2026-10-12). Undone in Settings.
    menu.hold = Widgets.CreateButton(menu, L["Don't mail this"], function()
        local data = UI.menu.data
        UI:HideMenu()
        if data and data.mailTo then ns.Verdicts:HoldUpgrade(data.itemID, data.mailTo, true) end
    end, { width = MENU_WIDTH - 16, height = 20 })
    menu.holdAll = Widgets.CreateButton(menu, L["Never mail upgrades"], function()
        local data = UI.menu.data
        UI:HideMenu()
        if data and data.mailTo then ns.Verdicts:HoldAllUpgrades(data.mailTo, true) end
    end, { width = MENU_WIDTH - 16, height = 20 })

    -- The characters page: one button a character, made as needed, and Back.
    menu.characters = {}
    menu.back = Widgets.CreateButton(menu, L["Back"], function()
        if UI.menu.data then UI:ShowMenu(UI.menu.data, true) end
    end, { width = MENU_WIDTH - 16, height = 20 })

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

--- Show the menu's main page for `data` (a row). `stay` keeps it where it
--- is, coming back from the characters page.
function UI:ShowMenu(data, stay)
    local menu = self:BuildMenu()
    menu.data = data
    menu.away = 0
    menu.title:SetText(data.name)

    for _, button in ipairs(menu.characters) do button:Hide() end
    menu.back:Hide()

    local choice, mailTo = ns.Verdicts:Choice(data.itemID)
    menu.keep:SetText(choice == "keep" and L["Always keep (now)"] or L["Always keep"])
    menu.sell:SetText(choice == "sell" and L["Always sell (now)"] or L["Always sell"])
    menu.bank:SetText(choice == "bank" and L["Always bank (now)"] or L["Always bank"])
    menu.mail:SetText(choice == "mail" and L.Format("Always mail to %s", mailTo) or L["Always mail to..."])
    menu.keep:Show()
    menu.sell:Show()
    menu.bank:Show()

    -- Mail needs Tradeskills to know the player's characters, and gear
    -- bound to this one can't be mailed at all.
    local canMail = choice == "mail" or (not data.bound and #ns.Errands:Characters() > 0)
    menu.mail:SetShown(canMail)

    -- Marked or unmarked through Tradeskills, so only with it loaded.
    local canMark = ns.Sisters.CanMarkBought()
    menu.bought:SetShown(canMark)
    menu.bought:SetText(data.bought and L["Bought to disenchant (now)"] or L["Bought to disenchant"])
    menu.mail:ClearAllPoints()
    menu.mail:SetPoint("TOPLEFT", canMark and menu.bought or menu.bank, "BOTTOMLEFT", 0, -4)

    local last = canMail and menu.mail or (canMark and menu.bought or menu.bank)
    local upgradeTo = data.upgrade and type(data.mailTo) == "string" and data.mailTo or nil
    menu.hold:SetShown(upgradeTo ~= nil)
    menu.holdAll:SetShown(upgradeTo ~= nil)
    if upgradeTo then
        menu.hold:SetText(L.Format("Don't mail this to %s", upgradeTo))
        menu.holdAll:SetText(L.Format("Never mail upgrades to %s", upgradeTo))
        menu.hold:ClearAllPoints()
        menu.hold:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
        menu.holdAll:ClearAllPoints()
        menu.holdAll:SetPoint("TOPLEFT", menu.hold, "BOTTOMLEFT", 0, -4)
        last = menu.holdAll
    end
    menu.decide:ClearAllPoints()
    menu.decide:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
    -- Also there for what Butler learned from the player (a buyback, a
    -- habit), which it forgets.
    local learned = choice == nil and ns.Learning and ns.Learning:Get(data.itemID) or nil
    local decides = choice ~= nil or learned ~= nil
    menu.decide:SetShown(decides)
    menu.decide:SetText(learned and L["Forget what Butler learned"] or L["Let Butler decide"])

    local rows = 3 + (canMark and 1 or 0) + (canMail and 1 or 0) + (upgradeTo and 2 or 0) + (decides and 1 or 0)
    menu:SetHeight(30 + rows * MENU_ROW)
    UI.FitMenu(menu, { menu.keep, menu.sell, menu.bank, menu.bought, menu.mail,
        menu.hold, menu.holdAll, menu.decide })

    if stay and menu:IsShown() then return end
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

--- The menu as wide as its widest button or title, so a long name (never
--- shortened) stays inside it; every shown button takes that width.
function UI.FitMenu(menu, buttons)
    local width = MENU_WIDTH - 16
    local title = menu.title and menu.title:GetText()
    if type(title) == "string" then width = math.max(width, Theme.TextWidth("small", title) or 0) end
    for _, button in ipairs(buttons) do
        if button:IsShown() then width = math.max(width, button:GetWidth() or 0) end
    end
    for _, button in ipairs(buttons) do
        if button:IsShown() then button:SetWidth(width) end
    end
    menu:SetWidth(width + 16)
end

--- The characters page: pick who this item always goes to.
function UI:ShowMailMenu()
    local menu = self.menu
    local data = menu and menu.data
    if not data then return end
    menu.away = 0

    local choice, mailTo = ns.Verdicts:Choice(data.itemID)
    local names = ns.Errands:Characters()
    menu.title:SetText(L.Format("Always mail %s to", data.name))

    menu.keep:Hide()
    menu.sell:Hide()
    menu.bank:Hide()
    menu.mail:Hide()
    menu.bought:Hide()
    menu.hold:Hide()
    menu.holdAll:Hide()
    menu.decide:Hide()

    local above
    for index, name in ipairs(names) do
        local button = menu.characters[index]
        if not button then
            button = Widgets.CreateButton(menu, name, function(self)
                menu.Pick("mail", self.character)
            end, { width = MENU_WIDTH - 16, height = 20 })
            menu.characters[index] = button
        end
        button.character = name
        button:SetText(choice == "mail" and mailTo == name and L.Format("%s (now)", name) or name)
        button:ClearAllPoints()
        if above then
            button:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -4)
        else
            button:SetPoint("TOPLEFT", 8, -26)
        end
        button:Show()
        above = button
    end
    for index = #names + 1, #menu.characters do menu.characters[index]:Hide() end

    menu.back:ClearAllPoints()
    if above then
        menu.back:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -4)
    else
        menu.back:SetPoint("TOPLEFT", 8, -26)
    end
    menu.back:Show()
    menu:SetHeight(30 + (#names + 1) * MENU_ROW)
    local buttons = { menu.back }
    for index = 1, #names do buttons[#buttons + 1] = menu.characters[index] end
    UI.FitMenu(menu, buttons)
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

    if ns.Ammo then ns.Ammo:Offer() end
    local key = ("%d:%d:%d:%d:%s:%s:%s"):format(ns.Bags.version, ns.Verdicts.version,
        ns.Funds and ns.Funds.version or 0, ns.Jobs and ns.Jobs.version or 0, tostring(ns.Errands.mailOpen),
        tostring(ns.Selling and ns.Selling.merchantOpen), tostring(ns.Ammo and ns.Ammo.offerKey))
    if force or key ~= self.drawnKey then
        local first = self.drawnKey == nil
        self.drawnKey = key
        self.list:SetData(self:Lines(), not first)
        -- The jobs may have moved: the footer's words with them.
        if ns.Jobs then self:FootRoom() end
    end

    local total = 0
    for _, entry in pairs(ns.Bags.slots) do total = total + 1 end
    self.subtitle:SetText(total > 0 and L.Format("Your bags: %s", Plural(total, L["stack"], L["stacks"])) or L["Your bags"])

    if total == 0 and (ns.Bags.scanning or ns.Bags.stale) then
        self.emptyLabel:SetText(L["Reading your bags..."])
    elseif total == 0 then
        self.emptyLabel:SetText(L["Your bags are empty."])
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
        text = L["Reading every character's items..."]
    elseif #everyone.sorted == 0 then
        text = everyone:FromTradeskills() and L["No items on record yet."]
            or L["Your bags are empty. Blackthornes Tradeskills keeps your other characters' items."]
    elseif (self.shownItems or 0) == 0 then
        text = L.Format('Nothing matches "%s".', search)
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
            text = L["Only your bags. Load Blackthornes Tradeskills to add your other characters."]
        else
            text = L.Format("%s on %s. Bank and mail as each last saw them.",
                Plural(#everyone.sorted, L["item"], L["items"]),
                Plural(everyone:Holders(), L["character"], L["characters"]))
        end
        self.footer:SetText(text)
        return
    end
    local sell = ns.Verdicts:Group("sell")
    local text = ""
    if self.errandText then
        text = self.errandText
    elseif ns.Jobs and ns.Jobs:DoneHere() then
        text = L["Everything here is done."]
    elseif self.sellShown then
        text = L["Sold items stay in the vendor's Buyback tab."]
    elseif sell and sell.count > 0 then
        text = L.Format("To sell: %s, %s. Open a vendor to sell them.",
            Plural(sell.count, L["item"], L["items"]), Items.FormatMoney(sell.worth))
    else
        text = L["Nothing to sell right now."]
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
    -- The Disenchant button goes left of those.
    local disenchant = ns.Disenchanting and ns.Disenchanting:Update(room) or 0
    if disenchant > 0 then room = room + (room > 0 and 6 or 0) + disenchant end
    -- The Log out button sits on the next character's row.
    if ns.Jobs then ns.Jobs:UpdateLogout() end
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
    if mail then self.mailButton:SetText(L.Format("Fill mail to %s", mail.to)) end

    self.bankButton:SetShown(offers.toBank > 0)
    self.bankButton:SetText(L.Format("Move %d to bank", offers.toBank))
    self.takeButton:SetShown(offers.fromBank > 0)
    self.takeButton:SetText(L["Take from bank"])
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
        self.errandText = L["Fills the Send Mail page. You press Send."]
    elseif count > 0 then
        self.errandText = L["Moves whole stacks, one at a time."]
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
    if self:IsShown() then
        -- Already up at a mailbox: Butler is the mailbox's window now, so it
        -- goes when the mailbox does (a player found it left up, 2026-10-11).
        if place == "mail" and not self.openedFor and not self.openedByVendor then
            self.openedFor = place
        end
        ns.Errands:TellTradeskills()
        return self:UpdateErrands()
    end
    local setting = place == "mail" and "openAtMailbox" or "openAtBank"
    if not (ns.db and ns.db[setting]) then return end
    -- At a mailbox Butler takes over from Tradeskills' mail panel, so it
    -- comes up every time; at the bank only with something to move.
    if place ~= "mail" and not ns.Errands:HasWork(place) then return end
    self:Show("bags")
    self.openedFor = place
    ns.Errands:TellTradeskills()
end

--- The mailbox or bank closed: a window that came up for it goes with it.
function UI:LeftPlace(place)
    if self.openedFor == place then
        self.openedFor = nil
        self.closingByItself = true
        self:Hide()
    else
        self:UpdateErrands()
    end
end

--- The vendor closed: a window that came up for it goes with it.
function UI:LeftVendor()
    if self.openedByVendor then
        self.openedByVendor = false
        self.closingByItself = true
        self:Hide()
    elseif ns.Selling then
        ns.Selling:Update()
    end
end

--------------------------------------------------------------------------------
-- Size
--------------------------------------------------------------------------------

function UI.ClampScale(value)
    value = tonumber(value)
    if not value or value ~= value then return 1 end
    value = math.max(SCALE_MIN, math.min(SCALE_MAX, value))
    return math.floor(value * 100 + 0.5) / 100
end

--- The largest size at which the whole window, portrait and corner gems
--- included, still fits on the screen.
function UI.FitScale()
    local ok, width, height = pcall(function()
        return UIParent:GetWidth(), UIParent:GetHeight()
    end)
    if not ok or type(width) ~= "number" or type(height) ~= "number"
        or width <= 0 or height <= 0 then
        return SCALE_MAX
    end
    local fit = math.min(width / (WIDTH + 40), height / (HEIGHT + 60))
    return math.max(SCALE_MIN, math.min(SCALE_MAX, math.floor(fit * 100) / 100))
end

--- The size the window is drawn at: the saved one, kept on the screen.
function UI:GetWindowScale()
    return math.min(UI.ClampScale(ns.db and ns.db.windowScale or 1), UI.FitScale())
end

function UI.ScaleText(scale)
    return ("%d%%"):format(math.floor((tonumber(scale) or 1) * 100 + 0.5))
end

--- Draw the window at `scale` with its top left corner where it was, so it
--- grows and shrinks toward the bottom right, as it does from the grip.
function UI:ApplyScale(scale)
    local frame = self.frame
    if not frame then return end
    scale = math.min(UI.ClampScale(scale), UI.FitScale())
    local old = frame:GetScale()
    if type(old) ~= "number" or old <= 0 then old = 1 end
    if math.abs(old - scale) < 0.001 then return end

    if ns.Motion and ns.Motion.Stop then pcall(ns.Motion.Stop, ns.Motion, frame, "open", true) end
    local left, top = frame:GetLeft(), frame:GetTop()
    frame:SetScale(scale)
    if type(left) == "number" and type(top) == "number" then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * old / scale, top * old / scale)
        self:SavePosition()
    end
    if ns.Selling then ns.Selling:Update() end
end

--- Save a size and draw the window at it.
function UI:SetWindowScale(value)
    local scale = UI.ClampScale(value)
    if ns.db then ns.db.windowScale = scale end
    self:ApplyScale(scale)
end

--- The grip below the bottom right corner: drag it to make the window
--- bigger or smaller, right-click it for the normal size. Only the
--- window's scale changes while dragging; the list is not filled again.
function UI:BuildSizeGrip()
    local frame = self.frame
    local below = 3
    if self.trim and ns.Titanforged and ns.Titanforged.Reach then
        local _, _, _, bottom = ns.Titanforged.Reach(self.trim)
        if type(bottom) == "number" then below = bottom + 3 end
    end

    local grip = Theme.CreatePanel(frame, "panel", "borderLit")
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -6, -below)
    grip:SetFrameLevel((frame:GetFrameLevel() or 0) + 20)
    grip:EnableMouse(true)
    if Theme.TopSheen then Theme.TopSheen(grip) end
    self.sizeGrip = grip

    -- Six gold dots in a stair down to the bottom right corner, the shape
    -- every resizable window in the game wears.
    local dots = {}
    for row = 0, 2 do
        for column = 2 - row, 2 do
            local dot = grip:CreateTexture(nil, "ARTWORK")
            dot:SetSize(3, 3)
            dot:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -3 - (2 - column) * 5, 3 + (2 - row) * 5)
            dot:SetColorTexture(Theme.Unpack("accent"))
            dots[#dots + 1] = dot
        end
    end

    local function Light(on)
        Theme.SetBorderColor(grip, on and "accent" or "borderLit")
        for _, dot in ipairs(dots) do
            dot:SetColorTexture(Theme.Unpack(on and "accentHi" or "accent"))
        end
    end

    local function Track(self)
        local cx, cy = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        if not (cx and cy and type(uiScale) == "number" and uiScale > 0) then return end
        cx, cy = cx / uiScale, cy / uiScale

        -- The size that keeps the cursor where it took hold of the grip:
        -- the width's and the height's answers averaged, so a drag off the
        -- diagonal still feels right.
        local width = cx - self.grabX - self.anchorLeft
        local height = self.anchorTop - (cy + self.grabY)
        local scale = UI.ClampScale((width / WIDTH + height / HEIGHT) / 2)
        scale = math.min(scale, self.fit)
        if math.abs(scale - (frame:GetScale() or 1)) < 0.005 then return end

        frame:SetScale(scale)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.anchorLeft / scale, self.anchorTop / scale)

        if GameTooltip:IsOwned(self) then
            GameTooltip:SetText(UI.ScaleText(scale), Theme.Unpack("accentHi"))
            GameTooltip:Show()
        end
    end

    local function StopSizing(self)
        if not self.sizing then return end
        self.sizing = false
        self:SetScript("OnUpdate", nil)
        UI.dragging = false
        if ns.db then ns.db.windowScale = UI.ClampScale(frame:GetScale()) end
        UI:SavePosition()
        if ns.Selling then ns.Selling:Update() end
    end

    grip:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            UI:SetWindowScale(1)
            return
        end
        if button ~= "LeftButton" then return end

        if ns.Motion and ns.Motion.Stop then pcall(ns.Motion.Stop, ns.Motion, frame, "open", true) end
        local scale = frame:GetScale() or 1
        local left, top = frame:GetLeft(), frame:GetTop()
        local cx, cy = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        if not (type(left) == "number" and type(top) == "number" and cx and cy
            and type(uiScale) == "number" and uiScale > 0) then
            return
        end

        -- All in the screen's units, which do not change with the window's.
        self.anchorLeft, self.anchorTop = left * scale, top * scale
        self.grabX = cx / uiScale - (self.anchorLeft + WIDTH * scale)
        self.grabY = (self.anchorTop - HEIGHT * scale) - cy / uiScale
        self.fit = UI.FitScale()

        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)

        -- The Sell button and the menu sit outside the window: out of the
        -- way until the drag ends, as when the window is moved.
        UI.dragging = true
        UI:HideMenu()
        if ns.Selling then ns.Selling:Update() end

        self.sizing = true
        self:SetScript("OnUpdate", Track)
    end)
    grip:SetScript("OnMouseUp", StopSizing)
    grip:SetScript("OnHide", StopSizing)

    grip:SetScript("OnEnter", function(self)
        Light(true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(UI.ScaleText(frame:GetScale()), Theme.Unpack("accentHi"))
        GameTooltip:AddLine(L["Drag to make the window bigger or smaller."], 1, 1, 1, true)
        GameTooltip:AddLine(L["Right-click: back to the normal size."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function()
        Light(false)
        GameTooltip:Hide()
    end)
    return grip
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
        if ns.Jobs then ns.Jobs:Changed() end
        self:RestorePosition()
        self.frame:Show()
        ns.Motion:Open(self.frame)
        if ns.Errands then ns.Errands:TellTradeskills() end
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
        self:Say("open")
    end
end

--------------------------------------------------------------------------------
-- Butler's voice
--
-- The owner asked (2026-10-11) for Moroes, Karazhan's butler, to answer when
-- the player opens Butler ("You rang?") and closes it ("Now, where was I?
-- Oh, yes..."): the game's own files, played by ID, so no sound ships here.
-- Never over an NPC: the client can't say when one is talking, so a line is
-- never said while a vendor, mailbox, bank or any NPC window is open, nor
-- when the window opens or closes by itself. Each line waits VOICE_GAP
-- seconds before it is said again. "Butler's voice" in Settings (`voice`,
-- account wide, on unless unticked).
--------------------------------------------------------------------------------

UI.VOICE = { open = 555818, close = 555814 }
UI.VOICE_GAP = 180
UI.voiceAt = {}

--- Is the player at a vendor, mailbox, bank or talking to any NPC?
function UI.AtAnNPC()
    if ns.Selling and ns.Selling.merchantOpen then return true end
    local errands = ns.Errands
    if errands and (errands.mailOpen or errands.bankOpen) then return true end
    if UI.openedByVendor or UI.openedFor then return true end
    local ok, talking = pcall(function() return UnitExists("npc") and true or false end)
    return ok and talking == true
end

--- Say Moroes's line for "open" or "close", when it may be said now.
function UI:Say(which)
    local id = self.VOICE[which]
    if not id or not (ns.db and ns.db.voice ~= false) then return false end
    if self.AtAnNPC() then return false end
    local ok, now = pcall(GetTime)
    if not (ok and type(now) == "number") then return false end
    local last = self.voiceAt[which]
    if last and now - last < self.VOICE_GAP then return false end
    ok = pcall(PlaySoundFile, id, "Dialog")
    if ok then self.voiceAt[which] = now end
    return ok
end

ns.RegisterCommand("window", L["open the Butler window (so does /bbutler on its own)"], function()
    UI:Toggle()
end)

ns.RegisterCommand("all", L["every character's items in one list, with where each one is"], function()

    if UI:IsShown() and UI.view == "all" then
        UI:Hide()
    else
        local wasShown = UI:IsShown()
        UI:Show("all")
        if not wasShown then UI:Say("open") end
    end
end)
