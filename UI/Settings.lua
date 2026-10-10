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
    { key = "selling", text = "SELLING",
      tip = "Selling at a vendor, and your Always keep and Always sell lists" },
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

    pages:Section("selling", 2, "YOUR LISTS")

    local _, listsButton = CommandRow(pages, "selling", 2, "Keep and sell",
        "Right-click an item in the Butler window to always keep it or always sell it. This lists both in chat. To empty them, type /bbutler reset confirm. Same as /bbutler lists.",
        "List them", "lists")
    controls.lists = listsButton

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
    controls.debug:SetChecked(ns.db.debug == true)
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
