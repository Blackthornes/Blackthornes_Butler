-- Blackthornes Butler -- UI/Settings.lua
-- The settings window: every switch the addon has, in one place.
--
-- Built the way Tradeskills' Settings tab is (UI/SettingsPages.lua): pages
-- picked along the top, two columns of rows a page, a row being [label ..
-- control] on one line, and what it does in the row's tooltip or, with Show
-- descriptions ticked, underneath it.
--
-- Open it with /bbutler settings, a click on the minimap button, or from the
-- game's own Options > AddOns list. Nothing here deletes anything.

local _, ns = ...
local L = ns.L

local SettingsUI = ns.NewModule("SettingsUI")

local Theme = ns.Theme
local Widgets = ns.Widgets

local PADDING = 18
-- From the window's top to the gold rule under the header row.
local HEADER = 44
-- The metal rim sits on the window's edge and reaches this far inward, with
-- room to spare (UI/Titanforged.lua).
local EDGE_PAD = 11

local COLUMN_WIDTH = 330
local COLUMN_GAP = 18
-- Where the controls start: room for a label like "Minimap button" in the
-- game's font, which runs wider than it looks.
local CONTROL_X = 150

local TITLE = "Blackthornes Butler"

-- The pages along the top (UI/SettingsPages.lua), as Tradeskills' Settings
-- tab has them. Every setting kept its saved name; only its place moved.
local PAGES = {
    { key = "selling", text = L["ERRANDS"],
      tip = L["Selling at a vendor, mail and the bank, and your Always keep, sell and bank lists"] },
    { key = "gold", text = L["GOLD"],
      tip = L["A gold fund: how much each of your characters keeps, topped up by mail"] },
    { key = "general", text = L["GENERAL"],
      tip = L["The minimap button, window position, text size and debug output"] },
    { key = "about", text = L["ABOUT"],
      tip = L["How these addons are made, the version, the Discord and the other Blackthornes addons"] },
}

--- Put the settings window back where it started.
function SettingsUI:ResetPositions()
    ns.db.settingsPoint = nil
    ns.db.settingsRelativePoint = nil
    ns.db.settingsX = nil
    ns.db.settingsY = nil
    self:RestorePosition()
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

function SettingsUI:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "BlackthornesButlerSettings", UIParent)
    frame:SetSize(COLUMN_WIDTH * 2 + COLUMN_GAP + PADDING * 2, 600)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    Theme.Fill(frame, "window")

    -- The house frame (UI/Titanforged.lua): the gold rim, the name on a
    -- plate and the red close gem. No portrait: on a window this narrow it
    -- would sit over the first section's heading.
    if ns.Titanforged then
        local trim = ns.Titanforged:Dress(frame, {
            title = TITLE,
            close = function() SettingsUI:Hide() end,
        })
        self.trim = trim

        local left, right, top, bottom = ns.Titanforged.Reach(trim)
        if frame.SetClampRectInsets then
            frame:SetClampRectInsets(-left, right, top, -bottom)
        end
    else
        Theme.Border(frame, "borderLit")
    end

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SettingsUI:SavePosition()
    end)

    -- Escape closes it, like the game's own windows.
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "BlackthornesButlerSettings")
    end

    self.frame = frame
    self.controls = {}

    self:BuildHeader()

    self.pages = ns.SettingsPages.New(frame, {
        pages = PAGES,
        top = HEADER + 4,
        bottom = 40,
        padding = PADDING,
        columnWidth = COLUMN_WIDTH,
        columnGap = COLUMN_GAP,
        controlX = CONTROL_X,
        db = function() return ns.db end,
    })
    self:BuildPages()
    -- About (UI/About.lua): the note on how the addons are made, then the
    -- version, the Discord and the other Blackthornes addons.
    if ns.About then
        local pages = self.pages
        pages:Section("about", 1, L["HOW THESE ADDONS ARE MADE"])
        local note = pages:Place("about", 1, ns.About:Note(pages.pages.about.content, COLUMN_WIDTH))
        pages:Searchable("about", note, note.words)
        pages:Section("about", 2, L["ABOUT"])
        local info = pages:Place("about", 2, ns.About:Info(pages.pages.about.content, COLUMN_WIDTH))
        pages:Searchable("about", info, info.words)
    end
    self.pages:Fit()

    local footer = Theme.CreateLabel(frame, "tiny", "dim")
    footer:SetPoint("BOTTOMLEFT", PADDING, 14)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, 14)
    footer:SetText(L["Changes save as you make them."])
    self.footer = footer

    frame:Hide()
    return frame
end

--- The header row. The addon's name is on the plate across the top edge
--- and the close gem sits on the top right corner (UI/Titanforged.lua), so
--- the row says which page this is and which version is running.
function SettingsUI:BuildHeader()
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

    local subtitle = Theme.CreateLabel(header, "small", "muted")
    subtitle:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", PADDING - EDGE_PAD, 7)
    subtitle:SetText(L["Settings"])

    local version = Theme.CreateLabel(header, "tiny", "dim", "RIGHT")
    version:SetText(ns.VersionLabel())
    version:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -(PADDING - EDGE_PAD), 8)
end

--- A row whose button runs a /bbutler command, so every command has a button
--- here (a house rule).
local function CommandRow(pages, page, column, label, description, buttonText, command)
    local row = pages:Row(page, column, label, description)
    local button = Widgets.CreateButton(row, buttonText, function()
        ns.HandleSlash(command)
    end, { width = 100, height = 20 })
    button:SetPoint("TOPLEFT", CONTROL_X, 0)
    return row, button
end

-- The window styles, in the order the stepper steps through them.
local STYLES = { "titanforged", "blizzard" }
local STYLE_LABELS = { titanforged = "Titanforged", blizzard = "Blizzard" }

--- Titanforged or Blizzard, with Reload under it while the pick differs
--- from what is drawn, as the Text size row has. Butler has no dropdown, so
--- it is a stepper like Text size.
function SettingsUI.WindowStyleControl(row, x)
    local reload
    local function Drawn()
        local Look = ns.BlizzardLook
        return Look and Look.Style() or "titanforged"
    end

    local stepper = Widgets.CreateStepper(row, {
        min = 1, max = #STYLES, step = 1,
        format = function(value) return STYLE_LABELS[STYLES[value]] end,
        onChange = function(value)
            ns.db.windowStyle = STYLES[value]
            reload:SetShown(STYLES[value] ~= Drawn())
        end,
    })
    -- As wide as "Titanforged" at the player's text size, with Reload under
    -- it: at 100 with Reload beside it, the word spilled out of its box and
    -- Reload out of the column (a player's report, 2026-10-13).
    ns.SettingsPages.FitStepper(stepper, STYLE_LABELS)
    stepper:SetPoint("TOPLEFT", x, -2)

    -- ReloadUI is allowed from a click, and saves everything first.
    reload = Widgets.CreateButton(row, L["Reload now"], function()
        if ReloadUI then ReloadUI() end
    end, { width = 60, height = 20 })
    ns.SettingsPages.ReloadUnder(row, stepper, reload)
    reload:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Reload the interface so the new window style shows (/reload)"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    reload:HookScript("OnLeave", function() GameTooltip:Hide() end)
    reload:Hide()
    stepper.reload = reload

    function stepper:Sync()
        local Look = ns.BlizzardLook
        local wanted = Look and Look.Wanted() or "titanforged"
        self:SetValue(wanted == "blizzard" and 2 or 1, true)
        reload:SetShown(wanted ~= Drawn())
    end

    return stepper
end

--- Steps through the player's characters on this realm and side, by full
--- name, wrapped rather than cut short. :SetNames(list), :GetName().
function SettingsUI.CharacterPicker(row, x, onChange)
    local picker = CreateFrame("Frame", nil, row)
    picker:SetSize(180, 24)
    picker:SetPoint("TOPLEFT", x, 0)
    picker.names, picker.index = {}, 1

    local text = Theme.CreateLabel(picker, "small", "text", "CENTER")
    text:SetPoint("LEFT", 26, 0)
    text:SetPoint("RIGHT", -26, 0)
    text:SetWordWrap(true)

    local function Show()
        local count = #picker.names
        picker.index = math.max(1, math.min(picker.index, math.max(1, count)))
        text:SetText(picker.names[picker.index] or L["No characters yet"])
        picker.prev:SetLabelColor(picker.index <= 1 and "dim" or nil)
        picker.next:SetLabelColor(picker.index >= count and "dim" or nil)
    end

    local function Step(direction)
        local wanted = picker.index + direction
        if wanted < 1 or wanted > #picker.names then return end
        picker.index = wanted
        Show()
        if onChange then onChange() end
    end

    picker.prev = Widgets.CreateButton(picker, "<", function() Step(-1) end, { width = 22, height = 20 })
    picker.prev:SetPoint("LEFT", 0, 0)
    picker.next = Widgets.CreateButton(picker, ">", function() Step(1) end, { width = 22, height = 20 })
    picker.next:SetPoint("RIGHT", 0, 0)

    function picker:SetNames(names)
        local current = self.names[self.index]
        self.names = names
        self.index = 1
        for index, name in ipairs(names) do
            if name == current then self.index = index end
        end
        Show()
    end

    function picker:GetName()
        return self.names[self.index]
    end

    Show()
    return picker
end

--- The picked character's own amount (or the usual) in its money box.
function SettingsUI:SyncGoldFor()
    local controls = self.controls
    if not (controls and controls.goldPick) then return end
    local name = controls.goldPick:GetName()
    local own = name and ns.Funds:Override(name)
    controls.goldFor:SetValue(own or (name and ns.Funds:MinimumFor(name)) or 0)
    controls.goldUsual:SetShown(own ~= nil)
end

--- The picked character's upgrade mail: the tick, and Undo with how many
--- items are held back (dim with none).
function SettingsUI:SyncHeld()
    local controls = self.controls
    if not (controls and controls.heldPick) then return end
    local name = controls.heldPick:GetName()
    controls.heldAll:SetChecked(not (name and (ns.db.noUpgradesFor or {})[name]))
    local count = name and #ns.Verdicts:HeldItems(name) or 0
    controls.heldItems:SetText(count > 0 and L.Format("Undo %d", count) or L["None"])
    controls.heldItems:SetLabelColor(count == 0 and "dim" or nil)
end

function SettingsUI:BuildPages()
    local controls = self.controls
    local pages = self.pages

    -- Selling: the vendor on the left, the player's lists on the right.
    pages:Section("selling", 1, L["AT A VENDOR"])

    local vendorRow = pages:Row("selling", 1, L["Open at a vendor"],
        L["The Butler window opens at every vendor and closes when you leave. Nothing sells until you click Sell. Also /bbutler vendor."])
    controls.openAtVendor = Widgets.CreateCheckbox(vendorRow, L["On"], function(checked)
        ns.db.openAtVendor = checked
    end, true)
    controls.openAtVendor:SetPoint("TOPLEFT", CONTROL_X, -2)

    local testRow, testButton = CommandRow(pages, "selling", 1, L["Test selling"],
        L["At a vendor, sells your cheapest grey item from Butler's own code to see whether the game allows it. If it does, Sell sells up to 12 a click; if not, one stack a click. Same as /bbutler selltest."],
        L["Test it"], "selltest")
    controls.sellTest = testButton
    controls.sellTestRow = testRow

    pages:Section("selling", 1, L["MAIL AND BANK"])

    local mailRow = pages:Row("selling", 1, L["Open at a mailbox"],
        L["The Butler window opens at every mailbox in place of Tradeskills' mail panel; close it to get the panel back. Fill mail, on each character's line, fills the game's Send Mail page for that character, and you press Send. Needs Blackthornes Tradeskills. Also /bbutler mailbox."])
    controls.openAtMailbox = Widgets.CreateCheckbox(mailRow, L["On"], function(checked)
        ns.db.openAtMailbox = checked
    end, true)
    controls.openAtMailbox:SetPoint("TOPLEFT", CONTROL_X, -2)

    local nextRow = pages:Row("selling", 1, L["Fill the next mail"],
        L["After you send a mail Butler filled, it fills the next character's mail. You still press Send each time. Also /bbutler fillnext."])
    controls.fillNext = Widgets.CreateCheckbox(nextRow, L["On"], function(checked)
        ns.db.fillNext = checked
    end, true)
    controls.fillNext:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Jobs for the craft queue on other characters (Logic/Jobs.lua, asked
    -- 2026-10-11).
    local jobRow = pages:Row("selling", 1, L["Jobs at login"],
        L["Logging in on a character with a job for Tradeskills' craft queue (craft this, mail that) brings the Butler window up on its steps. Also /bbutler joblogin."])
    controls.jobsAtLogin = Widgets.CreateCheckbox(jobRow, L["On"], function(checked)
        ns.db.jobsAtLogin = checked
    end, true)
    controls.jobsAtLogin:SetPoint("TOPLEFT", CONTROL_X, -2)

    CommandRow(pages, "selling", 1, L["Every character's jobs"],
        L["Lists in chat what each of your characters has to craft or mail for Tradeskills' craft queue. Also /bbutler jobs."], L["List"], "jobs")

    local bankRow = pages:Row("selling", 1, L["Open at the bank"],
        L["The Butler window comes up at the bank when there is something to move: Move to bank puts your Always bank items away, and Take from bank brings out what your craft queue needs. Also /bbutler bank."])
    controls.openAtBank = Widgets.CreateCheckbox(bankRow, L["On"], function(checked)
        ns.db.openAtBank = checked
    end, true)
    controls.openAtBank:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Asked 2026-10-11: anything worth less than this joins Sell. It only
    -- ever adds to Sell; nothing sells until the player clicks.
    pages:Section("selling", 2, L["JUNK"])

    local belowRow = pages:Row("selling", 2, L["Sell below"],
        L["Anything worth less than this goes under Sell, by the most a vendor, the auction house or a disenchant would give for it. Never quest items, upgrades, goal or craft materials, pet food, soulbound green or better gear, or your Always keep, bank and mail items. Nothing sells until you click Sell. Needs Blackthornes Tradeskills for auction prices. 0 is off. Also /bbutler sellbelow 50s."])
    controls.sellBelow = Widgets.CreateMoneyBox(belowRow, function(copper)
        ns.Verdicts:SetSellBelow(copper)
    end)
    controls.sellBelow:SetPoint("TOPLEFT", CONTROL_X, 0)

    pages:Section("selling", 2, L["YOUR LISTS"])

    local learnRow = pages:Row("selling", 2, L["Learn from what you do"],
        L["Butler learns from what you do. Buy back something it sold and it keeps it from then on. Sell an item yourself at a vendor on two visits and it goes under Sell. Mail an item to the same character twice and it goes under Mail to them. Your own right-click choices always win, and right-click shows Forget what Butler learned. Nothing is sold or sent without your click."])
    controls.learn = Widgets.CreateCheckbox(learnRow, L["On"], function(checked)
        ns.db.learn = checked
        ns.Verdicts:Changed(true)
    end)
    controls.learn:SetPoint("TOPLEFT", CONTROL_X, -2)

    local _, listsButton = CommandRow(pages, "selling", 2, L["Keep, sell, bank, mail"],
        L["Right-click an item in the Butler window to always keep it, sell it, bank it or mail it to one of your characters. This lists all four in chat, and what Butler learned from you. To empty them, type /bbutler reset confirm. Same as /bbutler lists."],
        L["List them"], "lists")
    controls.lists = listsButton

    -- Upgrades held back from a character (the owner asked 2026-10-12):
    -- right-click an upgrade under Mail to hold it back; undone here.
    pages:Section("selling", 2, L["UPGRADES FOR YOUR CHARACTERS"])

    local altRow = pages:Row("selling", 2, L["Mail upgrades to your characters"],
        L["Gear that is no use here but an upgrade for another of your characters goes under Mail to them, so Fill mail sends it. Off unless you tick it. Needs Blackthornes Equipment. Also /bbutler altupgrades."])
    controls.altUpgrades = Widgets.CreateCheckbox(altRow, L["On"], function(checked)
        ns.Verdicts:SetAltUpgrades(checked)
    end)
    controls.altUpgrades:SetPoint("TOPLEFT", CONTROL_X, -2)

    local heldRow = pages:Row("selling", 2, L["Character"],
        L["Pick one of your characters to see what you hold back from them. Right-click an upgrade under Mail to hold back that item, or every upgrade, from the character it was going to."])
    controls.heldPick = SettingsUI.CharacterPicker(heldRow, CONTROL_X, function()
        SettingsUI:SyncHeld()
    end)

    local allRow = pages:Row("selling", 2, L["Mail them upgrades"],
        L["Untick to stop Butler offering this character any upgrades by mail. Your own Always mail picks still go to them."])
    controls.heldAll = Widgets.CreateCheckbox(allRow, L["On"], function(checked)
        local name = controls.heldPick:GetName()
        if name then ns.Verdicts:HoldAllUpgrades(name, not checked) end
    end)
    controls.heldAll:SetPoint("TOPLEFT", CONTROL_X, -2)

    local itemsRow = pages:Row("selling", 2, L["Items held back"],
        L["The items you said not to mail to this character. Undo lets them go as upgrades again."])
    controls.heldItems = Widgets.CreateButton(itemsRow, L["Undo"], function()
        local name = controls.heldPick:GetName()
        if not name then return end
        for _, itemID in ipairs(ns.Verdicts:HeldItems(name)) do
            ns.Verdicts:HoldUpgrade(itemID, name, false)
        end
        SettingsUI:SyncHeld()
    end, { width = 100, height = 20 })
    controls.heldItems:SetPoint("TOPLEFT", CONTROL_X, 0)

    local _, heldButton = CommandRow(pages, "selling", 2, L["Everyone held back"],
        L["Lists in chat every upgrade you hold back, and from whom. Same as /bbutler upgrademail."],
        L["List them"], "upgrademail")
    controls.heldList = heldButton

    -- Gold: the gold fund (the owner asked 2026-10-11). The usual amount on
    -- the left, one character's own on the right. Logic/Funds.lua.
    pages:Section("gold", 1, L["GOLD FUND"])

    local minRow = pages:Row("gold", 1, L["Keep at least"],
        L["Every character keeps this much gold. At a mailbox, a character with more can send gold to each one below it, without dropping under its own amount. Fill mail fills it; you press Send. Needs Blackthornes Tradeskills, which keeps your characters' gold as last seen. 0 is off. Also /bbutler goldmin 50g."])
    controls.goldMinimum = Widgets.CreateMoneyBox(minRow, function(copper)
        ns.Funds:SetMinimum(copper)
    end)
    controls.goldMinimum:SetPoint("TOPLEFT", CONTROL_X, 0)

    local _, goldButton = CommandRow(pages, "gold", 1, L["Everyone's gold"],
        L["Lists in chat each character's gold as last seen, what it keeps and what the fund would send it. Same as /bbutler gold."],
        L["List it"], "gold")
    controls.goldReport = goldButton

    -- Class spells to train (Logic/ClassTraining.lua, the owner said build
    -- it 2026-10-13).
    pages:Section("gold", 1, L["CLASS TRAINING"])

    local trainingRow = pages:Row("gold", 1, L["Class training"],
        L["Spells you can train lead the Jobs list with what they cost, Train all shows at your class trainer, and a level up says in chat what's new. The gold fund keeps that gold back. Prices and the trainer's place are kept the first time you open a class trainer. Also /bbutler training on or off."])
    controls.classTraining = Widgets.CreateCheckbox(trainingRow, L["On"], function(checked)
        ns.ClassTraining:SetOn(checked)
        ns.Funds:Changed()
    end, true)
    controls.classTraining:SetPoint("TOPLEFT", CONTROL_X, -2)

    local _, trainingButton = CommandRow(pages, "gold", 1, L["Spells to train"],
        L["Lists in chat the spells you can train now, what each costs, the next level's and your other characters'. Same as /bbutler training."],
        L["List them"], "training")
    controls.trainingReport = trainingButton

    -- Gold goals at the bottom of the window (Logic/GoldGoals.lua, the
    -- owner said build it 2026-10-13).
    pages:Section("gold", 1, L["GOLD GOALS"])

    local goalsRow = pages:Row("gold", 1, L["Gold goals"],
        L["The bottom of the window shows what your gold is for next: class spells, profession training and riding, each with a bar of your purse against its price. Gold the gold fund sets aside for your other characters isn't counted. Also /bbutler goals on or off."])
    controls.goldGoals = Widgets.CreateCheckbox(goalsRow, L["On"], function(checked)
        ns.GoldGoals:SetOn(checked)
    end, true)
    controls.goldGoals:SetPoint("TOPLEFT", CONTROL_X, -2)

    local _, goalsButton = CommandRow(pages, "gold", 1, L["Your goals"],
        L["Lists in chat your gold goals and how far along each is. Same as /bbutler goals."],
        L["List them"], "goals")
    controls.goalsReport = goalsButton

    pages:Section("gold", 2, L["ONE CHARACTER"])

    local pickRow = pages:Row("gold", 2, L["Character"],
        L["Pick one of your characters to give it an amount of its own."])
    controls.goldPick = SettingsUI.CharacterPicker(pickRow, CONTROL_X, function()
        SettingsUI:SyncGoldFor()
    end)

    local ownRow = pages:Row("gold", 2, L["They keep"],
        L["This character's own amount, in place of the usual. 0 means it keeps nothing back, so it can give all it has."])
    controls.goldFor = Widgets.CreateMoneyBox(ownRow, function(copper)
        local name = controls.goldPick:GetName()
        if name then ns.Funds:SetMinimumFor(name, copper) end
    end)
    controls.goldFor:SetPoint("TOPLEFT", CONTROL_X, 0)

    local usualRow = pages:Row("gold", 2, L["Back to the usual"],
        L["This character keeps the usual amount again."])
    controls.goldUsual = Widgets.CreateButton(usualRow, L["Use the usual"], function()
        local name = controls.goldPick:GetName()
        if name then ns.Funds:SetMinimumFor(name, nil) end
        SettingsUI:SyncGoldFor()
    end, { width = 100, height = 20 })
    controls.goldUsual:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- General: windows and text on the left, debug on the right.
    pages:Section("general", 1, L["WINDOWS"])

    local windowRow = pages:Row("general", 1, L["Butler window"],
        L["What to do with each item in your bags. Same as /bbutler window, or /bbutler on its own."])
    controls.openWindow = Widgets.CreateButton(windowRow, L["Open it"], function()
        ns.HandleSlash("window")
    end, { width = 100, height = 20, primary = true })
    controls.openWindow:SetPoint("TOPLEFT", CONTROL_X, 0)

    local _, allButton = CommandRow(pages, "general", 1, L["All characters"],
        L["Every character's items in one list, with who has each and whether it is in their bags, bank or mail. Needs Blackthornes Tradeskills for the other characters. Same as /bbutler all."],
        L["Show them"], "all")
    controls.all = allButton

    local minimapRow = pages:Row("general", 1, L["Minimap button"],
        L["Click it for the Butler window, right-click for this page. Drag it to move it. Also /bbutler minimap."])

    controls.minimap = Widgets.CreateCheckbox(minimapRow, L["Show it"], function(checked)
        ns.db.minimapHidden = not checked
        if ns.MinimapButton then ns.MinimapButton:ApplyVisibility() end
    end, true)
    controls.minimap:SetPoint("TOPLEFT", CONTROL_X, -2)

    local spaceRow = pages:Row("general", 1, L["Free bag space"],
        L["How many bag slots are free, as a number on the backpack button of your bag bar: white, amber at 8 or fewer, red at 3 or fewer. Hover the button for each bag. Profession and reagent bags are listed but not counted. Also /bbutler freespace."])
    controls.freeSpace = Widgets.CreateCheckbox(spaceRow, L["Show it"], function(checked)
        if ns.FreeSpace then ns.FreeSpace:SetEnabled(checked) end
    end, true)
    controls.freeSpace:SetPoint("TOPLEFT", CONTROL_X, -2)

    local trashRow = pages:Row("general", 1, L["Trash can when full"],
        L["When your bags are full, a small gold can sits on the item worth the least that Butler would sell anyway. Click it to pick the item up, then drop it outside your bags; the game asks before anything is destroyed. Also /bbutler trash."])
    controls.trashCan = Widgets.CreateCheckbox(trashRow, L["Show it"], function(checked)
        if ns.Trash then ns.Trash:SetEnabled(checked) end
    end, true)
    controls.trashCan:SetPoint("TOPLEFT", CONTROL_X, -2)

    local whoRow = pages:Row("general", 1, L["Who has it"],
        L["Item tooltips list which of your characters have that item and where: bags, bank or mail. Needs Blackthornes Tradeskills, which remembers your other characters. Also /bbutler whohas."])
    controls.whoHas = Widgets.CreateCheckbox(whoRow, L["Show it"], function(checked)
        if ns.WhoHas then ns.WhoHas:SetEnabled(checked) end
    end, true)
    controls.whoHas:SetPoint("TOPLEFT", CONTROL_X, -2)

    local tipRow = pages:Row("general", 1, L["Butler on tooltips"],
        L["The last line on the tooltip of an item in your bags says what Butler would do with it (sell, keep, disenchant, mail to one of your characters) and what one is worth. Also /bbutler tooltip."])
    controls.verdictTip = Widgets.CreateCheckbox(tipRow, L["Show it"], function(checked)
        if ns.VerdictTip then ns.VerdictTip:SetEnabled(checked) end
    end, true)
    controls.verdictTip:SetPoint("TOPLEFT", CONTROL_X, -2)

    local voiceRow = pages:Row("general", 1, L["Butler's voice"],
        L["\"You rang?\" when you open the Butler window and \"Now, where was I?\" when you close it, in the voice of Karazhan's butler. Never at a vendor, mailbox, bank or other NPC, and at most once every few minutes. Uses your Dialog volume."])
    controls.voice = Widgets.CreateCheckbox(voiceRow, L["On"], function(checked)
        ns.db.voice = checked
    end, true)
    controls.voice:SetPoint("TOPLEFT", CONTROL_X, -2)

    local positionRow = pages:Row("general", 1, L["Window position"],
        L["Moves this window back where it started, if it ends up off screen."])

    local reset = Widgets.CreateButton(positionRow, L["Put it back"], function()
        SettingsUI:ResetPositions()
    end, { width = 100, height = 20 })
    reset:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- Bigger letters in the same windows, as Tradeskills has. Every size
    -- is read as text is drawn, so it waits for /reload.
    local textRow = pages:Row("general", 1, L["Text size"],
        L["Large and Larger add a point or two to all of this addon's text. Takes effect after /reload."])
    controls.textSize = ns.SettingsPages.TextSizeControl(textRow, CONTROL_X, function() return ns.db end)

    -- Asked 2026-10-10: the game's own look for players who would rather
    -- the windows matched the rest of their screen. Read at login, so it
    -- waits for /reload as Text size does. See UI/BlizzardLook.lua.
    local styleRow = pages:Row("general", 1, L["Window style"],
        L["Titanforged is the house look, with a gold rim and glowing edges. Blizzard uses the game's own frames, red buttons and tick boxes. Takes effect after /reload."])
    controls.windowStyle = SettingsUI.WindowStyleControl(styleRow, CONTROL_X)

    pages:Section("general", 2, L["ADVANCED"])

    local debugRow = pages:Row("general", 2, L["Debug output"],
        L["Extra messages in chat, to help track down a problem."])

    controls.debug = Widgets.CreateCheckbox(debugRow, L["Enabled"], function(checked)
        ns.db.debug = checked
    end, false)
    controls.debug:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Core/SisterNote.lua: one chat line, once, naming the Blackthornes
    -- addons the player does not have. Off here is off in all of them.
    local sistersRow = pages:Row("general", 2, L["Sister addons"],
        L["Once, a few seconds after login, says in chat which Blackthornes addons you don't have and what each adds. Turning it off here turns it off in all of them. Same as /bbutler sisters."])
    controls.sisters = Widgets.CreateCheckbox(sistersRow, L["Mention them"], function(checked)
        ns.SisterNote:SetOn(checked)
    end, true)
    controls.sisters:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- UI/WhatsNew.lua: one window after an update for every Blackthornes
    -- addon. Off here is off in all of them, as the sister note is.
    local _, whatsNewButton = CommandRow(pages, "general", 2, L["What's New"],
        L["Opens the What's New window: what changed in each of your Blackthornes addons. Same as /bbutler whatsnew."],
        L["Show it"], "whatsnew")
    controls.whatsnew = whatsNewButton

    local whatsNewRow = pages:Row("general", 2, L["After an update"],
        L["Brings up the What's New window the first time you play after a Blackthornes addon updates. Turning it off here turns it off in all of them."])
    controls.whatsNewPopup = Widgets.CreateCheckbox(whatsNewRow, L["Show What's New"], function(checked)
        ns.WhatsNew:SetOn(checked)
    end, true)
    controls.whatsNewPopup:SetPoint("TOPLEFT", CONTROL_X, -2)

    local whatsNewMotionRow = pages:Row("general", 2, L["What's New motion"],
        L["The What's New window rises in, and its news slides up and glows. Turning it off here turns it off in all of them."])
    controls.whatsNewMotion = Widgets.CreateCheckbox(whatsNewMotionRow, L["Motion"], function(checked)
        ns.WhatsNew:SetMotionOn(checked)
    end, true)
    controls.whatsNewMotion:SetPoint("TOPLEFT", CONTROL_X, -2)

    local _, probeButton = CommandRow(pages, "general", 2, L["Client check"],
        L["Lists in chat which bag, vendor and mail calls this client has, and which Blackthornes addons are loaded. It only reads. Same as /bbutler probe."],
        L["Check"], "probe")
    controls.probe = probeButton

    local _, helpButton = CommandRow(pages, "general", 2, L["Commands"],
        L["Lists every /bbutler command in chat. Same as /bbutler help."],
        L["List them"], "help")
    controls.help = helpButton
end

--------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------

--- Put every control back in step with what is saved. Called whenever the
--- page opens and after any /bbutler command, because each of these can also be
--- changed by typing.
function SettingsUI:Refresh()
    if not (self.frame and self.frame:IsShown() and ns.db) then return end

    local controls = self.controls
    controls.minimap:SetChecked(not ns.db.minimapHidden)
    controls.openAtVendor:SetChecked(ns.db.openAtVendor ~= false)
    controls.openAtMailbox:SetChecked(ns.db.openAtMailbox ~= false)
    controls.fillNext:SetChecked(ns.db.fillNext ~= false)
    controls.altUpgrades:SetChecked(ns.Verdicts:AltUpgradesOn())
    controls.jobsAtLogin:SetChecked(ns.db.jobsAtLogin ~= false)
    controls.openAtBank:SetChecked(ns.db.openAtBank ~= false)
    controls.freeSpace:SetChecked(ns.db.freeSpace ~= false)
    controls.trashCan:SetChecked(ns.db.trashCan ~= false)
    controls.whoHas:SetChecked(ns.db.whoHas ~= false)
    controls.verdictTip:SetChecked(ns.db.verdictTip ~= false)
    controls.voice:SetChecked(ns.db.voice ~= false)
    controls.learn:SetChecked(ns.db.learn ~= false)
    controls.classTraining:SetChecked(ns.ClassTraining:IsOn())
    controls.goldGoals:SetChecked(ns.GoldGoals:IsOn())
    controls.debug:SetChecked(ns.db.debug == true)
    controls.sisters:SetChecked(ns.SisterNote:IsOn())
    controls.whatsNewPopup:SetChecked(ns.WhatsNew:IsOn())
    controls.whatsNewMotion:SetChecked(ns.WhatsNew:IsMotionOn())
    controls.sellBelow:SetValue(ns.Verdicts:SellBelow() or 0)
    controls.goldMinimum:SetValue(ns.Funds:Minimum() or 0)
    local names = {}
    for _, character in ipairs((ns.Funds:Characters())) do names[#names + 1] = character.name end
    table.sort(names)
    controls.goldPick:SetNames(names)
    self:SyncGoldFor()
    local heldNames, seen = {}, {}
    for _, name in ipairs(ns.Errands:Characters()) do
        seen[name] = true
        heldNames[#heldNames + 1] = name
    end
    for _, name in ipairs(ns.Verdicts:HeldNames()) do
        if not seen[name] then heldNames[#heldNames + 1] = name end
    end
    table.sort(heldNames)
    controls.heldPick:SetNames(heldNames)
    self:SyncHeld()
    controls.textSize:Sync()
    controls.windowStyle:Sync()
    self.pages:Refresh()
end

--------------------------------------------------------------------------------
-- Position
--------------------------------------------------------------------------------

function SettingsUI:SavePosition()
    if not (ns.db and self.frame) then return end

    local point, _, relativePoint, x, y = self.frame:GetPoint()

    ns.db.settingsPoint = point
    ns.db.settingsRelativePoint = relativePoint
    ns.db.settingsX = x
    ns.db.settingsY = y
end

function SettingsUI:RestorePosition()
    if not self.frame then return end

    local db = ns.db or {}

    self.frame:ClearAllPoints()
    self.frame:SetPoint(db.settingsPoint or "CENTER", UIParent,
        db.settingsRelativePoint or "CENTER", db.settingsX or 0, db.settingsY or 0)
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

function SettingsUI:Show()
    self:Build()

    if not self.frame:IsShown() then
        self:RestorePosition()
        self.frame:Show()
        ns.Motion:Open(self.frame)
    end

    self:Refresh()
end

function SettingsUI:Hide()
    if self.frame then self.frame:Hide() end
end

function SettingsUI:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

--------------------------------------------------------------------------------
-- The game's own AddOns options list
--
-- As in Farmer: a small launcher under Options > AddOns rather than this page
-- squeezed into Blizzard's frame. Every call is guarded, because a missing
-- options entry is no reason for the addon to fail to load.
--------------------------------------------------------------------------------

function SettingsUI:RegisterGameOptions()
    if self.optionsPanel then return end

    local panel = CreateFrame("Frame")
    panel.name = TITLE

    local title = Theme.CreateLabel(panel, "title", "accent")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(TITLE)

    local blurb = Theme.CreateLabel(panel, "normal", "text")
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    blurb:SetText(L["Butler's settings have a window of their own."])

    local open = Widgets.CreateButton(panel, L["Open Butler settings"], function()
        -- The game's panel is left as it is: hiding a stock frame runs the
        -- game's own code as this addon and taints it (Equipment's Edit
        -- Mode error, 2026-10-10). Butler's window is top level in the dialog
        -- layer, so it comes up over the panel.
        SettingsUI:Show()
    end, { width = 190, height = 24 })
    open:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", 0, -14)

    local hint = Theme.CreateLabel(panel, "small", "muted")
    hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -10)
    hint:SetText(L["Or type /bbutler settings, or click the minimap button."])

    self.optionsPanel = panel

    local registered = false

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        registered = pcall(function()
            local category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
            Settings.RegisterAddOnCategory(category)
            SettingsUI.optionsCategory = category
        end)
    end

    -- The older options API, in case this client still has it instead.
    if not registered and type(InterfaceOptions_AddCategory) == "function" then
        registered = pcall(InterfaceOptions_AddCategory, panel)
    end

    if not registered then
        ns.Debug("no game options panel to register with; /bbutler settings still works")
    end

    return registered
end

function SettingsUI:OnEnable()
    local ok, err = pcall(self.RegisterGameOptions, self)
    if not ok then
        ns.Debug("could not add Butler to the game's options:", tostring(err))
    end
end

ns.RegisterCommand("settings", L["open the settings window"], function()
    SettingsUI:Toggle()
end)

-- Common names for the same thing, so a guess works. Kept out of the help
-- list, which would otherwise print the same line three times.
ns.commands.options = ns.commands.settings
ns.commands.config = ns.commands.settings
