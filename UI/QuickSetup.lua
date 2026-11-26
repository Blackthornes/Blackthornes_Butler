-- Blackthornes Butler -- UI/QuickSetup.lua
-- Set Up Butler: three choices on first open (the owner said build it,
-- 2026-11-26, from a mockup).
--
-- A card shown once, the first time Butler's window opens on an account
-- where none of these is set yet:
--
--   1. Bank Alt          `bankAlt` (Logic/BankAlt.lua)
--   2. Disenchanter      Tradeskills' Mail page box, through its
--                        Butler:Disenchanter() and SetDisenchanter(name)
--   3. Where Butler      `openAtVendor`, `openAtMailbox`, `openAtBank` and
--      Shows Up          `placeBar` (the Butler bar)
--
-- It writes only those existing settings, and only on Confirm. Later or
-- the close gem shuts it for good. `quickSetupShown` (account wide, never
-- rename it) is set the moment it shows, so it never comes back, not even
-- after a reload. A player who set any of the choices before never sees
-- it. The name lists hold only the player's characters on this realm and
-- side (`Errands:Characters`), never the one playing, and every name is
-- asked `Errands:IsMe` again right before it is written.

local _, ns = ...
local L = ns.L

local QuickSetup = ns.NewModule("QuickSetup")

local Theme = ns.Theme
local Widgets = ns.Widgets

QuickSetup.WIDTH = 700
local PAD = 18
local GAP = 10
local TOP = 34          -- under the title plate
local INTRO = 26
local LINE = 22         -- one line of ticks
local CONTROL_Y = -64   -- where a column's drop-down or ticks start

local function Field(object, key)
    if type(object) ~= "table" then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
    return nil
end

local function Text(value)
    if type(value) ~= "string" then return nil end
    value = value:match("^%s*(.-)%s*$")
    return value ~= "" and value or nil
end

local function InCombat()
    local fn = rawget(_G, "InCombatLockdown")
    if type(fn) ~= "function" then return false end
    local ok, fighting = pcall(fn)
    return ok and fighting and true or false
end

--------------------------------------------------------------------------------
-- What is set already
--------------------------------------------------------------------------------

--- Tradeskills' Butler table when it can read and type the disenchanter.
function QuickSetup.Tradeskills()
    local ts = ns.Sisters and ns.Sisters.Butler("ts")
    if not ts then return nil end
    if type(Field(ts, "Disenchanter")) ~= "function" or type(Field(ts, "SetDisenchanter")) ~= "function" then
        return nil
    end
    return ts
end

--- The disenchanter typed on Tradeskills' Mail page, or nil.
function QuickSetup.Disenchanter()
    local ts = QuickSetup.Tradeskills()
    if not ts then return nil end
    local ok, name = pcall(ts.Disenchanter, ts)
    return ok and Text(name) or nil
end

--- Has the player set any of the three choices already? Then the card
--- never shows. Open Butler At is set once any place is unticked (all
--- three are on until then), the Butler bar once it is ticked.
function QuickSetup:AnySet()
    local db = ns.db
    if type(db) ~= "table" then return true end
    if Text(db.bankAlt) then return true end
    if type(db.bankAltKindTo) == "table" and next(db.bankAltKindTo) ~= nil then return true end
    if db.openAtVendor == false or db.openAtMailbox == false or db.openAtBank == false then return true end
    if db.placeBar == true then return true end
    if QuickSetup.Disenchanter() then return true end
    return false
end

--- Should the card come up now? Once only, and never over a fight.
function QuickSetup:Wanted()
    local db = ns.db
    if type(db) ~= "table" or db.quickSetupShown then return false end
    if InCombat() then return false end
    return not self:AnySet()
end

--- Asked each time Butler's window opens (UI:Show).
function QuickSetup:Offer()
    if self:Wanted() then self:Show() end
end

--------------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------------

--- A column: a gold heading, a muted line under it, the control below.
local function Column(parent, index, heading, line)
    local width = (QuickSetup.WIDTH - PAD * 2 - GAP * 2) / 3
    local column = Theme.CreatePanel(parent, "glass", "border")
    column:SetWidth(width)
    column:SetPoint("TOPLEFT", PAD + (index - 1) * (width + GAP), -(TOP + INTRO))

    column.heading = Theme.CreateLabel(column, "normal", "heading")
    column.heading:SetPoint("TOPLEFT", 10, -10)
    column.heading:SetPoint("RIGHT", column, "RIGHT", -10, 0)
    column.heading:SetWordWrap(true)
    column.heading:SetText(heading)

    column.line = Theme.CreateLabel(column, "small", "muted")
    column.line:SetPoint("TOPLEFT", 10, -30)
    column.line:SetPoint("RIGHT", column, "RIGHT", -10, 0)
    column.line:SetHeight(30)
    column.line:SetWordWrap(true)
    column.line:SetJustifyV("TOP")
    column.line:SetText(line)

    column.inner = width - 20
    return column
end

--- A drop-down of None and the player's characters on this realm and side.
local function NamePicker(column)
    local picker = Widgets.CreateDropdown(column, {}, nil, { width = 150 })
    picker:SetPoint("TOPLEFT", 10, CONTROL_Y)
    function picker:Fill(names)
        local options = { { text = L["None"], value = "" } }
        for _, name in ipairs(names or {}) do options[#options + 1] = { text = name, value = name } end
        self.options = options
        -- As wide as the longest name, so none is cut short.
        self:SetWidth(Widgets.DropdownWidth(options, 150))
        self:SetValue("")
    end
    return picker
end

--- Lay `ticks` out left to right, a new line when one would not fit.
--- Returns how many lines they took.
local function Flow(column, ticks)
    local x, line = 0, 1
    for _, tick in ipairs(ticks) do
        local width = tonumber(tick:GetWidth()) or 80
        if x > 0 and x + width > column.inner then x, line = 0, line + 1 end
        tick:ClearAllPoints()
        tick:SetPoint("TOPLEFT", 10 + x, CONTROL_Y - (line - 1) * LINE)
        x = x + width + 12
    end
    return line
end

function QuickSetup:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "BlackthornesButlerQuickSetup", UIParent)
    frame:SetWidth(QuickSetup.WIDTH)
    -- Over Butler's window (DIALOG); its drop-down menus sit higher still.
    frame:SetFrameStrata("FULLSCREEN")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    Theme.Fill(frame, "window")
    if ns.Titanforged then
        self.trim = ns.Titanforged:Dress(frame, {
            title = L["Set Up Butler"],
            portrait = true,
            close = function() QuickSetup:Later() end,
        })
    else
        Theme.Border(frame, "borderLit")
    end
    -- Escape closes it as the game's own windows close.
    local special = rawget(_G, "UISpecialFrames")
    if type(special) == "table" then special[#special + 1] = "BlackthornesButlerQuickSetup" end

    local intro = Theme.CreateLabel(frame, "normal", "text")
    intro:SetPoint("TOPLEFT", PAD, -TOP)
    intro:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    intro:SetJustifyH("CENTER")
    intro:SetWordWrap(true)
    intro:SetText(L["Three quick choices and Butler is ready. Change them any time in Settings."])

    local bank = Column(frame, 1, L["1. BANK ALT"],
        L["The character who stores your spare cloth, herbs and ore."])
    self.bankAlt = NamePicker(bank)

    local enchanter = Column(frame, 2, L["2. DISENCHANTER"],
        L["The character who breaks greens into dust."])
    self.disenchanter = NamePicker(enchanter)
    self.enchanterColumn = enchanter
    self.enchanterLine = L["The character who breaks greens into dust."]

    local places = Column(frame, 3, L["3. WHERE BUTLER SHOWS UP"],
        L["Pick the full window or the slim bar."])
    -- The words the Settings row "Open Butler At:" uses.
    self.atVendor = Widgets.CreateCheckbox(places, L["Vendors"], nil, true)
    self.atMailbox = Widgets.CreateCheckbox(places, L["Mailboxes"], nil, true)
    self.atBank = Widgets.CreateCheckbox(places, L["The Bank"], nil, true)
    local lines = Flow(places, { self.atVendor, self.atMailbox, self.atBank })
    self.bar = Widgets.CreateCheckbox(places, L["Slim bar under the game's window"], nil, false)
    self.bar:SetPoint("TOPLEFT", 10, CONTROL_Y - lines * LINE)

    -- Every column as tall as the tallest: the ticks need the most room.
    local columnHeight = -CONTROL_Y + (lines + 1) * LINE + 6
    for _, column in ipairs({ bank, enchanter, places }) do column:SetHeight(columnHeight) end

    -- Two buttons the same width, as wide as the longer label.
    local width = math.max(90, Theme.TextWidth("normal", L["Confirm"]) + 32,
        Theme.TextWidth("normal", L["Later"]) + 32)
    local confirm = Widgets.CreateButton(frame, L["Confirm"], function() QuickSetup:Confirm() end,
        { width = width, height = 24, primary = true })
    confirm:SetPoint("BOTTOMRIGHT", -PAD, PAD - 4)
    self.confirmButton = confirm
    local later = Widgets.CreateButton(frame, L["Later"], function() QuickSetup:Later() end,
        { width = width, height = 24 })
    later:SetPoint("RIGHT", confirm, "LEFT", -8, 0)
    self.laterButton = later

    frame:SetHeight(TOP + INTRO + columnHeight + 24 + PAD + 14)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)

    self.frame = frame
    return frame
end

--- Fill the card from what is saved now, so Confirm with nothing touched
--- writes nothing new.
function QuickSetup:Fill()
    local names = ns.Errands and ns.Errands.Characters and ns.Errands:Characters() or {}
    self.bankAlt:Fill(names)
    self.disenchanter:Fill(names)

    -- Without a Tradeskills that takes the name, the column says so and
    -- has nothing to pick.
    local ts = QuickSetup.Tradeskills()
    self.disenchanter:SetShown(ts ~= nil)
    self.enchanterColumn.line:SetText(ts and self.enchanterLine or L["Blackthornes Tradeskills isn't loaded."])

    local db = ns.db or {}
    self.atVendor:SetChecked(db.openAtVendor ~= false)
    self.atMailbox:SetChecked(db.openAtMailbox ~= false)
    self.atBank:SetChecked(db.openAtBank ~= false)
    self.bar:SetChecked(db.placeBar == true)
end

function QuickSetup:Show()
    if not ns.db then return end
    self:Build()
    self:Fill()
    -- Once only: marked as it shows, so a reload with it up never brings
    -- it back.
    ns.db.quickSetupShown = true
    self.frame:Show()
    self.frame:Raise()
    if ns.Motion and ns.Motion.Open then ns.Motion:Open(self.frame) end
end

function QuickSetup:IsShown()
    return self.frame ~= nil and self.frame:IsShown() == true
end

function QuickSetup:Hide()
    if self.frame then self.frame:Hide() end
end

--- Later: shut for good, nothing written.
function QuickSetup:Later()
    if ns.db then ns.db.quickSetupShown = true end
    self:Hide()
end

--- A picked name, or nil for None or the character playing.
local function Picked(picker)
    local name = Text(picker and picker:GetValue())
    if not name then return nil end
    if ns.Errands and ns.Errands.IsMe and ns.Errands:IsMe(name) then return nil end
    return name
end

--- Confirm: write the choices into the settings they already have, then
--- shut for good.
function QuickSetup:Confirm()
    local db = ns.db
    if not (db and self.frame) then return self:Hide() end
    db.quickSetupShown = true

    local bankAlt = Picked(self.bankAlt)
    if bankAlt and ns.BankAlt then ns.BankAlt:SetName(bankAlt) end

    local disenchanter = self.disenchanter:IsShown() and Picked(self.disenchanter)
    local ts = disenchanter and QuickSetup.Tradeskills()
    if ts then pcall(ts.SetDisenchanter, ts, disenchanter) end

    db.openAtVendor = self.atVendor:GetChecked()
    db.openAtMailbox = self.atMailbox:GetChecked()
    db.openAtBank = self.atBank:GetChecked()
    local bar = self.bar:GetChecked()
    if bar ~= (db.placeBar == true) then
        if ns.PlaceBar then ns.PlaceBar:SetOn(bar) else db.placeBar = bar end
    end

    -- Something to mail may have changed: judge the bags again.
    if (bankAlt or ts) and ns.Verdicts and ns.Verdicts.Changed then ns.Verdicts:Changed(true) end
    if ns.SettingsUI and ns.SettingsUI.Refresh then ns.SettingsUI:Refresh() end
    self:Hide()
end
