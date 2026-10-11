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
    { key = "selling", text = "ERRANDS",
      tip = "Selling at a vendor, mail and the bank, and your Always keep, sell and bank lists" },
    { key = "gold", text = "GOLD",
      tip = "A gold fund: how much each of your characters keeps, topped up by mail" },
    { key = "general", text = "GENERAL",
      tip = "The minimap button, window position, text size and debug output" },
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
    self.pages:Fit()

    local footer = Theme.CreateLabel(frame, "tiny", "dim")
    footer:SetPoint("BOTTOMLEFT", PADDING, 14)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, 14)
    footer:SetText("Changes save as you make them.")
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
    subtitle:SetText("Settings")

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

--- Titanforged or Blizzard, with Reload beside it while the pick differs
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
    stepper:SetWidth(100)
    stepper:SetPoint("TOPLEFT", x, -2)

    -- ReloadUI is allowed from a click, and saves everything first.
    reload = Widgets.CreateButton(row, "Reload now", function()
        if ReloadUI then ReloadUI() end
    end, { width = 60, height = 20 })
    reload:SetPoint("LEFT", stepper, "RIGHT", 6, 0)
    reload:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Reload the interface so the new window style shows (/reload)", 1, 1, 1, true)
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
        text:SetText(picker.names[picker.index] or "No characters yet")
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

function SettingsUI:BuildPages()
    local controls = self.controls
    local pages = self.pages

    -- Selling: the vendor on the left, the player's lists on the right.
    pages:Section("selling", 1, "AT A VENDOR")

    local vendorRow = pages:Row("selling", 1, "Open at a vendor",
        "The Butler window comes up by itself at every vendor, and goes when you leave. Nothing sells until you click Sell. Also /bbutler vendor.")
    controls.openAtVendor = Widgets.CreateCheckbox(vendorRow, "On", function(checked)
        ns.db.openAtVendor = checked
    end, true)
    controls.openAtVendor:SetPoint("TOPLEFT", CONTROL_X, -2)

    local testRow, testButton = CommandRow(pages, "selling", 1, "Test selling",
        "At a vendor, sells your cheapest grey item from Butler's own code to see whether the game allows it. If it does, Sell sells up to 12 a click; if not, one stack a click. Same as /bbutler selltest.",
        "Test it", "selltest")
    controls.sellTest = testButton
    controls.sellTestRow = testRow

    pages:Section("selling", 1, "MAIL AND BANK")

    local mailRow = pages:Row("selling", 1, "Open at a mailbox",
        "The Butler window comes up at every mailbox, in place of Tradeskills' mail panel (close it to get that back). Fill mail at its foot fills the game's Send Mail page for one character a click; you press Send. Needs Blackthornes Tradeskills. Also /bbutler mailbox.")
    controls.openAtMailbox = Widgets.CreateCheckbox(mailRow, "On", function(checked)
        ns.db.openAtMailbox = checked
    end, true)
    controls.openAtMailbox:SetPoint("TOPLEFT", CONTROL_X, -2)

    local nextRow = pages:Row("selling", 1, "Fill the next mail",
        "After you send a mail Butler filled, it fills the next one straight away, so you only press Send for each character. Also /bbutler fillnext.")
    controls.fillNext = Widgets.CreateCheckbox(nextRow, "On", function(checked)
        ns.db.fillNext = checked
    end, true)
    controls.fillNext:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Jobs for the craft queue on other characters (Logic/Jobs.lua, asked
    -- 2026-10-11).
    local jobRow = pages:Row("selling", 1, "Jobs at login",
        "Logging in on a character with a job for Tradeskills' craft queue (craft this, mail that) brings the Butler window up on its steps. Also /bbutler joblogin.")
    controls.jobsAtLogin = Widgets.CreateCheckbox(jobRow, "On", function(checked)
        ns.db.jobsAtLogin = checked
    end, true)
    controls.jobsAtLogin:SetPoint("TOPLEFT", CONTROL_X, -2)

    CommandRow(pages, "selling", 1, "Every character's jobs",
        "Lists in chat what each of your characters has to craft or mail for Tradeskills' craft queue. Also /bbutler jobs.", "List", "jobs")

    local bankRow = pages:Row("selling", 1, "Open at the bank",
        "The Butler window comes up at the bank when there is something to move: Move to bank puts your Always bank items away, and Take from bank brings out what your craft queue needs. Also /bbutler bank.")
    controls.openAtBank = Widgets.CreateCheckbox(bankRow, "On", function(checked)
        ns.db.openAtBank = checked
    end, true)
    controls.openAtBank:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Asked 2026-10-11: anything worth less than this joins Sell. It only
    -- ever adds to Sell; nothing sells until the player clicks.
    pages:Section("selling", 2, "JUNK")

    local belowRow = pages:Row("selling", 2, "Sell below",
        "Anything worth less than this goes under Sell, judged on the most it could fetch from a vendor, the auction house or a disenchant. Quest items, upgrades, goal and craft materials, pet food, soulbound green or better gear and your Always keep, bank and mail items are never included, and nothing sells until you click Sell. Needs Blackthornes Tradeskills for auction prices. Leave it at 0 for off. Also /bbutler sellbelow 50s.")
    controls.sellBelow = Widgets.CreateMoneyBox(belowRow, function(copper)
        ns.Verdicts:SetSellBelow(copper)
    end)
    controls.sellBelow:SetPoint("TOPLEFT", CONTROL_X, 0)

    pages:Section("selling", 2, "YOUR LISTS")

    local learnRow = pages:Row("selling", 2, "Learn from what you do",
        "Butler watches what you do anyway and remembers it: buy back something it sold and it keeps it from then on; sell an item yourself at a vendor on two visits and it goes under Sell; mail an item to the same one of your characters twice and it goes under Mail to them. Your own right-click choices always win, and right-click shows Forget what Butler learned. Nothing is sold or sent without your click.")
    controls.learn = Widgets.CreateCheckbox(learnRow, "On", function(checked)
        ns.db.learn = checked
        ns.Verdicts:Changed(true)
    end)
    controls.learn:SetPoint("TOPLEFT", CONTROL_X, -2)

    local _, listsButton = CommandRow(pages, "selling", 2, "Keep, sell, bank, mail",
        "Right-click an item in the Butler window to always keep it, sell it, bank it or mail it to one of your characters. This lists all four in chat, and what Butler learned from you. To empty them, type /bbutler reset confirm. Same as /bbutler lists.",
        "List them", "lists")
    controls.lists = listsButton

    -- Gold: the gold fund (the owner asked 2026-10-11). The usual amount on
    -- the left, one character's own on the right. Logic/Funds.lua.
    pages:Section("gold", 1, "GOLD FUND")

    local minRow = pages:Row("gold", 1, "Keep at least",
        "Every character keeps this much gold. At a mailbox, a character with more is offered a gold mail to each of your characters below it (Fill mail fills it, you press Send), never going below its own amount. Needs Blackthornes Tradeskills, which keeps your characters' gold as last seen. Leave it at 0 for off. Also /bbutler goldmin 50g.")
    controls.goldMinimum = Widgets.CreateMoneyBox(minRow, function(copper)
        ns.Funds:SetMinimum(copper)
    end)
    controls.goldMinimum:SetPoint("TOPLEFT", CONTROL_X, 0)

    local _, goldButton = CommandRow(pages, "gold", 1, "Everyone's gold",
        "Lists in chat each character's gold as last seen, what it keeps and what the fund would send it. Same as /bbutler gold.",
        "List it", "gold")
    controls.goldReport = goldButton

    pages:Section("gold", 2, "ONE CHARACTER")

    local pickRow = pages:Row("gold", 2, "Character",
        "Pick one of your characters to give it an amount of its own.")
    controls.goldPick = SettingsUI.CharacterPicker(pickRow, CONTROL_X, function()
        SettingsUI:SyncGoldFor()
    end)

    local ownRow = pages:Row("gold", 2, "They keep",
        "This character's own amount, in place of the usual. 0 means it keeps nothing back, so it can give all it has.")
    controls.goldFor = Widgets.CreateMoneyBox(ownRow, function(copper)
        local name = controls.goldPick:GetName()
        if name then ns.Funds:SetMinimumFor(name, copper) end
    end)
    controls.goldFor:SetPoint("TOPLEFT", CONTROL_X, 0)

    local usualRow = pages:Row("gold", 2, "Back to the usual",
        "This character keeps the usual amount again.")
    controls.goldUsual = Widgets.CreateButton(usualRow, "Use the usual", function()
        local name = controls.goldPick:GetName()
        if name then ns.Funds:SetMinimumFor(name, nil) end
        SettingsUI:SyncGoldFor()
    end, { width = 100, height = 20 })
    controls.goldUsual:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- General: windows and text on the left, debug on the right.
    pages:Section("general", 1, "WINDOWS")

    local windowRow = pages:Row("general", 1, "Butler window",
        "What to do with each item in your bags. Same as /bbutler window, or /bbutler on its own.")
    controls.openWindow = Widgets.CreateButton(windowRow, "Open it", function()
        ns.HandleSlash("window")
    end, { width = 100, height = 20, primary = true })
    controls.openWindow:SetPoint("TOPLEFT", CONTROL_X, 0)

    local _, allButton = CommandRow(pages, "general", 1, "All characters",
        "Every character's items in one list, with who has each and whether it is in their bags, bank or mail. Needs Blackthornes Tradeskills for the other characters. Same as /bbutler all.",
        "Show them", "all")
    controls.all = allButton

    local minimapRow = pages:Row("general", 1, "Minimap button",
        "Click it for the Butler window, right-click for this page. Drag it to move it. Also /bbutler minimap.")

    controls.minimap = Widgets.CreateCheckbox(minimapRow, "Show it", function(checked)
        ns.db.minimapHidden = not checked
        if ns.MinimapButton then ns.MinimapButton:ApplyVisibility() end
    end, true)
    controls.minimap:SetPoint("TOPLEFT", CONTROL_X, -2)

    local spaceRow = pages:Row("general", 1, "Free bag space",
        "How many bag slots are free, as a number on the backpack button of your bag bar: white, amber at 8 or fewer, red at 3 or fewer. Hover the button for each bag. Profession and reagent bags are listed but not counted. Also /bbutler freespace.")
    controls.freeSpace = Widgets.CreateCheckbox(spaceRow, "Show it", function(checked)
        if ns.FreeSpace then ns.FreeSpace:SetEnabled(checked) end
    end, true)
    controls.freeSpace:SetPoint("TOPLEFT", CONTROL_X, -2)

    local whoRow = pages:Row("general", 1, "Who has it",
        "Item tooltips list which of your characters have that item and where: bags, bank or mail. Needs Blackthornes Tradeskills, which remembers your other characters. Also /bbutler whohas.")
    controls.whoHas = Widgets.CreateCheckbox(whoRow, "Show it", function(checked)
        if ns.WhoHas then ns.WhoHas:SetEnabled(checked) end
    end, true)
    controls.whoHas:SetPoint("TOPLEFT", CONTROL_X, -2)

    local voiceRow = pages:Row("general", 1, "Butler's voice",
        "\"You rang?\" when you open the Butler window and \"Now, where was I?\" when you close it, in the voice of Karazhan's butler. Never at a vendor, mailbox, bank or other NPC, and at most once every few minutes. Uses your Dialog volume.")
    controls.voice = Widgets.CreateCheckbox(voiceRow, "On", function(checked)
        ns.db.voice = checked
    end, true)
    controls.voice:SetPoint("TOPLEFT", CONTROL_X, -2)

    local positionRow = pages:Row("general", 1, "Window position",
        "Moves this window back where it started, if it ends up off screen.")

    local reset = Widgets.CreateButton(positionRow, "Put it back", function()
        SettingsUI:ResetPositions()
    end, { width = 100, height = 20 })
    reset:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- Bigger letters in the same windows, as Tradeskills has. Every size
    -- is read as text is drawn, so it waits for /reload.
    local textRow = pages:Row("general", 1, "Text size",
        "Large and Larger add a point or two to all of this addon's text. Takes effect after /reload.")
    controls.textSize = ns.SettingsPages.TextSizeControl(textRow, CONTROL_X, function() return ns.db end)

    -- Asked 2026-10-10: the game's own look for players who would rather
    -- the windows matched the rest of their screen. Read at login, so it
    -- waits for /reload as Text size does. See UI/BlizzardLook.lua.
    local styleRow = pages:Row("general", 1, "Window style",
        "Titanforged is the house look, with a gold rim and glowing edges. Blizzard uses the game's own frames, red buttons and tick boxes. Takes effect after /reload.")
    controls.windowStyle = SettingsUI.WindowStyleControl(styleRow, CONTROL_X)

    pages:Section("general", 2, "ADVANCED")

    local debugRow = pages:Row("general", 2, "Debug output",
        "Extra messages in chat, to help track down a problem.")

    controls.debug = Widgets.CreateCheckbox(debugRow, "Enabled", function(checked)
        ns.db.debug = checked
    end, false)
    controls.debug:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Core/SisterNote.lua: one chat line, once, naming the Blackthornes
    -- addons the player does not have. Off here is off in all of them.
    local sistersRow = pages:Row("general", 2, "Sister addons",
        "Once, a few seconds after login, says in chat which Blackthornes addons you don't have "
        .. "and what each adds. Turning it off here turns it off in all of them. Same as /bbutler sisters.")
    controls.sisters = Widgets.CreateCheckbox(sistersRow, "Mention them", function(checked)
        ns.SisterNote:SetOn(checked)
    end, true)
    controls.sisters:SetPoint("TOPLEFT", CONTROL_X, -2)

    local _, probeButton = CommandRow(pages, "general", 2, "Client check",
        "Lists in chat which bag, vendor and mail calls this client has, and which Blackthornes addons are loaded. It only reads. Same as /bbutler probe.",
        "Check", "probe")
    controls.probe = probeButton

    local _, helpButton = CommandRow(pages, "general", 2, "Commands",
        "Lists every /bbutler command in chat. Same as /bbutler help.",
        "List them", "help")
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
    controls.jobsAtLogin:SetChecked(ns.db.jobsAtLogin ~= false)
    controls.openAtBank:SetChecked(ns.db.openAtBank ~= false)
    controls.freeSpace:SetChecked(ns.db.freeSpace ~= false)
    controls.whoHas:SetChecked(ns.db.whoHas ~= false)
    controls.voice:SetChecked(ns.db.voice ~= false)
    controls.learn:SetChecked(ns.db.learn ~= false)
    controls.debug:SetChecked(ns.db.debug == true)
    controls.sisters:SetChecked(ns.SisterNote:IsOn())
    controls.sellBelow:SetValue(ns.Verdicts:SellBelow() or 0)
    controls.goldMinimum:SetValue(ns.Funds:Minimum() or 0)
    local names = {}
    for _, character in ipairs((ns.Funds:Characters())) do names[#names + 1] = character.name end
    table.sort(names)
    controls.goldPick:SetNames(names)
    self:SyncGoldFor()
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
    blurb:SetText("Butler's settings have a window of their own.")

    local open = Widgets.CreateButton(panel, "Open Butler settings", function()
        -- The game's panel is left as it is: hiding a stock frame runs the
        -- game's own code as this addon and taints it (Equipment's Edit
        -- Mode error, 2026-10-10). Butler's window is top level in the dialog
        -- layer, so it comes up over the panel.
        SettingsUI:Show()
    end, { width = 190, height = 24 })
    open:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", 0, -14)

    local hint = Theme.CreateLabel(panel, "small", "muted")
    hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -10)
    hint:SetText("Or type /bbutler settings, or click the minimap button.")

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

ns.RegisterCommand("settings", "open the settings window", function()
    SettingsUI:Toggle()
end)

-- Common names for the same thing, so a guess works. Kept out of the help
-- list, which would otherwise print the same line three times.
ns.commands.options = ns.commands.settings
ns.commands.config = ns.commands.settings
