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
-- Where the controls start: room for a label like "Free Bag Space:" in the
-- game's font, which runs wider than it looks.
local CONTROL_X = 150
SettingsUI.PADDING, SettingsUI.COLUMN_WIDTH, SettingsUI.COLUMN_GAP = PADDING, COLUMN_WIDTH, COLUMN_GAP

local TITLE = "Blackthornes Butler"

-- The pages along the top (UI/SettingsPages.lua), as Tradeskills' Settings
-- tab has them. Every setting kept its saved name; only its place moved.
local PAGES = {
    { key = "selling", text = L["ERRANDS"],
      tip = L["Selling at a vendor, mail and the bank, and your Always keep, sell and bank lists"] },
    { key = "keep", text = L["KEEP"],
      tip = L["What each character keeps, and upgrades for your other characters"] },
    { key = "order", text = L["ORDER"],
      tip = L["The order Butler asks its rules in, and which ones are on"] },
    { key = "bankalt", text = L["BANK ALT"],
      tip = L["Mail whole kinds of items to one of your characters"] },
    { key = "gold", text = L["GOLD"],
      tip = L["How much gold each of your characters keeps, topped up by mail"] },
    -- From here on, the pages every Blackthornes addon shares, in the same
    -- order in all five (the owner said build it, 2026-11-17). Tooltips
    -- left General for its own page, and General became Windows; its key
    -- stays "general", so a saved page still opens.
    { key = "tooltips", text = L["TOOLTIPS"],
      tip = L["Lines Butler adds to item tooltips"] },
    { key = "general", text = L["WINDOWS"],
      tip = L["The Butler window, its size and voice, and your bags"] },
    -- The settings every Blackthornes addon shares (2026-11-16): reached
    -- by the one window's gear while One Window is on, so it is left off
    -- the switch then; on the switch while each addon has its own window.
    { key = "all", text = L["ALL ADDONS"] },
    { key = "about", text = L["ABOUT"],
      tip = L["How these addons are made, the version, the Discord and the other Blackthornes addons"] },
}

--- Put the Butler window and this one back where they started. The place
--- every tab opens at is `windowLeft`/`windowTop`; the older keys are only
--- read when those are missing, so all of them are cleared. Inside the one
--- window the pages fill its area, so nothing is moved there: pulling a
--- page onto UIParent left it hanging off the one window until Butler was
--- opened again (a player's report, 2026-10-31). The cleared place is used
--- once the pages are back in their own window.
function SettingsUI:ResetPositions()
    local db = ns.db
    if not db then return end
    db.settingsPoint, db.settingsRelativePoint, db.settingsX, db.settingsY = nil, nil, nil, nil
    db.point, db.relativePoint, db.x, db.y = nil, nil, nil, nil
    db.windowLeft, db.windowTop = nil, nil
    local tabs = ns.ButlerTabs
    if tabs and tabs.Hosted and tabs:Hosted() then return end
    for _, window in ipairs({ self, ns.UI }) do
        local frame = window and rawget(window, "frame")
        if frame and frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
            if tabs and tabs.Settle then tabs:Settle(frame) end
        end
    end
end

--- Every Blackthornes window back where it started, in every addon loaded
--- (the owner, 2026-11-12): the one window, its docked spots, the small
--- windows and each addon's own. Settings and data stay the same.
function SettingsUI:ResetAllWindows()
    local shared = ns.SharedWindow
    if shared and shared.ResetAllSpots then
        shared.ResetAllSpots()
    else
        SettingsUI:ResetPositions()
    end
    ns.Print(L["Every window is back in its first spot."])
end

if ns.SharedWindow and ns.SharedWindow.AddSpotReset then
    ns.SharedWindow.AddSpotReset("Butler", function() SettingsUI:ResetPositions() end)
end

--------------------------------------------------------------------------------
-- Butler Settings: Set Default (the owner said build it, 2026-11-23)
--------------------------------------------------------------------------------

--- Every saved key a Settings control writes, and only those. Data, window
--- spots and the ALL ADDONS choices the five addons share are left out on
--- purpose. tools/test_restoredefaults.lua clicks every control and fails
--- if one writes a key missing here.
SettingsUI.SETTING_KEYS = {
    "altUpgrades", "arrowRoute", "bagGroupBy", "bagItemLevel", "bagItemSize",
    "bagMarks", "bagNewGlow", "bagWindow", "bankAltAuctions",
    "bankAltFullStacks", "bankAltStore", "bankAltWhen", "buyMany",
    "classTraining", "craftDetails", "craftPays", "disenchantAnyPrice",
    "disenchantGreens", "fillNext", "freeSpace", "goldGoals", "jobsAtLogin",
    "keepAcrossBank", "keepAcrossMail", "keepLevelUp", "learn",
    "mailContents", "mailRunsOut", "namePicker", "openAtBank",
    "openAtMailbox", "openAtVendor", "placeBar", "questBuy", "questItems",
    "settingsDescriptions", "skillUpLine", "swapWhenFull", "trashCan",
    "useTomTom", "vendorPrice", "verdictTip", "voice", "wayArrowSize",
    "whoHas", "windowScale",
}

--- The same, for keys saved for one character.
SettingsUI.CHAR_SETTING_KEYS = {
}

--- How long the red Confirm waits for the second click, in seconds.
SettingsUI.CONFIRM_WAIT = 4

--- Puts every Butler setting back to how it started, then reloads the
--- game's interface so every window reads them again. Saved data stays.
function SettingsUI:RestoreDefaults()
    local db, defaults = ns.db, ns.DEFAULTS or {}
    if type(db) ~= "table" then return false end
    for _, key in ipairs(SettingsUI.SETTING_KEYS) do
        local value = defaults[key]
        if type(value) == "table" and CopyTable then value = CopyTable(value) end
        db[key] = value
    end
    if type(ns.charDB) == "table" then
        local charDefaults = ns.CHAR_DEFAULTS or {}
        for _, key in ipairs(SettingsUI.CHAR_SETTING_KEYS) do
            ns.charDB[key] = charDefaults[key]
        end
    end

    -- Said after the reload, once.
    db.settingsRestored = true
    if type(ReloadUI) == "function" then
        ReloadUI()
    else
        self:SayRestored()
    end
    return true
end

--- The chat line after Set Default, said once.
function SettingsUI:SayRestored()
    if not (ns.db and ns.db.settingsRestored) then return end
    ns.db.settingsRestored = nil
    ns.Print(L["Every Butler setting is back to how it started."])
end

--- A button that turns red and says Confirm on the first click, and runs
--- `onConfirm` on a second click within CONFIRM_WAIT seconds.
function SettingsUI.ConfirmButton(parent, text, onConfirm, width)
    local button, armedAt
    local function Now()
        if type(GetTime) ~= "function" then return nil end
        local ok, now = pcall(GetTime)
        return ok and type(now) == "number" and now or nil
    end
    local function Arm(on, at)
        button.armed, armedAt = on, at
        button:SetText(on and L["Confirm"] or text)
        -- Red words while it waits for the second click.
        if button.SetLabelColor then button:SetLabelColor(on and "loss" or nil) end
    end
    button = Widgets.CreateButton(parent, text, function()
        local now = Now()
        if button.armed and (not armedAt or not now
            or now - armedAt <= SettingsUI.CONFIRM_WAIT) then
            Arm(false, nil)
            onConfirm()
            return
        end
        Arm(true, now)
        if now and C_Timer and type(C_Timer.After) == "function" then
            pcall(C_Timer.After, SettingsUI.CONFIRM_WAIT, function()
                local later = Now()
                if button.armed and armedAt and later
                    and later - armedAt >= SettingsUI.CONFIRM_WAIT then
                    Arm(false, nil)
                end
            end)
        end
    end, { width = width, height = 20 })
    button.armed = false
    return button
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

    -- The fold gem beside the close gem, as on every other tab
    -- (UI/FoldWindow.lua), so the corner never changes between tabs.
    if ns.FoldWindow then
        ns.FoldWindow:Add(frame, { key = "Settings", onToggle = function(folded)
            if not folded then SettingsUI:Refresh() end
        end })
    end
    -- And left of it, the swap gem: it joins every Blackthornes addon into
    -- the one window (UI/SharedWindow.lua).
    if ns.SharedWindow and ns.SharedWindow.AddSwap then ns.SharedWindow.AddSwap(frame, "butler") end

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SettingsUI:SavePosition()
        if ns.ButlerTabs then ns.ButlerTabs:Save(self) end
    end)
    -- Closed for good, not stepping aside for another tab: Tradeskills'
    -- mail panel may come back.
    frame:SetScript("OnHide", function()
        if ns.ButlerTabs and ns.ButlerTabs.switching then return end
        if ns.Errands then ns.Errands:TellTradeskills() end
        if ns.ButlerTabs then ns.ButlerTabs:Closed(frame) end
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
        -- The page names wrap to a second line rather than grow the window
        -- past its two columns (Farmer's BAR_CAP does the same): a wider
        -- Butler stretched the one window, off the screen in Russian.
        barCap = 2 * COLUMN_WIDTH + COLUMN_GAP + 2 * PADDING,
        db = function() return ns.db end,
    })
    self:BuildPages()
    -- The order Butler asks its rules in (UI/RuleOrder.lua): one board
    -- across both columns.
    if ns.RuleOrderUI then
        local pages = self.pages
        local board = ns.RuleOrderUI:Build(pages.pages.order.content, COLUMN_WIDTH, COLUMN_GAP, function(key)
            pages:Show(key)
        end)
        pages:Place("order", 1, board)
        pages:Searchable("order", board, board.words)
    end
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
    -- Every tab is one size (UI/ButlerTabs.lua): Settings says how wide its
    -- pages need to be, and the Butler window widens to match. Its height
    -- stays the Butler window's and the pages scroll: asking for the
    -- fullest page's height let a long list (Keep Across, the mail rules)
    -- stretch every tab nearly to the screen's height, off its bottom in
    -- the one window (2026-11-18).
    local pages = self.pages
    local fit = pages.Fit
    pages.Fit = function(page)
        fit(page)
        -- What the pages asked for: laid into the one window the frame
        -- fills the area, so its own size would only say how big that is.
        local need = page.need or { frame:GetWidth(), frame:GetHeight() }
        if ns.ButlerTabs then ns.ButlerTabs:Need("settings", need[1], nil) end
    end
    self.pages:Fit()

    local footer = Theme.CreateLabel(frame, "tiny", "dim")
    footer:SetPoint("BOTTOMLEFT", PADDING, 14)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, 14)
    footer:SetText(L["Changes save as you make them."])
    self.footer = footer

    -- Your Bags, All Characters and Settings, last on the right.
    if ns.ButlerTabs then ns.ButlerTabs:Attach(self) end

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

--- A row whose button runs a /bbutler command. Chat-only commands have no
--- row (the owner, 2026-10-15).
local function CommandRow(pages, page, column, label, description, buttonText, command)
    local row = pages:Row(page, column, label, description)
    local button = Widgets.CreateButton(row, buttonText, function()
        ns.HandleSlash(command)
    end, { width = 100, height = 20 })
    button:SetPoint("TOPLEFT", CONTROL_X, 0)
    return row, button
end

--- A control's words on the hover, the game's way.
function SettingsUI.Hover(control, text)
    if not (control and control.HookScript and text and text ~= "") then return end
    control:HookScript("OnEnter", function(self)
        local tip = rawget(_G, "GameTooltip")
        if not tip then return end
        tip:SetOwner(self, "ANCHOR_RIGHT")
        tip:SetText(text, 1, 1, 1, 1, true)
        tip:Show()
    end)
    control:HookScript("OnLeave", function()
        local tip = rawget(_G, "GameTooltip")
        if tip then tip:Hide() end
    end)
end

SettingsUI.FLOW_LINE = 22
SettingsUI.FLOW_GAP = 12

--- Lay `list` (tick boxes) left to right under a row's label, across the
--- whole column, onto a new line when the next one does not fit. The row
--- grows by the lines used. Returns how many lines.
function SettingsUI.Flow(row, list)
    local x, line = 0, 1
    local top = row.compactHeight or 24
    for _, control in ipairs(list) do
        local width = tonumber(control:GetWidth()) or 80
        if x > 0 and x + width > COLUMN_WIDTH then
            x, line = 0, line + 1
        end
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", x, -(top + (line - 1) * SettingsUI.FLOW_LINE))
        x = x + width + SettingsUI.FLOW_GAP
    end
    if row.Grow then row:Grow(line * SettingsUI.FLOW_LINE) end
    -- The search finds the row by its ticks' words too.
    for _, entry in ipairs(row.pages and row.pages.searchables or {}) do
        if entry.frame == row then
            for _, control in ipairs(list) do
                local text = control.label and control.label:GetText()
                if type(text) == "string" then entry.words = entry.words .. " " .. text:lower() end
            end
        end
    end
    return line
end

--- One Off, Shift or Always box for all of `lines` ({ key, text, isOn,
--- setOn } each: its own on or off reader and setter), at CONTROL_X on `row`,
--- and a tick box per line (line.box, placed by the caller). The box shows
--- Off with no line ticked, else Always if any ticked line is on Always,
--- else Shift. Picking Off unticks every line and remembers which were
--- ticked, for this session, so Shift or Always brings the same ones back.
function SettingsUI.TooltipLinesControl(row, lines)
    local TooltipShift = ns.TooltipShift
    local stepper
    local remembered

    local function Mode()
        local mode = TooltipShift.OFF
        for _, line in ipairs(lines) do
            mode = math.max(mode, TooltipShift:Mode(line.isOn(), line.key))
        end
        return mode
    end

    local function Sync()
        stepper:SetValue(Mode(), true)
        for _, line in ipairs(lines) do line.box:SetChecked(line.isOn()) end
    end

    stepper = Widgets.CreateChoice(row, {
        min = 0, max = 2, step = 1,
        format = function(value) return TooltipShift.NAMES[value] end,
        onChange = function(value)
            if value == TooltipShift.OFF then
                remembered = {}
                for _, line in ipairs(lines) do
                    remembered[line.key] = line.isOn()
                    TooltipShift:Apply(value, line.key, line.isOn(), line.setOn)
                end
            else
                local any = false
                for _, line in ipairs(lines) do any = any or line.isOn() end
                for _, line in ipairs(lines) do
                    -- Coming back from Off: the lines ticked before, or all.
                    local want = line.isOn()
                    if not any then want = not remembered or remembered[line.key] ~= false end
                    if want then TooltipShift:Apply(value, line.key, line.isOn(), line.setOn) end
                end
                remembered = nil
            end
            Sync()
        end,
    })
    ns.SettingsPages.FitStepper(stepper, TooltipShift.NAMES)
    stepper:SetPoint("TOPLEFT", CONTROL_X, -2)

    for _, line in ipairs(lines) do
        line.box = Widgets.CreateCheckbox(row, line.text, function(checked)
            local mode = Mode()
            if checked then
                TooltipShift:Apply(mode == TooltipShift.SHIFT and TooltipShift.SHIFT or TooltipShift.ALWAYS,
                    line.key, line.isOn(), line.setOn)
            else
                TooltipShift:Apply(TooltipShift.OFF, line.key, line.isOn(), line.setOn)
            end
            Sync()
        end, line.isOn())
    end

    stepper.Sync = Sync
    Sync()
    return stepper
end

-- The window styles, in the order their drop-down lists them.
local STYLES = { "titanforged", "blizzard" }
local STYLE_LABELS = { titanforged = "Titanforged", blizzard = "Blizzard" }

--- Titanforged or Blizzard, with Reload under it while the pick differs
--- from what is drawn, as the Text size row has. A drop-down, like Text
--- size.
function SettingsUI.WindowStyleControl(row, x)
    local reload
    local function Drawn()
        local Look = ns.BlizzardLook
        return Look and Look.Style() or "titanforged"
    end

    local stepper = Widgets.CreateChoice(row, {
        min = 1, max = #STYLES, step = 1,
        format = function(value) return STYLE_LABELS[STYLES[value]] end,
        onChange = function(value)
            ns.db.windowStyle = STYLES[value]
            if ns.SharedChoices then ns.SharedChoices:Changed("windowStyle", STYLES[value]) end
            reload:SetShown(STYLES[value] ~= Drawn())
        end,
    })
    -- As wide as "Titanforged" at the player's text size, with Reload under
    -- it: at 100 with Reload beside it, the word spilled out of its box and
    -- Reload out of the column (a player's report, 2026-10-13).
    ns.SettingsPages.FitStepper(stepper, STYLE_LABELS)
    stepper:SetPoint("TOPLEFT", x, -2)

    -- ReloadUI is allowed from a click, and saves everything first.
    reload = Widgets.CreateButton(row, L["Reload"], function()
        if ReloadUI then ReloadUI() end
    end, { width = 60, height = 20 })
    ns.SettingsPages.ReloadUnder(row, stepper, reload)
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

--- The player's characters on this realm and side by full name, in a
--- drop-down (the owner, 2026-10-23: drop-downs, never < > pickers), as
--- wide as the longest name so none is cut short. Also lists and items.
--- :SetNames(list), :GetName(), :Select(name); .index is the one picked,
--- and :Pick(index) is what a click on a line of its menu does.
function SettingsUI.CharacterPicker(row, x, onChange)
    local picker = Widgets.CreateDropdown(row, {}, nil,
        { width = 180, placeholder = L["No characters yet"] })
    picker:SetPoint("TOPLEFT", x, -1)
    picker.names, picker.index, picker.least = {}, 1, 180
    picker.text = picker.label

    local function Show()
        local count = #picker.names
        picker.index = math.max(1, math.min(picker.index, math.max(1, count)))
        local options = {}
        for index, name in ipairs(picker.names) do options[index] = { text = name, value = index } end
        picker.options = options
        -- Grows to the longest name; never narrower than `least`.
        picker:SetWidth(Widgets.DropdownWidth(options, picker.least))
        picker:SetValue(count > 0 and picker.index or nil)
    end

    function picker:Pick(index)
        if self.menu then self.menu:Hide() end
        index = tonumber(index)
        if not index or index < 1 or index > #self.names or index == self.index then return end
        self.index = index
        Show()
        if onChange then onChange() end
    end

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

    --- Show this name, or the first when it is nil or not there.
    function picker:Select(name)
        self.index = 1
        for index, each in ipairs(self.names) do
            if name ~= nil and each == name then self.index = index end
        end
        Show()
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

-- The characters and items the keep pickers step through.
SettingsUI.keepState = { guids = {}, items = {} }

--- Keep on each character: the characters with a list (the one playing
--- first), the picked one's items, and the picked item's number.
function SettingsUI:SyncKeepHere()
    local controls = self.controls
    if not (controls and controls.keepWho and ns.KeepHere) then return end
    local state = self.keepState
    local who = controls.keepWho
    local current = state.guids[who.index]
    local names, guids = {}, {}
    for _, each in ipairs(ns.KeepHere:Characters()) do
        names[#names + 1] = each.name
        guids[#guids + 1] = each.guid
    end
    state.guids = guids
    who:SetNames(names)
    who.index = 1
    for index, guid in ipairs(guids) do
        if guid == current then who.index = index end
    end
    who:Select(names[who.index])
    who.index = math.max(1, math.min(#guids, who.index))

    local what = controls.keepWhat
    local items = ns.KeepHere:Items(guids[who.index])
    local itemNames = {}
    for _, each in ipairs(items) do itemNames[#itemNames + 1] = ns.Items:ColorName(each.name, each.itemID) end
    local index = what.index or 1
    state.items = items
    what:SetNames(itemNames)
    what.index = math.max(1, math.min(#items, index))
    what:Select(itemNames[what.index])
    if #items == 0 then what.text:SetText(L["Nothing kept yet"]) end

    local picked = items[what.index]
    local all = picked and ns.KeepHere.IsAll(picked.count)
    controls.keepCount:SetText(picked and not all and tostring(picked.count) or "")
    if controls.keepAll then
        controls.keepAll:SetText(all and L["Keeping All"] or L["Keep All"])
        controls.keepAll:SetLabelColor(picked and not all and nil or "dim")
    end
    controls.keepRemove:SetLabelColor(picked and nil or "dim")
end

--------------------------------------------------------------------------------
-- Keep across characters: the list
--------------------------------------------------------------------------------

-- Where each column ends, from the list's left edge.
local ACROSS_KEEP_RIGHT = 214
local ACROSS_HAVE_RIGHT = 262
local ACROSS_NAME_WIDTH = 160
local ACROSS_ROW = 22
local ACROSS_LINE = 18
local ACROSS_HEADER = 18

-- Items whose characters are shown, by item ID, for this session only.
SettingsUI.acrossOpen = {}

--- The ITEM, KEEP, HAVE and STATUS headings over the list.
function SettingsUI.BuildAcrossHeader(list)
    local function Heading(text, right, justify)
        local label = Theme.CreateLabel(list, "tiny", "heading", justify)
        label:SetText(text)
        if right then
            label:SetPoint("TOPRIGHT", list, "TOPLEFT", right, -3)
        else
            label:SetPoint("TOPLEFT", 8, -3)
        end
        return label
    end
    Heading(L["ITEM"])
    Heading(L["KEEP"], ACROSS_KEEP_RIGHT, "RIGHT")
    Heading(L["HAVE"], ACROSS_HAVE_RIGHT, "RIGHT")
    Heading(L["STATUS"], COLUMN_WIDTH - 8, "RIGHT")
    list.rows, list.lines = {}, {}
    list.empty = Theme.CreateLabel(list, "small", "dim")
    list.empty:SetPoint("TOPLEFT", 8, -(ACROSS_HEADER + 4))
    list.empty:SetText(L["Nothing kept yet"])
end

--- How tall a label wants to be, or `least`.
local function TextHeight(label, least)
    local ok, height = pcall(label.GetStringHeight, label)
    height = ok and tonumber(height) or nil
    return math.max(least, height and (height + 8) or least)
end

--- An item's row: dark glass, its name, the numbers and a status.
local function AcrossRow(list, index)
    local row = list.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, list)
    row:SetWidth(COLUMN_WIDTH)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
    row.edge:SetColorTexture(Theme.Unpack("accentHi"))
    row.name = Theme.CreateLabel(row, "normal", "text")
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetWidth(ACROSS_NAME_WIDTH)
    row.name:SetWordWrap(true)
    row.keep = Theme.CreateLabel(row, "normal", "text", "RIGHT")
    row.keep:SetPoint("RIGHT", row, "LEFT", ACROSS_KEEP_RIGHT, 0)
    row.have = Theme.CreateLabel(row, "normal", "text", "RIGHT")
    row.have:SetPoint("RIGHT", row, "LEFT", ACROSS_HAVE_RIGHT, 0)
    row.status = Theme.CreateLabel(row, "normal", "good", "RIGHT")
    row.status:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnClick", function(self, button)
        if not self.itemID then return end
        if button == "RightButton" then
            if ns.KeepAcrossUI then ns.KeepAcrossUI:Open(self.itemID) end
            return
        end
        SettingsUI.acrossOpen[self.itemID] = not SettingsUI.acrossOpen[self.itemID] or nil
        SettingsUI:SyncKeepAcross()
    end)
    row:SetScript("OnEnter", function(self)
        self.fill:SetColorTexture(Theme.Unpack(self.open and "glassActive" or "glassHover"))
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip, Theme.Unpack("accentHi"))
        GameTooltip:AddLine(L["Click to see who has them. Right-click to change it."],
            Theme.Unpack("dim"))
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.fill:SetColorTexture(Theme.Unpack(self.open and "glassActive" or self.band))
        GameTooltip:Hide()
    end)
    list.rows[index] = row
    return row
end

--- A character's line under an open item: whole name, then where they are.
local function AcrossLine(list, index)
    local line = list.lines[index]
    if line then return line end
    line = CreateFrame("Frame", nil, list)
    line:SetWidth(COLUMN_WIDTH)
    line.fill = Theme.Fill(line, "glassAlt")
    line.name = Theme.CreateLabel(line, "small", "text")
    line.name:SetPoint("LEFT", 20, 0)
    line.name:SetWidth(150)
    line.name:SetWordWrap(true)
    line.where = Theme.CreateLabel(line, "small", "muted", "RIGHT")
    line.where:SetPoint("RIGHT", -8, 0)
    line.where:SetPoint("LEFT", line.name, "RIGHT", 6, 0)
    line.where:SetWordWrap(true)
    list.lines[index] = line
    return line
end

--- Where a character's copies are: "60 bags, 30 bank".
function SettingsUI.AcrossWhere(holder)
    local parts = {}
    if (holder.bags or 0) > 0 then parts[#parts + 1] = L.Format("%d bags", holder.bags) end
    if (holder.bank or 0) > 0 then parts[#parts + 1] = L.Format("%d bank", holder.bank) end
    if (holder.mail or 0) > 0 then parts[#parts + 1] = L.Format("%d mail", holder.mail) end
    if #parts == 0 then return L["None"] end
    return table.concat(parts, ", ")
end

--- Keep across characters: a row an item, the open ones' characters under
--- them, the ticks and the count. Only drawn while Settings shows.
function SettingsUI:SyncKeepAcross()
    local controls = self.controls
    local list = controls and controls.acrossList
    if not (list and ns.KeepAcross) then return end
    local across = ns.KeepAcross
    if controls.acrossBank.SetChecked then controls.acrossBank:SetChecked(across:CountsBank()) end
    if controls.acrossMail.SetChecked then controls.acrossMail:SetChecked(across:CountsMail()) end

    local items = across:Items()
    local n = #items
    controls.acrossCount:SetText(n == 1 and L.Format("%d item kept", n) or L.Format("%d items kept", n))
    if self.frame and self.frame.IsShown and not self.frame:IsShown() then
        list.stale = true
        return
    end
    list.stale = nil

    local y, rowCount, lineCount = ACROSS_HEADER, 0, 0
    for index, each in ipairs(items) do
        local status = across:Status(each.itemID)
        if status then
            rowCount = rowCount + 1
            local row = AcrossRow(list, rowCount)
            row.itemID = each.itemID
            row.open = SettingsUI.acrossOpen[each.itemID] and true or false
            row.band = (index % 2 == 0) and "glassAlt" or "glass"
            row.fill:SetColorTexture(Theme.Unpack(row.open and "glassActive" or row.band))
            row.edge:SetShown(row.open)
            local name = ns.KeepAcrossUI and ns.KeepAcrossUI.ItemName(each.itemID) or tostring(each.itemID)
            row.name:SetText(ns.Items:ColorName(name, each.itemID) or name)
            local all = ns.KeepHere.IsAll(status.count)
            row.keep:SetText(all and L["All"] or tostring(status.count))
            row.have:SetText(tostring(status.have))
            if status.short > 0 then
                row.status:SetText(L.Format("Short %d", status.short))
                row.status:SetTextColor(Theme.Unpack("warn"))
                row.tip = L.Format("Your characters need %d more.", status.short)
            else
                row.status:SetText(L["Kept"])
                row.status:SetTextColor(Theme.Unpack("good"))
                row.tip = all and L["Your characters keep every one."] or L["Your characters have enough."]
            end
            local height = TextHeight(row.name, ACROSS_ROW)
            row:SetHeight(height)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
            row:Show()
            y = y + height
            if row.open then
                for _, holder in ipairs(status.holders) do
                    lineCount = lineCount + 1
                    local line = AcrossLine(list, lineCount)
                    local who = holder.name ~= "" and holder.name or (UnitName and UnitName("player") or "")
                    line.name:SetText(holder.isCurrent and L.Format("%s (you)", who) or who)
                    line.where:SetText(SettingsUI.AcrossWhere(holder))
                    local lineHeight = math.max(TextHeight(line.name, ACROSS_LINE),
                        TextHeight(line.where, ACROSS_LINE))
                    line:SetHeight(lineHeight)
                    line:ClearAllPoints()
                    line:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
                    line:Show()
                    y = y + lineHeight
                end
            end
        end
    end
    for i = rowCount + 1, #list.rows do list.rows[i]:Hide() end
    for i = lineCount + 1, #list.lines do list.lines[i]:Hide() end
    list.empty:SetShown(rowCount == 0)
    if rowCount == 0 then y = y + ACROSS_ROW end

    local height = math.ceil(y + 2)
    if list.fixedHeight ~= height then
        list.fixedHeight = height
        list:SetHeight(height)
        if self.pages and self.pages.fitted then self.pages:Fit() end
    end
end

--------------------------------------------------------------------------------
-- Mail rules: one list of every mail rule (a player asked for several, the
-- owner said build it from a mockup, 2026-11-12). Logic/MailRules.lua.
--------------------------------------------------------------------------------

local RULE_NAME_WIDTH = 132
local RULE_TO_LEFT = 146
local RULE_TO_WIDTH = 112
local RULE_ROW = 22
local RULE_HEADER = 18

-- The sort a heading picked and whether kinds show, for this session only.
SettingsUI.ruleSort = nil
SettingsUI.ruleSortDown = false
SettingsUI.ruleKinds = false

--- What a rule's first column says: the item (in its colour) or the name.
function SettingsUI.RuleName(row)
    if row.kind == "item" or row.kind == "learned" then
        local name = ns.KeepAcrossUI and ns.KeepAcrossUI.ItemName(row.itemID) or tostring(row.itemID)
        return name, ns.Items:ColorName(name, row.itemID) or name
    end
    local name = row.name or ""
    return name, name
end

--- The rules in the order the headings ask: as Butler gathers them, or by
--- item, name or where it came from. A third click goes back.
function SettingsUI.SortedRules(rows)
    local by = SettingsUI.ruleSort
    if not by then return rows end
    local down = SettingsUI.ruleSortDown
    local function Key(row)
        if by == "to" then return (row.to or ""):lower() end
        if by == "from" then return (row.from or ""):lower() end
        return (SettingsUI.RuleName(row)):lower()
    end
    local keyed = {}
    for index, row in ipairs(rows) do keyed[index] = { row = row, key = Key(row), at = index } end
    table.sort(keyed, function(a, b)
        if a.key == b.key then return a.at < b.at end
        if down then return a.key > b.key end
        return a.key < b.key
    end)
    local sorted = {}
    for index, each in ipairs(keyed) do sorted[index] = each.row end
    return sorted
end

--- A click on a heading: sort by it, again to turn it round, a third time
--- back to the usual order.
function SettingsUI:SortRules(by)
    if SettingsUI.ruleSort ~= by then
        SettingsUI.ruleSort, SettingsUI.ruleSortDown = by, false
    elseif not SettingsUI.ruleSortDown then
        SettingsUI.ruleSortDown = true
    else
        SettingsUI.ruleSort, SettingsUI.ruleSortDown = nil, false
    end
    self:SyncMailRules()
end

--- Change who a rule goes to: the item menu's mail page at the mouse.
function SettingsUI.ChangeRule(row)
    if not (row and ns.UI and ns.UI.ShowMailMenuFor) then return end
    ns.UI:ShowMailMenuFor({ mailRule = row, itemID = row.itemID, name = (SettingsUI.RuleName(row)),
        fromSettings = true })
end

--- Add Rule: the item on the cursor, else ask for one, then who it goes to.
function SettingsUI.AddRule()
    if not (ns.UI and ns.UI.ShowMailMenuFor) then return end
    local itemID = ns.KeepAcrossUI and ns.KeepAcrossUI.Cursor()
    if itemID then
        if ClearCursor then pcall(ClearCursor) end
        ns.UI:ShowMailMenuFor({ itemID = itemID, name = ns.KeepAcrossUI.ItemName(itemID), fromSettings = true })
    else
        ns.UI:ShowMailMenuFor({ askItem = true, fromSettings = true })
    end
end

--- The ITEM OR KIND, GOES TO and FROM headings, each a sort button.
function SettingsUI.BuildRuleHeader(list)
    list.heads = {}
    local function Heading(by, text, left, width, justify)
        local head = CreateFrame("Button", nil, list)
        head:SetHeight(RULE_HEADER)
        head.label = Theme.CreateLabel(head, "tiny", "heading", justify)
        head.label:SetAllPoints()
        head.text = text
        head.label:SetText(text)
        if justify == "RIGHT" then
            head:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, 0)
        else
            head:SetPoint("TOPLEFT", list, "TOPLEFT", left, 0)
        end
        head:SetWidth(width)
        head:SetScript("OnClick", function() SettingsUI:SortRules(by) end)
        head:SetScript("OnEnter", function(self) self.label:SetTextColor(Theme.Unpack("accentHi")) end)
        head:SetScript("OnLeave", function(self) self.label:SetTextColor(Theme.Unpack("heading")) end)
        list.heads[by] = head
    end
    Heading("item", L["ITEM OR KIND"], 8, RULE_NAME_WIDTH)
    Heading("to", L["GOES TO"], RULE_TO_LEFT, RULE_TO_WIDTH)
    Heading("from", L["FROM"], 0, 60, "RIGHT")
    list.rows = {}
    list.empty = Theme.CreateLabel(list, "small", "dim")
    list.empty:SetPoint("TOPLEFT", 8, -(RULE_HEADER + 4))
    list.empty:SetText(L["No mail rules yet"])
end

--- A rule's row: dark glass, the item or kind, who it goes to and where the
--- rule lives.
local function RuleRow(list, index)
    local row = list.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, list)
    row:SetWidth(COLUMN_WIDTH)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
    row.edge:SetColorTexture(Theme.Unpack("accentHi"))
    row.edge:Hide()
    row.name = Theme.CreateLabel(row, "normal", "text")
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetWidth(RULE_NAME_WIDTH)
    row.name:SetWordWrap(true)
    row.to = Theme.CreateLabel(row, "normal", "text")
    row.to:SetPoint("LEFT", RULE_TO_LEFT, 0)
    row.to:SetWidth(RULE_TO_WIDTH)
    row.to:SetWordWrap(true)
    row.from = Theme.CreateLabel(row, "small", "muted", "RIGHT")
    row.from:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnClick", function(self, button)
        local rule = self.rule
        if not rule then return end
        if button == "RightButton" and ns.RowMenu then
            ns.RowMenu:Open({
                { text = L["Change"], run = function() SettingsUI.ChangeRule(rule) end },
                { text = L["Remove"], run = function()
                    ns.MailRules:Remove(rule)
                    SettingsUI:SyncMailRules()
                end },
            }, { title = self.shown })
            return
        end
        SettingsUI.ChangeRule(rule)
    end)
    row:SetScript("OnEnter", function(self)
        self.fill:SetColorTexture(Theme.Unpack("glassHover"))
        self.edge:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.shown or "", Theme.Unpack("accentHi"))
        if self.notOwn then
            GameTooltip:AddLine(L["This isn't one of your characters."], Theme.Unpack("warn"))
        end
        GameTooltip:AddLine(L["Click to change who gets it. Right-click for more."], Theme.Unpack("dim"))
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

--- Mail rules: a row a rule, the headings' sort and the count. Only drawn
--- while Settings shows.
function SettingsUI:SyncMailRules()
    local controls = self.controls
    local list = controls and controls.ruleList
    if not (list and ns.MailRules) then return end
    if controls.ruleKinds and controls.ruleKinds.SetText then
        controls.ruleKinds:SetText(SettingsUI.ruleKinds and L["Hide Kinds"] or L["Show Kinds"])
    end
    local rows = SettingsUI.SortedRules(ns.MailRules:All(SettingsUI.ruleKinds))
    local n = #rows
    controls.ruleCount:SetText(n == 1 and L.Format("%d rule", n) or L.Format("%d rules", n))
    for by, head in pairs(list.heads) do
        local arrow = ""
        if SettingsUI.ruleSort == by then arrow = SettingsUI.ruleSortDown and " v" or " ^" end
        head.label:SetText(head.text .. arrow)
    end
    if self.frame and self.frame.IsShown and not self.frame:IsShown() then
        list.stale = true
        return
    end
    list.stale = nil

    local y = RULE_HEADER
    for index, rule in ipairs(rows) do
        local row = RuleRow(list, index)
        row.rule = rule
        row.band = (index % 2 == 0) and "glassAlt" or "glass"
        row.fill:SetColorTexture(Theme.Unpack(row.band))
        local plain, colored = SettingsUI.RuleName(rule)
        row.shown = plain
        row.name:SetText(colored)
        row.to:SetText(rule.to or "")
        row.notOwn = not ns.MailRules.IsOwn(rule.to)
        row.to:SetTextColor(Theme.Unpack(row.notOwn and "warn" or "text"))
        row.from:SetText(rule.from or "")
        local height = math.max(TextHeight(row.name, RULE_ROW), TextHeight(row.to, RULE_ROW))
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        row:Show()
        y = y + height
    end
    for i = n + 1, #list.rows do list.rows[i]:Hide() end
    list.empty:SetShown(n == 0)
    if n == 0 then y = y + RULE_ROW end

    local height = math.ceil(y + 2)
    if list.fixedHeight ~= height then
        list.fixedHeight = height
        list:SetHeight(height)
        if self.pages and self.pages.fitted then self.pages:Fit() end
    end
end

--- The bank alt page: who, when, which list and the kinds, as saved.
function SettingsUI:SyncBankAlt()
    local controls = self.controls
    if not (controls and controls.bankAltPick) then return end
    local BankAlt = ns.BankAlt
    local picked = BankAlt:Name()
    local names, seen = { L["Nobody"] }, {}
    local playing = ns.Errands:PlayingName()
    for _, name in ipairs(ns.Errands:Characters()) do seen[name] = true end
    if playing then seen[playing] = true end
    if picked then seen[picked] = true end
    local sorted = {}
    for name in pairs(seen) do sorted[#sorted + 1] = name end
    table.sort(sorted)
    for _, name in ipairs(sorted) do names[#names + 1] = name end
    controls.bankAltPick:SetNames(names)
    controls.bankAltPick:Select(picked)
    controls.bankAltPick.text:SetTextColor(Theme.Unpack((picked and not BankAlt:IsKnown(picked)) and "warn" or "text"))

    local lists = { L["None"] }
    for _, name in ipairs(BankAlt:ListNames()) do lists[#lists + 1] = name end
    local list = BankAlt:ListName()
    local known = false
    for _, name in ipairs(lists) do known = known or name == list end
    if list and not known then lists[#lists + 1] = list end
    controls.bankAltList:SetNames(lists)
    controls.bankAltList:Select(list)

    for index, when in ipairs(BankAlt.WHEN) do
        if when == BankAlt:When() then controls.bankAltWhen:SetValue(index, true) end
    end
    for key, box in pairs(controls.bankAltKinds) do box:SetChecked(BankAlt:KindOn(key)) end
    for key, kindPicker in pairs(controls.bankAltKindTo or {}) do
        local to = BankAlt:KindTo(key)
        local choices = { L["Bank Alt"] }
        local listed = false
        for _, name in ipairs(ns.Errands:Characters()) do
            choices[#choices + 1] = name
            listed = listed or name == to
        end
        table.sort(choices, function(a, b)
            if a == L["Bank Alt"] then return b ~= a end
            if b == L["Bank Alt"] then return false end
            return a < b
        end)
        if to and not listed then table.insert(choices, 2, to) end
        choices[#choices + 1] = L["Type a Name..."]
        kindPicker:SetNames(choices)
        kindPicker:Select(to)
        kindPicker.text:SetTextColor(Theme.Unpack((to and not BankAlt:IsKnown(to)) and "warn" or "text"))
    end
    if controls.bankAltAuctions then controls.bankAltAuctions:SetChecked(BankAlt:AuctionsOn()) end
    if controls.bankAltFullStacks then controls.bankAltFullStacks:SetChecked(BankAlt:FullStacksOn()) end
    if controls.bankAltStore then controls.bankAltStore:SetChecked(BankAlt:StoreOn()) end
end

--- The Tradeskills list picked on the Lists page: { name, id, items }, or
--- nil when there are none.
function SettingsUI:PickedList()
    local controls = self.controls
    local lists = self.listsState or {}
    return controls and controls.listsPick and lists[controls.listsPick.index] or nil
end

--- The Lists page: the player's Tradeskills lists, and the picked one's
--- Mail To and Keep Here as saved.
function SettingsUI:SyncLists()
    local controls = self.controls
    if not (controls and controls.listsPick and ns.ListRules) then return end
    local lists = {}
    for _, list in ipairs(ns.ListRules:Lists(true)) do
        if list.id ~= nil then lists[#lists + 1] = list end
    end
    self.listsState = lists
    local names = {}
    for _, list in ipairs(lists) do names[#names + 1] = list.name end
    controls.listsPick:SetNames(names)
    if #names == 0 then controls.listsPick.text:SetText(L["None"]) end

    local list = self:PickedList()
    local rule = list and ns.ListRules:Get(list.id) or {}
    local picked = rule.mailTo
    -- Never the character playing: it can't mail itself.
    local choices, seen, sorted = { L["Nobody"] }, {}, {}
    for _, name in ipairs(ns.Errands:Characters()) do
        if not seen[name] and not ns.Verdicts:IsMe(name) then
            seen[name] = true
            sorted[#sorted + 1] = name
        end
    end
    if picked and not seen[picked] then sorted[#sorted + 1] = picked end
    table.sort(sorted)
    for _, name in ipairs(sorted) do choices[#choices + 1] = name end
    controls.listsMailTo:SetNames(choices)
    controls.listsMailTo:Select(picked)
    -- Dim with no list to set it for.
    controls.listsMailTo:SetAlpha(list and 1 or 0.45)

    if not controls.listsKeep.editBox:HasFocus() then
        controls.listsKeep:SetText(rule.keep and tostring(rule.keep) or "")
    end
end

function SettingsUI:BuildPages()
    local controls = self.controls
    local pages = self.pages

    -- Selling: the vendor on the left, the player's lists on the right.
    -- Where Butler opens by itself: one row, a tick a place (2026-11-16,
    -- from a mockup). The saved keys are as they were.
    pages:Section("selling", 1, L["OPEN BUTLER"])
    local openWords = {
        L["Opens Butler at every vendor. Nothing sells until you click Sell."],
        L["Opens Butler at every mailbox. Fill Mail fills in the mail and you press Send. Needs Blackthornes Tradeskills."],
        L["Opens Butler at the bank when there's something to move."],
    }
    local openRow = pages:Row("selling", 1, L["Open Butler At:"], table.concat(openWords, " "))
    controls.openAtVendor = Widgets.CreateCheckbox(openRow, L["Vendors"], function(checked)
        ns.db.openAtVendor = checked
    end, true)
    controls.openAtMailbox = Widgets.CreateCheckbox(openRow, L["Mailboxes"], function(checked)
        ns.db.openAtMailbox = checked
    end, true)
    controls.openAtBank = Widgets.CreateCheckbox(openRow, L["The Bank"], function(checked)
        ns.db.openAtBank = checked
    end, true)
    SettingsUI.Hover(controls.openAtVendor, openWords[1])
    SettingsUI.Hover(controls.openAtMailbox, openWords[2])
    SettingsUI.Hover(controls.openAtBank, openWords[3])
    SettingsUI.Flow(openRow, { controls.openAtVendor, controls.openAtMailbox, controls.openAtBank })

    -- The slim bar under the game's window, in the big window's stead
    -- (UI/PlaceBar.lua). Off unless ticked.
    local barRow = pages:Row("selling", 1, L["Butler Bar:"],
        L["Shows a small bar under the vendor, mailbox or bank window, in place of the Butler window. Click Open on the bar when you want the window."])
    controls.placeBar = Widgets.CreateCheckbox(barRow, L["On"], function(checked)
        if ns.PlaceBar then ns.PlaceBar:SetOn(checked) else ns.db.placeBar = checked end
    end, true)
    controls.placeBar:SetPoint("TOPLEFT", CONTROL_X, -2)

    pages:Section("selling", 1, L["AT A VENDOR"])

    local buyRow = pages:Row("selling", 1, L["Buy More:"],
        L["Shift-click an item at a vendor to buy as many as you want, like 200."])
    controls.buyMany = Widgets.CreateCheckbox(buyRow, L["On"], function(checked)
        ns.BuyMany:SetOn(checked)
    end, true)
    controls.buyMany:SetPoint("TOPLEFT", CONTROL_X, -2)

    pages:Section("selling", 1, L["MAIL AND BANK"])

    local nextRow = pages:Row("selling", 1, L["Fill the Next Mail:"],
        L["After you send one, Butler fills the next character's mail."])
    controls.fillNext = Widgets.CreateCheckbox(nextRow, L["On"], function(checked)
        ns.db.fillNext = checked
    end, true)
    controls.fillNext:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- The Pick button by the mail To box (UI/MailPicker.lua, 2026-11-09).
    local pickRow = pages:Row("selling", 1, L["Name Picker:"], nil)
    controls.namePicker = Widgets.CreateCheckbox(pickRow, L["On"], function(checked)
        ns.MailPicker:SetEnabled(checked)
    end, false)
    controls.namePicker:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Jobs for the craft queue on other characters (Logic/Jobs.lua, asked
    -- 2026-10-11).
    local jobRow = pages:Row("selling", 1, L["Jobs at Login:"],
        L["Opens Butler at login when this character has crafting or mail to do."])
    controls.jobsAtLogin = Widgets.CreateCheckbox(jobRow, L["On"], function(checked)
        ns.db.jobsAtLogin = checked
    end, true)
    controls.jobsAtLogin:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Items for your quests (Logic/Quests.lua, a player asked 2026-10-14).
    local questRow = pages:Row("selling", 1, L["Quest Items:"],
        L["Keeps what your quests need and lists what's still missing."])
    controls.questItems = Widgets.CreateCheckbox(questRow, L["On"], function(checked)
        ns.Quests:SetOn(checked)
    end, true)
    controls.questItems:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Buy them at the auction house (Logic/QuestBuy.lua, 2026-10-18).
    local questBuyRow = pages:Row("selling", 1, L["Buy Quest Items:"],
        L["At the auction house, lists each item your quests need with its price and a Buy button."])
    controls.questBuy = Widgets.CreateCheckbox(questBuyRow, L["On"], function(checked)
        ns.QuestBuy:SetOn(checked)
    end, false)
    controls.questBuy:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Mail running out on any of your characters (Logic/MailRunsOut.lua,
    -- the owner said build it 2026-11-09). Off unless ticked.
    pages:Section("selling", 2, L["MAILBOX"])
    local runsOutRow = pages:Row("selling", 2, L["Mail Running Out:"], nil)
    controls.mailRunsOut = Widgets.CreateCheckbox(runsOutRow, L["On"], function(checked)
        ns.MailRunsOut:SetOn(checked)
    end, false)
    controls.mailRunsOut:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- What a mail holds, on its row's tooltip in the inbox (2026-11-09).
    local mailContentsRow = pages:Row("selling", 2, L["Mail Contents:"], nil)
    controls.mailContents = Widgets.CreateCheckbox(mailContentsRow, L["On"], function(checked)
        ns.MailContents:SetEnabled(checked)
    end, false)
    controls.mailContents:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- The owner asked 2026-10-14: on the disenchanter, break every green.
    pages:Section("selling", 2, L["DISENCHANTING"])

    local greensRow = pages:Row("selling", 2, L["Disenchant Greens Here:"],
        L["On your disenchanter, greens go under Disenchant unless selling pays more. Crafted greens, upgrades and things you need are still kept."])
    controls.disenchantGreens = Widgets.CreateCheckbox(greensRow, L["On"], function(checked)
        ns.Verdicts:SetDisenchantGreens(checked)
    end)
    controls.disenchantGreens:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- A player asked, the owner said yes (2026-10-16): your disenchanter
    -- takes a green only when breaking it pays as much as selling it,
    -- unless this is ticked. Levelling Enchanting takes it either way
    -- (the owner, 2026-10-17).
    local alwaysRow = pages:Row("selling", 2, L["Always Disenchant:"],
        L["Greens go to your disenchanter even when selling them pays more."])
    controls.alwaysDisenchant = Widgets.CreateCheckbox(alwaysRow, L["On"], function(checked)
        ns.Verdicts:SetAlwaysDisenchant(checked)
    end)
    controls.alwaysDisenchant:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Asked 2026-10-11: anything worth less than this joins Sell. It only
    -- ever adds to Sell; nothing sells until the player clicks.
    pages:Section("selling", 2, L["JUNK AND CRAFTING"])

    local belowRow = pages:Row("selling", 2, L["Sell Below:"],
        L["Anything worth less than this goes under Sell. 0 turns it off."])
    controls.sellBelow = Widgets.CreateMoneyBox(belowRow, function(copper)
        ns.Verdicts:SetSellBelow(copper)
    end)
    controls.sellBelow:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- A player asked, the owner said build it (2026-10-19): say when a
    -- known craft earns more than selling. Off unless ticked.
    local craftRow = pages:Row("selling", 2, L["Craft When It Pays More:"],
        L["Butler checks the recipes you know and says when crafting earns more than selling. Needs Blackthornes Tradeskills."])
    controls.craftPays = Widgets.CreateCheckbox(craftRow, L["On"], function(checked)
        ns.Verdicts:SetCraftPays(checked)
    end)
    controls.craftPays:SetPoint("TOPLEFT", CONTROL_X, -2)

    pages:Section("keep", 1, L["YOUR LISTS"])

    local learnRow = pages:Row("keep", 1, L["Learn From You:"],
        L["Butler learns what you keep, sell and mail. Your right-click picks always win."])
    controls.learn = Widgets.CreateCheckbox(learnRow, L["On"], function(checked)
        ns.db.learn = checked
        ns.Verdicts:Changed(true)
    end)
    controls.learn:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Keep Level Up Materials (the owner said build it, 2026-11-17).
    pages:Section("keep", 1, L["LEVELING PROFESSIONS"])

    local levelUpRow = pages:Row("keep", 1, L["Keep Level Up Materials:"],
        L["Keeps the materials for crafts that still give you skill points, in every profession. Cooking and First Aid too. Needs Blackthornes Tradeskills."])
    controls.keepLevelUp = Widgets.CreateCheckbox(levelUpRow, L["On"], function(checked)
        ns.Verdicts:SetKeepLevelUp(checked)
    end)
    controls.keepLevelUp:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Upgrades held back from a character (the owner asked 2026-10-12):
    -- right-click an upgrade under Mail to hold it back; undone here.
    pages:Section("keep", 1, L["UPGRADES FOR YOUR CHARACTERS"])

    local altRow = pages:Row("keep", 1, L["Mail Upgrades to Alts:"],
        L["Gear that's an upgrade for another of your characters goes under Mail. Needs Blackthornes Equipment."])
    controls.altUpgrades = Widgets.CreateCheckbox(altRow, L["On"], function(checked)
        ns.Verdicts:SetAltUpgrades(checked)
    end)
    controls.altUpgrades:SetPoint("TOPLEFT", CONTROL_X, -2)

    local heldRow = pages:Row("keep", 1, L["Character:"],
        L["Pick a character to see what you hold back from them."])
    controls.heldPick = SettingsUI.CharacterPicker(heldRow, CONTROL_X, function()
        SettingsUI:SyncHeld()
    end)

    local allRow = pages:Row("keep", 1, L["Mail Them Upgrades:"], nil)
    controls.heldAll = Widgets.CreateCheckbox(allRow, L["On"], function(checked)
        local name = controls.heldPick:GetName()
        if name then ns.Verdicts:HoldAllUpgrades(name, not checked) end
    end)
    controls.heldAll:SetPoint("TOPLEFT", CONTROL_X, -2)

    local itemsRow = pages:Row("keep", 1, L["Items Held Back:"],
        L["Lets these items go to this character again."])
    controls.heldItems = Widgets.CreateButton(itemsRow, L["Undo"], function()
        local name = controls.heldPick:GetName()
        if not name then return end
        for _, itemID in ipairs(ns.Verdicts:HeldItems(name)) do
            ns.Verdicts:HoldUpgrade(itemID, name, false)
        end
        SettingsUI:SyncHeld()
    end, { width = 100, height = 20 })
    controls.heldItems:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- How many of an item each character keeps (Logic/KeepHere.lua, a
    -- player asked, the owner said build it 2026-10-17). Set with a
    -- right-click in the Butler window; seen and changed here.
    pages:Section("keep", 2, L["KEEP ON EACH CHARACTER"])

    local keepWhoRow = pages:Row("keep", 2, L["Character:"],
        L["Right-click an item in the Butler window to keep some on the character you're on."])
    controls.keepWho = SettingsUI.CharacterPicker(keepWhoRow, CONTROL_X, function()
        controls.keepWhat.index = 1
        SettingsUI:SyncKeepHere()
    end)

    local keepWhatRow = pages:Row("keep", 2, L["Item:"], nil)
    controls.keepWhat = SettingsUI.CharacterPicker(keepWhatRow, CONTROL_X, function()
        SettingsUI:SyncKeepHere()
    end)

    local function KeepPicked()
        local state = SettingsUI.keepState
        return state.guids[controls.keepWho.index], state.items[controls.keepWhat.index]
    end

    local keepCountRow = pages:Row("keep", 2, L["Keep:"], L["0 takes it off the list. Keep All keeps every one."])
    local function SaveCount()
        local who, what = KeepPicked()
        if not (who and what) then return end
        local text = controls.keepCount.editBox:GetText()
        -- An empty box beside Keep All means it is still all.
        if (text == nil or text == "") and ns.KeepHere.IsAll(what.count) then return end
        local count = tonumber(text) or 0
        if count == what.count then return end
        ns.KeepHere:Set(what.itemID, count, who)
        SettingsUI:SyncKeepHere()
    end
    controls.keepCount = Widgets.CreateSearchBox(keepCountRow, "0", nil, SaveCount, { plain = true })
    controls.keepCount:SetSize(60, 24)
    controls.keepCount:SetPoint("TOPLEFT", CONTROL_X, 0)
    controls.keepCount.editBox:SetMaxLetters(4)
    if controls.keepCount.editBox.SetNumeric then controls.keepCount.editBox:SetNumeric(true) end
    controls.keepCount.editBox:HookScript("OnEditFocusLost", SaveCount)
    controls.keepAll = Widgets.CreateButton(keepCountRow, L["Keep All"], function()
        local who, what = KeepPicked()
        if not (who and what) or ns.KeepHere.IsAll(what.count) then return end
        ns.KeepHere:Set(what.itemID, ns.KeepHere.MOST, who)
        SettingsUI:SyncKeepHere()
    end, { width = 100, height = 20 })
    controls.keepAll:SetPoint("LEFT", controls.keepCount, "RIGHT", 6, 0)

    local keepRemoveRow = pages:Row("keep", 2, L["Remove:"], nil)
    controls.keepRemove = Widgets.CreateButton(keepRemoveRow, L["Remove"], function()
        local who, what = KeepPicked()
        if not (who and what) then return end
        ns.KeepHere:Set(what.itemID, 0, who)
        SettingsUI:SyncKeepHere()
    end, { width = 100, height = 20 })
    controls.keepRemove:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- Keep across characters (Logic/KeepAcross.lua, a player asked, the
    -- owner said build it from a mockup 2026-11-07): one number an item for
    -- the account, a row each with what is kept, what all the characters
    -- have and whether that's enough. A click opens who has them.
    local acrossHead = pages:Section("keep", 2, L["KEEP ACROSS CHARACTERS"])
    controls.acrossAdd = Widgets.CreateButton(acrossHead, L["Add Item"], function()
        if ns.KeepAcrossUI then ns.KeepAcrossUI:Open() end
    end, { height = 18 })
    controls.acrossAdd:SetPoint("BOTTOMRIGHT", acrossHead, "TOPRIGHT", 0, -12)

    local acrossList = CreateFrame("Frame", nil, pages.pages.keep.content)
    acrossList:SetWidth(COLUMN_WIDTH)
    acrossList.fixedHeight = 40
    acrossList:SetHeight(40)
    pages:Place("keep", 2, acrossList, 4)
    controls.acrossList = acrossList
    SettingsUI.BuildAcrossHeader(acrossList)

    local acrossBankRow = pages:Row("keep", 2, L["Count Bank:"], nil)
    controls.acrossBank = Widgets.CreateCheckbox(acrossBankRow, L["On"], function(checked)
        if ns.KeepAcross then ns.KeepAcross:SetCountsBank(checked) end
    end)
    controls.acrossBank:SetPoint("TOPLEFT", CONTROL_X, 0)

    local acrossMailRow = pages:Row("keep", 2, L["Count Mail:"], nil)
    controls.acrossMail = Widgets.CreateCheckbox(acrossMailRow, L["On"], function(checked)
        if ns.KeepAcross then ns.KeepAcross:SetCountsMail(checked) end
    end)
    controls.acrossMail:SetPoint("TOPLEFT", CONTROL_X, 0)

    local acrossFoot = CreateFrame("Frame", nil, pages.pages.keep.content)
    acrossFoot:SetSize(COLUMN_WIDTH, 16)
    acrossFoot.fixedHeight = 16
    pages:Place("keep", 2, acrossFoot, 6)
    controls.acrossCount = Theme.CreateLabel(acrossFoot, "small", "muted")
    controls.acrossCount:SetPoint("LEFT", 0, 0)
    local acrossSaves = Theme.CreateLabel(acrossFoot, "small", "dim", "RIGHT")
    acrossSaves:SetPoint("RIGHT", 0, 0)
    acrossSaves:SetText(L["Changes save as you make them."])

    -- Bank alt (Logic/BankAlt.lua, a player asked, the owner said build it
    -- 2026-10-14): who, where it sits among the verdicts and which list on
    -- the left, the kinds of items on the right.
    pages:Section("bankalt", 1, L["BANK ALT"])

    local altRow = pages:Row("bankalt", 1, L["Send To:"],
        L["The character that gets the kinds of items you tick. Fill Mail sends them. A name in amber isn't one of your characters here."])
    controls.bankAltPick = SettingsUI.CharacterPicker(altRow, CONTROL_X, function()
        local picker = controls.bankAltPick
        ns.BankAlt:SetName(picker.index > 1 and picker:GetName() or nil)
    end)

    -- A character on another account, typed by hand (a player asked, the
    -- owner said yes, 2026-10-16). A name that isn't one of the player's
    -- characters shows in amber on the Send To row, so a typo stands out.
    local typeRow = pages:Row("bankalt", 1, L["Type a Name:"],
        L["For a character on your other account. Type the whole name, first and last."])
    controls.bankAltTyped = Widgets.CreateSearchBox(typeRow, L["First Last"], nil, function(text)
        local name, why = ns.BankAlt:TypeName(text)
        controls.bankAltTyped:SetText("")
        if not name and why then ns.Print(why) end
    end, { plain = true })
    controls.bankAltTyped:SetPoint("TOPLEFT", CONTROL_X, 0)
    controls.bankAltTyped:SetWidth(180)

    local whenRow = pages:Row("bankalt", 1, L["When:"],
        L["Before Everything sends what you tick, even things that sell well. Before a Vendor lets the auction house and disenchanting go first. Only Leftovers sends what's left."])
    controls.bankAltWhen = Widgets.CreateChoice(whenRow, {
        min = 1, max = #ns.BankAlt.WHEN, step = 1,
        format = function(value) return ns.BankAlt.WHEN_LABELS[ns.BankAlt.WHEN[value]] end,
        onChange = function(value) ns.BankAlt:SetWhen(ns.BankAlt.WHEN[value]) end,
    })
    ns.SettingsPages.FitStepper(controls.bankAltWhen, ns.BankAlt.WHEN_LABELS)
    controls.bankAltWhen:SetPoint("TOPLEFT", CONTROL_X, -2)

    local listRow = pages:Row("bankalt", 1, L["Shopping List:"],
        L["Everything on this list goes to the bank alt too."])
    controls.bankAltList = SettingsUI.CharacterPicker(listRow, CONTROL_X, function()
        local picker = controls.bankAltList
        ns.BankAlt:SetList(picker.index > 1 and picker:GetName() or nil)
    end)

    -- Rules for each of the player's Tradeskills lists (Logic/ListRules.lua,
    -- the owner said build it, 2026-10-19): pick a list, then who it mails
    -- to and how many of each stay on every character.
    pages:Section("bankalt", 1, L["YOUR TRADESKILLS LISTS"])
    local listRow = pages:Row("bankalt", 1, "", nil)
    controls.listsPick = SettingsUI.CharacterPicker(listRow, 0, function()
        SettingsUI:SyncLists()
    end)
    controls.listsPick.least = COLUMN_WIDTH
    controls.listsPick:SetWidth(COLUMN_WIDTH)

    local mailToRow = pages:Row("bankalt", 1, L["Mail To:"], nil)
    controls.listsMailTo = SettingsUI.CharacterPicker(mailToRow, CONTROL_X, function()
        local list = SettingsUI:PickedList()
        if not list then return end
        local picker = controls.listsMailTo
        ns.ListRules:SetMailTo(list.id, picker.index > 1 and picker:GetName() or nil)
    end)

    local keepRow = pages:Row("bankalt", 1, L["Keep Here:"], nil)
    local function SaveListKeep()
        local list = SettingsUI:PickedList()
        if not list then return end
        local count = tonumber(controls.listsKeep.editBox:GetText()) or 0
        if count == (ns.ListRules:Get(list.id).keep or 0) then return end
        ns.ListRules:SetKeep(list.id, count)
    end
    controls.listsKeep = Widgets.CreateSearchBox(keepRow, "0", nil, SaveListKeep, { plain = true })
    controls.listsKeep:SetSize(60, 24)
    controls.listsKeep:SetPoint("TOPLEFT", CONTROL_X, 0)
    controls.listsKeep.editBox:SetMaxLetters(4)
    if controls.listsKeep.editBox.SetNumeric then controls.listsKeep.editBox:SetNumeric(true) end
    controls.listsKeep.editBox:HookScript("OnEditFocusLost", SaveListKeep)
    local keepNote = Theme.CreateLabel(keepRow, "tiny", "muted")
    keepNote:SetPoint("LEFT", controls.listsKeep, "RIGHT", 6, 0)
    keepNote:SetWidth(COLUMN_WIDTH - CONTROL_X - 66)
    keepNote:SetWordWrap(true)
    keepNote:SetText(L["of each, on every character"])

    -- Mail rules (a player asked for several, the owner said build it from
    -- a mockup, 2026-11-12): every mail rule in one list, wherever it lives.
    local ruleHead = pages:Section("bankalt", 1, L["MAIL RULES"])
    controls.ruleAdd = Widgets.CreateButton(ruleHead, L["Add Rule"], function()
        SettingsUI.AddRule()
    end, { height = 18, primary = true })
    controls.ruleAdd:SetPoint("BOTTOMRIGHT", ruleHead, "TOPRIGHT", 0, -12)
    controls.ruleKinds = Widgets.CreateButton(ruleHead, L["Show Kinds"], function()
        SettingsUI.ruleKinds = not SettingsUI.ruleKinds
        SettingsUI:SyncMailRules()
    end, { height = 18 })
    controls.ruleKinds:SetPoint("RIGHT", controls.ruleAdd, "LEFT", -4, 0)

    local ruleList = CreateFrame("Frame", nil, pages.pages.bankalt.content)
    ruleList:SetWidth(COLUMN_WIDTH)
    ruleList.fixedHeight = 40
    ruleList:SetHeight(40)
    pages:Place("bankalt", 1, ruleList, 4)
    controls.ruleList = ruleList
    SettingsUI.BuildRuleHeader(ruleList)

    local ruleFoot = CreateFrame("Frame", nil, pages.pages.bankalt.content)
    ruleFoot:SetSize(COLUMN_WIDTH, 16)
    ruleFoot.fixedHeight = 16
    pages:Place("bankalt", 1, ruleFoot, 6)
    controls.ruleCount = Theme.CreateLabel(ruleFoot, "small", "muted")
    controls.ruleCount:SetPoint("LEFT", 0, 0)
    local ruleSaves = Theme.CreateLabel(ruleFoot, "small", "dim", "RIGHT")
    ruleSaves:SetPoint("RIGHT", 0, 0)
    ruleSaves:SetText(L["Changes save as you make them."])

    pages:Section("bankalt", 2, L["WHAT GOES THERE"])
    controls.bankAltKinds, controls.bankAltKindTo, controls.bankAltKindTyped = {}, {}, {}
    -- The kinds' names as the Settings rows show them; chat keeps kind.label.
    local KIND_LABELS = {
        cloth = L["Cloth:"],
        leather = L["Leather:"],
        metal = L["Ore, Bars and Stone:"],
        herb = L["Herbs:"],
        meat = L["Meat and Cooking:"],
        elemental = L["Elemental:"],
        enchanting = L["Enchanting Materials:"],
        tradegoods = L["Other Trade Goods:"],
        boe = L["Gear That Binds When Worn:"],
    }
    for _, kind in ipairs(ns.BankAlt.KINDS) do
        local key = kind.key
        local description = key == "boe"
            and L["Green or better weapons and armor that bind when worn and aren't an upgrade for you."]
            or nil
        local row = pages:Row("bankalt", 2, KIND_LABELS[key] or kind.label, description)
        local box = Widgets.CreateCheckbox(row, "", function(checked)
            ns.BankAlt:SetKind(key, checked)
        end, true)
        box:SetPoint("TOPLEFT", CONTROL_X, -2)
        controls.bankAltKinds[key] = box

        -- Who this kind goes to (the owner said build it, 2026-11-09): the
        -- bank alt, one of the player's characters, or a name typed by hand.
        local typed
        local picker = SettingsUI.CharacterPicker(row, CONTROL_X + 26, function()
            local pick = controls.bankAltKindTo[key]
            if pick.index == #pick.names then
                pick:Hide()
                typed:Show()
                typed:SetText("")
                if typed.editBox.SetFocus then typed.editBox:SetFocus() end
                return
            end
            ns.BankAlt:SetKindTo(key, pick.index > 1 and pick:GetName() or nil)
        end)
        picker.least = 150
        controls.bankAltKindTo[key] = picker

        local function Back()
            if not typed:IsShown() then return end
            typed:Hide()
            picker:Show()
            SettingsUI:SyncBankAlt()
        end
        typed = Widgets.CreateSearchBox(row, L["First Last"], nil, function(text)
            local name, why = ns.BankAlt:TypeKindTo(key, text)
            if not name and why then ns.Print(why) end
            Back()
        end, { plain = true })
        typed:SetPoint("TOPLEFT", CONTROL_X + 26, 0)
        typed:SetWidth(150)
        typed:Hide()
        typed.editBox:HookScript("OnEditFocusLost", Back)
        controls.bankAltKindTyped[key] = typed
    end

    -- Auction Items (a player asked, the owner said build it, 2026-10-22):
    -- whatever Butler would auction goes too, whatever its kind.
    local auctionRow = pages:Row("bankalt", 2, L["Auction Items:"],
        L["Everything Butler would put on the auction house goes to the bank alt, whatever kind it is."])
    controls.bankAltAuctions = Widgets.CreateCheckbox(auctionRow, L["On"], function(checked)
        ns.BankAlt:SetAuctions(checked)
    end, false)
    controls.bankAltAuctions:SetPoint("TOPLEFT", CONTROL_X, -2)

    local fullRow = pages:Row("bankalt", 2, L["Full Stacks Only:"],
        L["Only mail stacks that are full. Smaller stacks stay in your bags."])
    controls.bankAltFullStacks = Widgets.CreateCheckbox(fullRow, L["On"], function(checked)
        ns.BankAlt:SetFullStacks(checked)
    end, false)
    controls.bankAltFullStacks:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Store in Bank (the owner said build it, 2026-11-17): on the bank alt
    -- itself, the ticked kinds go under Bank for Move to bank.
    local storeRow = pages:Row("bankalt", 2, L["Store in Bank:"],
        L["On the bank alt, everything ticked above goes in the bank when you click Move to bank."])
    controls.bankAltStore = Widgets.CreateCheckbox(storeRow, L["On"], function(checked)
        ns.BankAlt:SetStore(checked)
    end, false)
    controls.bankAltStore:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Gold: the gold fund (the owner asked 2026-10-11). The usual amount on
    -- the left, one character's own on the right. Logic/Funds.lua.
    pages:Section("gold", 1, L["GOLD FUND"])

    local minRow = pages:Row("gold", 1, L["Keep at Least:"],
        L["Every character keeps at least this much. A character with more can mail gold to one with less. 0 turns it off."])
    controls.goldMinimum = Widgets.CreateMoneyBox(minRow, function(copper)
        ns.Funds:SetMinimum(copper)
    end)
    controls.goldMinimum:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- Class spells to train (Logic/ClassTraining.lua, the owner said build
    -- it 2026-10-13).
    pages:Section("gold", 1, L["CLASS TRAINING"])

    local trainingRow = pages:Row("gold", 1, L["Class Training:"],
        L["Spells you can train show at the top of Jobs with their cost."])
    controls.classTraining = Widgets.CreateCheckbox(trainingRow, L["On"], function(checked)
        ns.ClassTraining:SetOn(checked)
        ns.Funds:Changed()
    end, true)
    controls.classTraining:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- The arrow's own rows, in the order every addon has them (the
    -- unified look, card 13): Use TomTom, Guide Me, Arrow Size.
    pages:Section("gold", 1, L["ARROW"])

    -- TomTom's arrow instead of Show the way's dial, when TomTom is
    -- installed (Logic/TomTom.lua). On unless unticked.
    local tomtomRow = pages:Row("gold", 1, L["Use TomTom:"],
        L["With TomTom installed, its arrow shows the way instead."])
    controls.useTomTom = Widgets.CreateCheckbox(tomtomRow, L["On"], function(checked)
        if ns.TomTom then ns.TomTom:SetOn(checked) end
    end, true)
    controls.useTomTom:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Show the way to a trainer far away step by step (Logic/Travel.lua,
    -- the same in every addon). On unless unticked.
    local guideRow = pages:Row("gold", 1, L["Guide Me:"],
        L["When the place is in another zone or across the sea, the arrow leads you there step by step."])
    controls.arrowRoute = Widgets.CreateCheckbox(guideRow, L["On"], function(checked)
        if ns.Travel then ns.Travel:SetOn(checked) end
    end, true)
    controls.arrowRoute:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- How big the whole arrow is drawn, 100% unless picked (the owner,
    -- 2026-10-26). The arrow keeps its spot.
    local arrowSizeRow = pages:Row("gold", 1, L["Arrow Size:"], nil)
    controls.arrowSize = Widgets.CreateChoice(arrowSizeRow, {
        min = 50, max = 100, step = 25, value = 100,
        format = function(percent) return ("%d%%"):format(percent) end,
        onChange = function(percent)
            if ns.WayArrowUI then ns.WayArrowUI:SetSize(percent) end
        end,
    })
    ns.SettingsPages.FitStepper(controls.arrowSize, { "50%", "75%", "100%" })
    controls.arrowSize:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Gold goals at the bottom of the window (Logic/GoldGoals.lua, the
    -- owner said build it 2026-10-13).
    pages:Section("gold", 1, L["GOLD GOALS"])

    local goalsRow = pages:Row("gold", 1, L["Gold Goals:"],
        L["Shows what your gold is for next: class spells, profession training and riding."])
    controls.goldGoals = Widgets.CreateCheckbox(goalsRow, L["On"], function(checked)
        ns.GoldGoals:SetOn(checked)
    end, true)
    controls.goldGoals:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- The cheapest skill-up in Jobs (Logic/SkillUp.lua, a player asked,
    -- the owner said build it 2026-10-19).
    pages:Section("gold", 1, L["PROFESSIONS"])

    local skillUpRow = pages:Row("gold", 1, L["Cheapest Skill-Up:"],
        L["Shows the cheapest craft for your next skill point in each profession. Needs Blackthornes Tradeskills."])
    controls.skillUp = Widgets.CreateCheckbox(skillUpRow, L["On"], function(checked)
        ns.SkillUp:SetOn(checked)
    end, false)
    controls.skillUp:SetPoint("TOPLEFT", CONTROL_X, -2)

    pages:Section("gold", 2, L["ONE CHARACTER"])

    local pickRow = pages:Row("gold", 2, L["Character:"],
        L["Give one character its own amount."])
    controls.goldPick = SettingsUI.CharacterPicker(pickRow, CONTROL_X, function()
        SettingsUI:SyncGoldFor()
    end)

    local ownRow = pages:Row("gold", 2, L["They Keep:"],
        L["0 means it can give all it has."])
    controls.goldFor = Widgets.CreateMoneyBox(ownRow, function(copper)
        local name = controls.goldPick:GetName()
        if name then ns.Funds:SetMinimumFor(name, copper) end
    end)
    controls.goldFor:SetPoint("TOPLEFT", CONTROL_X, 0)

    local usualRow = pages:Row("gold", 2, L["Back to Usual:"], nil)
    controls.goldUsual = Widgets.CreateButton(usualRow, L["Reset"], function()
        local name = controls.goldPick:GetName()
        if name then ns.Funds:SetMinimumFor(name, nil) end
        SettingsUI:SyncGoldFor()
    end, { width = 100, height = 20 })
    controls.goldUsual:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- All Addons: the rows every Blackthornes addon shares, shown once in
    -- the one window behind its gear (the owner said build it,
    -- 2026-11-16). General keeps only Butler's own. No setting was renamed
    -- and no saved choice changed.
    pages:Section("all", 1, L["ALL BLACKTHORNES ADDONS"])

    -- Asked 2026-10-10: the game's own look for players who would rather
    -- the windows matched the rest of their screen. Read at login, so it
    -- waits for /reload as Text size does. See UI/BlizzardLook.lua.
    local styleRow = pages:Row("all", 1, L["Window Style:"], nil)
    controls.windowStyle = SettingsUI.WindowStyleControl(styleRow, CONTROL_X)

    -- Bigger letters in the same windows, as Tradeskills has. Every size
    -- is read as text is drawn, so it waits for /reload.
    local textRow = pages:Row("all", 1, L["Text Size:"], nil)
    controls.textSize = ns.SettingsPages.TextSizeControl(textRow, CONTROL_X, function() return ns.db end)

    -- How much the windows move: they rise in, glow and glint at Full,
    -- only fade at Subtle and stay still at Off. Full until picked, and the
    -- same choice as every Blackthornes addon (UI/SharedChoices.lua).
    local effectsRow = pages:Row("all", 1, L["Effects:"], nil)
    local Motion = ns.Motion
    local effectNames = { full = L["Full"], subtle = L["Subtle"], off = L["Off"] }
    local function EffectIndex()
        local level = Motion.Level()
        for index, name in ipairs(Motion.LEVELS) do
            if name == level then return index end
        end
        return 1
    end
    controls.effects = Widgets.CreateChoice(effectsRow, {
        min = 1, max = #Motion.LEVELS, step = 1, value = EffectIndex(),
        format = function(index) return effectNames[Motion.LEVELS[index]] end,
        onChange = function(index) Motion.SetLevel(Motion.LEVELS[index]) end,
    })
    controls.effects:SetPoint("TOPLEFT", CONTROL_X, 0)
    controls.effectsIndex = EffectIndex

    -- Quiets every sound every Blackthornes addon plays (UI/SharedChoices.lua,
    -- a player asked, 2026-11-12). Off unless ticked; ticked in one is ticked in all.
    local muteRow = pages:Row("all", 1, L["Mute All Sounds:"], nil)
    controls.muteSounds = Widgets.CreateCheckbox(muteRow, L["On"], function(checked)
        SettingsUI:SetMuteSounds(checked)
    end, false)
    controls.muteSounds:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- One minimap button for every Blackthornes addon (UI/SharedMinimap.lua,
    -- the owner, 2026-10-28): ticked unless unticked, the same in all five.
    local combineRow = pages:Row("all", 1, L["Combine Addon Buttons:"], nil)
    controls.combineButtons = Widgets.CreateCheckbox(combineRow, L["On"], function(checked)
        if ns.SharedMinimap then ns.SharedMinimap.SetCombined(checked) end
    end, true)
    controls.combineButtons:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- One window for every Blackthornes addon (UI/SharedWindow.lua, the
    -- owner, 2026-10-30): on unless unticked, the same in all five. Ticked
    -- or not, Settings opens again where it now belongs.
    local oneRow = pages:Row("all", 1, L["One Window:"], nil)
    controls.oneWindow = Widgets.CreateCheckbox(oneRow, L["On"], function(checked)
        SettingsUI:SetOneWindow(checked)
    end, true)
    controls.oneWindow:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- The minimap button always shows (the owner, 2026-10-15), so it has
    -- no row here.

    local positionRow = pages:Row("all", 1, L["Window Locations:"],
        L["Puts every Blackthornes window back where it started. Your settings and data stay the same."])

    local reset = Widgets.CreateButton(positionRow, L["Set Default"], function()
        SettingsUI:ResetAllWindows()
    end, { width = 110, height = 20 })
    reset:SetPoint("TOPLEFT", CONTROL_X, 0)
    controls.resetPositions = reset

    local restoreRow = pages:Row("all", 1, L["Butler Settings:"],
        L["Puts every Butler setting back to how it started. Your keep and sell lists and your characters stay. So do your window locations and the choices on this page."])
    controls.restoreDefaults = SettingsUI.ConfirmButton(restoreRow, L["Set Default"], function()
        SettingsUI:RestoreDefaults()
    end, reset:GetWidth() or 100)
    controls.restoreDefaults:SetPoint("TOPLEFT", CONTROL_X, 0)

    -- Core/SisterNote.lua: one chat line, once, naming the Blackthornes
    -- addons the player does not have. Off here is off in all of them.
    local sistersRow = pages:Row("all", 1, L["Sister Addons:"],
        L["Says once in chat which Blackthornes addons you don't have."])
    controls.sisters = Widgets.CreateCheckbox(sistersRow, L["On"], function(checked)
        ns.SisterNote:SetOn(checked)
    end, true)
    controls.sisters:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- UI/WhatsNew.lua: one window after an update for every Blackthornes
    -- addon. Off here is off in all of them, as the sister note is. One
    -- drop-down for its two choices, the same in every addon
    -- (UI/SettingsPages.lua).
    pages:Section("all", 2, L["WHAT'S NEW"])
    local _, whatsNewButton = CommandRow(pages, "all", 2, L["What's New:"], nil,
        L["Open"], "whatsnew")
    controls.whatsnew = whatsNewButton

    local afterRow = pages:Row("all", 2, L["After Updates:"],
        L["Opens What's New the first time you play after an update."])
    controls.whatsNewAfter = ns.SettingsPages.AfterUpdatesControl(afterRow, CONTROL_X,
        function() return ns.WhatsNew end)

    pages:Section("general", 1, L["BUTLER"])

    -- The size the window's grip saves, for Your Bags, All Characters and
    -- Settings alike.
    local sizeRow = pages:Row("general", 1, L["Window Size:"], nil)
    controls.windowScale = ns.SettingsPages.WindowSizeControl(sizeRow, CONTROL_X,
        function() return math.floor(((ns.db and ns.db.windowScale) or 1) * 100 + 0.5) end,
        function(percent)
            ns.UI:SetWindowScale(percent / 100)
            if ns.ButlerTabs and SettingsUI.frame then ns.ButlerTabs.ApplyScale(SettingsUI.frame) end
        end)


    local windowRow = pages:Row("general", 1, L["Butler:"], nil)
    controls.openWindow = Widgets.CreateButton(windowRow, L["Open"], function()
        ns.HandleSlash("window")
    end, { width = 100, height = 20, primary = true })
    controls.openWindow:SetPoint("TOPLEFT", CONTROL_X, 0)

    local _, allButton = CommandRow(pages, "general", 1, L["All Characters:"],
        L["Every character's items in one list. Needs Blackthornes Tradeskills."],
        L["Open"], "all")
    controls.all = allButton

    local voiceRow = pages:Row("general", 1, L["Butler's Voice:"], nil)
    controls.voice = Widgets.CreateCheckbox(voiceRow, L["On"], function(checked)
        ns.db.voice = checked
    end, true)
    controls.voice:SetPoint("TOPLEFT", CONTROL_X, -2)

    -- Three bag helpers on one row (2026-11-16, from a mockup): a tick
    -- each, their words on the hover and in the row's description. The
    -- saved keys are as they were.
    local helpWords = {
        L["Shows free slots on your backpack button."],
        L["When your bags are full, a gold can marks the cheapest item Butler would sell. Click it to pick it up."],
        L["When your bags are full and you loot a quest item or something worth more, Butler offers to throw out your cheapest junk to make room. Nothing goes until you click Swap."],
        L["Shows Butler's marks on your bags: sell, mail, upgrade, quest and needed items."],
    }
    local helpRow = pages:Row("general", 1, L["Bag Helpers:"], table.concat(helpWords, " "))
    controls.freeSpace = Widgets.CreateCheckbox(helpRow, L["Free Space"], function(checked)
        if ns.FreeSpace then ns.FreeSpace:SetEnabled(checked) end
    end, true)
    controls.trashCan = Widgets.CreateCheckbox(helpRow, L["Trash Can"], function(checked)
        if ns.Trash then ns.Trash:SetEnabled(checked) end
    end, true)
    controls.swapWhenFull = Widgets.CreateCheckbox(helpRow, L["Swap When Full"], function(checked)
        if ns.SwapWhenFull then ns.SwapWhenFull:SetEnabled(checked) end
    end, false)
    SettingsUI.Hover(controls.freeSpace, helpWords[1])
    SettingsUI.Hover(controls.trashCan, helpWords[2])
    controls.bagMarks = Widgets.CreateCheckbox(helpRow, L["Marks on Bags"], function(checked)
        if ns.BagMarks then ns.BagMarks:SetOn(checked) end
    end, false)
    SettingsUI.Hover(controls.swapWhenFull, helpWords[3])
    SettingsUI.Hover(controls.bagMarks, helpWords[4])
    SettingsUI.Flow(helpRow, { controls.freeSpace, controls.trashCan, controls.swapWhenFull, controls.bagMarks })

    -- Debug and the client check are typed only (/bbutler debug, probe;
    -- the owner, 2026-10-23): players don't need them.

    pages:Section("tooltips", 1, L["TOOLTIPS"])

    -- One Off, Shift or Always box for every tooltip line, and a tick for
    -- each line (2026-11-16, from a mockup). Each line keeps its own saved
    -- setting and Shift choice, so nothing changes until the player uses
    -- the box: lines that differ show as the most shown of them.
    local tipWords = {
        whoHas = L["Tooltips list which characters have the item. Needs Blackthornes Tradeskills."],
        verdictTip = L["The last tooltip line says what Butler would do with it."],
    }
    local linesRow = pages:Row("tooltips", 1, L["Show Tooltip Lines:"],
        tipWords.whoHas .. " " .. tipWords.verdictTip)
    local lines = {
        { key = "whoHas", text = L["Who Has It"],
            isOn = function() return ns.db.whoHas ~= false end,
            setOn = function(on) if ns.WhoHas then ns.WhoHas:SetEnabled(on) end end },
        { key = "verdictTip", text = L["Butler"],
            isOn = function() return ns.db.verdictTip ~= false end,
            setOn = function(on) if ns.VerdictTip then ns.VerdictTip:SetEnabled(on) end end },
        { key = "vendorPrice", text = L["Vendor Price"],
            isOn = function() return ns.db.vendorPrice ~= false end,
            setOn = function(on) if ns.VendorPrices then ns.VendorPrices:SetEnabled(on) end end },
    }
    controls.tooltipLines = SettingsUI.TooltipLinesControl(linesRow, lines)
    for _, line in ipairs(lines) do
        controls[line.key] = line.box
        if tipWords[line.key] then SettingsUI.Hover(line.box, tipWords[line.key]) end
    end
    -- Craft Details (2026-11-14): off unless ticked; the tooltip names the craft.
    controls.craftDetails = Widgets.CreateCheckbox(linesRow, L["Craft Details"], function(checked)
        if ns.VerdictTip then ns.VerdictTip:SetDetails(checked) end
    end, false)
    SettingsUI.Flow(linesRow, { lines[1].box, lines[2].box, lines[3].box, controls.craftDetails })

    -- Butler's own bag window (UI/BagWindow.lua), off unless ticked.
    if ns.BagWindow then ns.BagWindow:AddSettings(pages, controls, CONTROL_X) end

    -- The chat-only commands (help, jobs, lists, upgrademail, gold,
    -- training, goals and bankalt on its own) have no button here: they
    -- are typed only (the owner, 2026-10-15).
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
    if ns.BagWindow then ns.BagWindow:SyncSettings(controls) end
    controls.openAtVendor:SetChecked(ns.db.openAtVendor ~= false)
    controls.openAtMailbox:SetChecked(ns.db.openAtMailbox ~= false)
    controls.fillNext:SetChecked(ns.db.fillNext ~= false)
    controls.namePicker:SetChecked(ns.MailPicker:Enabled())
    controls.altUpgrades:SetChecked(ns.Verdicts:AltUpgradesOn())
    controls.keepLevelUp:SetChecked(ns.Verdicts:KeepLevelUpOn())
    controls.disenchantGreens:SetChecked(ns.Verdicts:DisenchantGreensOn())
    controls.craftPays:SetChecked(ns.Verdicts:CraftPaysOn())
    controls.alwaysDisenchant:SetChecked(ns.Verdicts:AlwaysDisenchantOn())
    controls.jobsAtLogin:SetChecked(ns.db.jobsAtLogin ~= false)
    controls.questItems:SetChecked(ns.Quests:IsOn())
    controls.questBuy:SetChecked(ns.db.questBuy == true)
    controls.mailRunsOut:SetChecked(ns.db.mailRunsOut == true)
    controls.openAtBank:SetChecked(ns.db.openAtBank ~= false)
    controls.placeBar:SetChecked(ns.db.placeBar == true)
    if controls.mailContents then controls.mailContents:SetChecked(ns.MailContents:Enabled()) end
    controls.freeSpace:SetChecked(ns.db.freeSpace ~= false)
    controls.trashCan:SetChecked(ns.db.trashCan ~= false)
    controls.swapWhenFull:SetChecked(ns.db.swapWhenFull == true)
    controls.bagMarks:SetChecked(ns.db.bagMarks == true)
    controls.buyMany:SetChecked(ns.BuyMany:IsOn())
    controls.tooltipLines:Sync()
    controls.craftDetails:SetChecked(ns.VerdictTip ~= nil and ns.VerdictTip:DetailsOn())
    controls.voice:SetChecked(ns.db.voice ~= false)
    controls.learn:SetChecked(ns.db.learn ~= false)
    controls.classTraining:SetChecked(ns.ClassTraining:IsOn())
    controls.arrowRoute:SetChecked(ns.db.arrowRoute ~= false)
    controls.arrowSize:SetValue(ns.WayArrowUI and ns.WayArrowUI.Size() or 100, true)
    controls.useTomTom:SetChecked(ns.db.useTomTom ~= false)
    controls.goldGoals:SetChecked(ns.GoldGoals:IsOn())
    controls.skillUp:SetChecked(ns.SkillUp:IsOn())
    controls.sisters:SetChecked(ns.SisterNote:IsOn())
    controls.whatsNewAfter:Sync()
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
    self:SyncKeepHere()
    self:SyncKeepAcross()
    self:SyncBankAlt()
    self:SyncMailRules()
    self:SyncLists()
    controls.textSize:Sync()
    controls.windowStyle:Sync()
    controls.effects:SetValue(controls.effectsIndex(), true)
    controls.muteSounds:SetChecked(ns.Muted ~= nil and ns.Muted() == true)
    controls.windowScale:Sync()
    controls.combineButtons:SetChecked(not ns.SharedMinimap or ns.SharedMinimap.Combined())
    local One = ns.ButlerTabs and ns.ButlerTabs.One()
    controls.oneWindow:SetChecked(One ~= nil and One.On() == true)
    if ns.RuleOrderUI then ns.RuleOrderUI:Refresh() end
    -- In the one window, All Addons is behind its gear, not on the switch.
    self.pages:SetHidden("all", One ~= nil and One.On() == true)
    self.pages:Refresh()
end

--- Open Settings on the All Addons page (the one window's gear).
function SettingsUI:ShowAllAddons()
    self:Show()
    if self.pages then self.pages:Show("all") end
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
    if ns.ButlerTabs and ns.ButlerTabs:Route("settings") then return end
    self:Build()

    if not self.frame:IsShown() then
        -- In the Butler window's place when it is up, else where the tabs
        -- last stood (UI/ButlerTabs.lua).
        local how = ns.ButlerTabs and ns.ButlerTabs:Take(self)
        if not how then self:RestorePosition() end
        self.frame:Show()
        if not how and ns.ButlerTabs then ns.ButlerTabs:Settle(self.frame) end
        if how ~= "switch" then ns.Motion:Open(self.frame) end
        if ns.Errands then ns.Errands:TellTradeskills() end
    end

    self:Refresh()
end

--- Tick or untick "One Window:" in every loaded addon, and open Settings
--- again in the one window, or in its own.
function SettingsUI:SetOneWindow(on)
    local One = ns.ButlerTabs and ns.ButlerTabs.One()
    if not One then return end
    local inside = ns.ButlerTabs:Hosted()
    One.SetOn(on)
    if on and not inside and self.frame and self.frame:IsShown() then
        ns.ButlerTabs.switching = true
        self.frame:Hide()
        ns.ButlerTabs.switching = false
        self:Show()
    elseif not on and inside then
        self:Show()
    end
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
    self:SayRestored()
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
-- Mute All Sounds: kept in this addon's own save as muteSounds and
-- muteSoundsAt (never rename them) and told to every sister.
function SettingsUI:SetMuteSounds(on)
    on = on and true or false
    local at = ns.SharedChoices and ns.SharedChoices:SetMute(on) or nil
    if ns.db then
        ns.db.muteSounds = on
        ns.db.muteSoundsAt = at
    end
    if self.Refresh and self.frame and self.frame:IsShown() then pcall(self.Refresh, self) end
end

ns.RegisterCommand("mute", L["turn every Blackthornes sound off or back on (on/off)"], function(arg)
    arg = ((arg or ""):match("^%s*(.-)%s*$") or ""):lower()
    local on
    if arg == "on" then on = true
    elseif arg == "off" then on = false
    else on = not (ns.Muted and ns.Muted()) end
    SettingsUI:SetMuteSounds(on)
    ns.Print(on and L["All Blackthornes sounds are off. /bbutler mute off turns them back on."]
        or L["Blackthornes sounds are back on."])
end)

ns.commands.options = ns.commands.settings
ns.commands.config = ns.commands.settings

--------------------------------------------------------------------------------
-- Choices every Blackthornes addon shares (UI/SharedChoices.lua): a change
-- made in a sister is written here the way this addon writes it itself.
--------------------------------------------------------------------------------

if ns.SharedChoices then
    ns.SharedChoices:Join("Butler", function(choice, value)
        if not ns.db then return end
        if choice == "textSize" then
            if ns.Theme.TEXT_STEPS and ns.Theme.TEXT_STEPS[value] then ns.db.textSize = value end
        elseif choice == "windowStyle" then
            if value == "titanforged" or value == "blizzard" then ns.db.windowStyle = value end
        elseif choice == "effects" then
            if value == "full" or value == "subtle" or value == "off" then ns.Motion.SetLevel(value) end
        elseif choice == "useTomTom" then
            if ns.TomTom then ns.TomTom:SetOn(value and true or false) end
        elseif choice == "arrowRoute" then
            if ns.Travel then ns.Travel:SetOn(value and true or false) end
        elseif choice == "arrowSize" then
            if ns.WayArrowUI then ns.WayArrowUI:SetSize(value) end
        elseif choice == "muteSounds" then
            ns.db.muteSounds = value and true or false
            ns.db.muteSoundsAt = ns.SharedChoices.board.mute.at
        end
        if ns.SettingsUI and ns.SettingsUI.Refresh and ns.SettingsUI.frame and ns.SettingsUI.frame:IsShown() then pcall(ns.SettingsUI.Refresh, ns.SettingsUI) end
    end, function()
        if not ns.db then return nil end
        return ns.db.muteSounds == true, ns.db.muteSoundsAt
    end)
end

ns.RegisterCommand("windows", L["put every Blackthornes window back where it started (reset)"], function(arg)
    arg = ((arg or ""):match("^%s*(.-)%s*$") or ""):lower()
    if arg == "reset" then
        SettingsUI:ResetAllWindows()
    else
        ns.Print(L["Type /bbutler windows reset to put every window back in its first spot."])
    end
end)

-- Kept folded through a /reload, its round button opens it (UI/FoldWindow.lua).
if ns.FoldWindow and ns.FoldWindow.Opener then
    ns.FoldWindow:Opener("Settings", { open = function() SettingsUI:Show() end })
end
