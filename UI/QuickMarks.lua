-- Blackthornes Butler -- UI/QuickMarks.lua
-- Quick marks (the owner said build it, 2026-11-26, from the improvement
-- review's mockup #4): tell Butler what to do with an item in one click or
-- one key press.
--
--   * The Quick Marks Bar key (below) brings up a small bar of marks above
--     the bag square under the mouse. One click sets the mark through
--     Verdicts:SetChoice; a click on the mark it has already takes it off.
--     Only the marks that fit the item show: nothing bound gets Mail or
--     Auction, only green or better gets Disenchant, and nothing a vendor
--     won't buy gets Sell.
--   * Keep For Now holds an item until logout (Verdicts:KeepForNow; nothing
--     is saved).
--   * Keys on the game's Key Bindings page, under Blackthornes Butler
--     (Bindings.xml): Mark to Sell, Mark to Keep and Keep For Now act on
--     the item under the mouse. Quick Marks Bar shows the bar. None has a
--     key until the player gives it one, so no key of theirs is taken.
--     Holding Alt over an item once showed the bar too; the owner asked
--     to take that out (2026-11-27). Don't add it back.
--   * Works on the game's bags and on Butler Bags. Never in a fight. No
--     drag and drop (the owner's earlier no). Alt right-click's menu stays.
--
-- The square under the mouse is learned from the game's own bag tooltip
-- (GameTooltip:SetBagItem, hooked, nothing changed) and from Butler Bags'
-- squares as the mouse enters them.

local _, ns = ...
local L = ns.L

local QuickMarks = ns.NewModule("QuickMarks")

QuickMarks.SLOT = 26
QuickMarks.ICON = 18
QuickMarks.PAD = 4
QuickMarks.CHECK = 0.1

QuickMarks.BAR_BINDING = "BLACKTHORNESBUTLER_QUICKBAR"

-- The marks, in the bar's order: id, the mark it wears (UI/Marks.lua), its
-- name. Keep For Now has a line under its name.
QuickMarks.MARKS = {
    { id = "keep", kind = "keep", label = L["Always Keep"] },
    { id = "now", kind = "waiting", label = L["Keep For Now"], note = L["Kept until you log out."] },
    { id = "sell", kind = "sell", label = L["Always Sell"] },
    { id = "auction", kind = "list", label = L["Always Auction"] },
    { id = "bank", kind = "bank", label = L["Always Bank"] },
    { id = "disenchant", kind = "disenchant", label = L["Always Disenchant"] },
    { id = "mail", kind = "mail", label = L["Always Mail To..."] },
}

local BY_ID = {}
for _, mark in ipairs(QuickMarks.MARKS) do BY_ID[mark.id] = mark end

_G.BINDING_HEADER_BLACKTHORNESBUTLER = L["Blackthornes Butler"]
_G.BINDING_NAME_BLACKTHORNESBUTLER_MARKSELL = L["Mark to Sell"]
_G.BINDING_NAME_BLACKTHORNESBUTLER_MARKKEEP = L["Mark to Keep"]
_G.BINDING_NAME_BLACKTHORNESBUTLER_KEEPNOW = L["Keep For Now"]
_G.BINDING_NAME_BLACKTHORNESBUTLER_QUICKBAR = L["Quick Marks Bar"]

local function InFight()
    local fn = rawget(_G, "InCombatLockdown")
    return type(fn) == "function" and fn() and true or false
end

local function MouseOver(frame)
    if type(frame) ~= "table" or type(frame.IsMouseOver) ~= "function" then return false end
    local ok, over = pcall(frame.IsMouseOver, frame)
    if not ok or not over then return false end
    if type(frame.IsVisible) == "function" then
        local seen, visible = pcall(frame.IsVisible, frame)
        if seen and visible == false then return false end
    end
    return true
end

--------------------------------------------------------------------------------
-- The square under the mouse
--------------------------------------------------------------------------------

--- The mouse is over this bag square (`owner` the button).
function QuickMarks:Hover(owner, bag, slot)
    bag, slot = tonumber(bag), tonumber(slot)
    if not owner or not bag or not slot then return end
    self.hover = { owner = owner, bag = bag, slot = slot }
end

--- The bag item under the mouse now: its slot as the client has it, and
--- its square. Nil when the mouse left it or the square is empty.
function QuickMarks:Hovered()
    local hover = self.hover
    if not hover then return nil end
    if not MouseOver(hover.owner) and not (self.bar and self.bar:IsShown() and MouseOver(self.bar)) then
        return nil
    end
    local entry = ns.Bags and ns.Bags.ReadSlot(hover.bag, hover.slot)
    if not entry or not entry.itemID then return nil end
    return entry, hover.owner
end

--------------------------------------------------------------------------------
-- What fits
--------------------------------------------------------------------------------

--- The marks that fit this item, in the bar's order. A mark it has now
--- always shows, so it can be taken off.
function QuickMarks.Fits(entry)
    local list = {}
    if type(entry) ~= "table" or not entry.itemID then return list end
    local choice = ns.Verdicts:Choice(entry.itemID)
    for _, mark in ipairs(QuickMarks.MARKS) do
        local id, fits = mark.id, true
        if id == "sell" then
            fits = not entry.noValue
        elseif id == "auction" or id == "mail" then
            fits = not entry.bound
        elseif id == "disenchant" then
            fits = (entry.quality or 0) >= 2
        end
        if fits or choice == id then list[#list + 1] = mark end
    end
    return list
end

--- True when this item wears this mark now.
function QuickMarks.Has(entry, id)
    if type(entry) ~= "table" or not entry.itemID then return false end
    if id == "now" then return ns.Verdicts:KeptForNow(entry.itemID) end
    return (ns.Verdicts:Choice(entry.itemID)) == id
end

local function Fits(entry, id)
    for _, mark in ipairs(QuickMarks.Fits(entry)) do
        if mark.id == id then return true end
    end
    return false
end

--- Set a mark on the item (`id` from QuickMarks.MARKS). `toggle` takes it
--- off when the item has it already (a click on the bar); a key only ever
--- sets it. Returns true when something changed. Never in a fight.
function QuickMarks:Pick(entry, id, toggle)
    if InFight() or type(entry) ~= "table" or not entry.itemID then return false end
    if not BY_ID[id] or not Fits(entry, id) then return false end
    local Verdicts = ns.Verdicts
    local has = QuickMarks.Has(entry, id)
    if has and not toggle then return false end
    if id == "now" then
        Verdicts:KeepForNow(entry.itemID, not has)
        return true
    end
    if has then
        Verdicts:SetChoice(entry.itemID, nil)
        return true
    end
    if id == "mail" then
        -- Mail needs a character: the menu's own page asks who.
        if ns.UI and ns.UI.ShowMailMenuFor then
            local name = ns.Items and ns.Items.NameFromLink and ns.Items.NameFromLink(entry.link)
            ns.UI:ShowMailMenuFor({ itemID = entry.itemID, name = name or tostring(entry.itemID) })
        end
        return false
    end
    Verdicts:SetChoice(entry.itemID, id)
    return true
end

--------------------------------------------------------------------------------
-- The keys
--------------------------------------------------------------------------------

--- Mark to Sell, Mark to Keep and Keep For Now: the item under the mouse.
--- A short line in chat says what was set.
function QuickMarks:Key(id)
    if InFight() then return false end
    local entry = self:Hovered()
    if not entry then return false end
    if not self:Pick(entry, id, false) then return false end
    local mark = BY_ID[id]
    ns.Print(("%s: %s"):format(entry.link or tostring(entry.itemID), mark.label))
    self:Paint()
    return true
end

--- The Quick Marks Bar key, held down (`keystate` "down") over an item.
function QuickMarks:BarKey(keystate)
    if keystate == "up" then return end
    self:ShowBar()
end

--------------------------------------------------------------------------------
-- The bar
--------------------------------------------------------------------------------

local function Color(key, alpha)
    local theme = ns.Theme
    if theme and theme.Unpack then
        local ok, r, g, b, a = pcall(theme.Unpack, key, alpha)
        if ok and r then return r, g, b, a or alpha or 1 end
    end
    return 0.8, 0.65, 0.3, alpha or 1
end

local function PaintSlot(slot, hover)
    local active = slot.active
    local key = active and "glassActive" or (hover and "glassHover") or (slot.index % 2 == 1 and "glass" or "glassAlt")
    slot.fill:SetColorTexture(Color(key))
    slot.edge:SetShown((hover or active) and true or false)
end

local function MakeSlot(bar, index)
    local size = QuickMarks.SLOT
    local slot = CreateFrame("Button", nil, bar)
    slot:SetSize(size, size)
    slot.index = index
    slot.mark = false
    slot.fill = slot:CreateTexture(nil, "BACKGROUND")
    slot.fill:SetAllPoints()
    -- A gold line round the slot under the mouse or for the mark it has.
    slot.edge = CreateFrame("Frame", nil, slot)
    slot.edge:SetAllPoints()
    if ns.Theme and ns.Theme.Border then ns.Theme.Border(slot.edge, "accentHi") end
    slot.edge:Hide()
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("CENTER")
    if ns.Marks then ns.Marks.Attach(slot.icon) end
    if slot.icon.SetSize then slot.icon:SetSize(QuickMarks.ICON, QuickMarks.ICON) end
    slot:SetScript("OnEnter", function(self)
        PaintSlot(self, true)
        local mark = self.mark
        if not mark or not GameTooltip then return end
        GameTooltip:SetOwner(QuickMarks.bar, "ANCHOR_TOP")
        GameTooltip:SetText(mark.label, Color("accentHi"))
        if mark.note then GameTooltip:AddLine(mark.note, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function(self)
        PaintSlot(self, false)
        if GameTooltip then GameTooltip:Hide() end
    end)
    slot:SetScript("OnClick", function(self)
        QuickMarks:Click(self.mark and self.mark.id)
    end)
    return slot
end

function QuickMarks:BuildBar()
    if self.bar then return self.bar end
    local bar = CreateFrame("Frame", "BlackthornesButlerQuickMarks", UIParent)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:SetFrameLevel(60)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(true)
    -- A thin gold rim round dark glass, the house menu.
    if ns.Theme then
        ns.Theme.Fill(bar, "well")
        ns.Theme.Border(bar, "accent")
    end
    bar.slots = {}
    bar.entry, bar.owner = false, false
    bar.wait = 0
    bar:SetScript("OnUpdate", function(self, elapsed)
        self.wait = self.wait + (elapsed or 0)
        if self.wait < QuickMarks.CHECK then return end
        self.wait = 0
        QuickMarks:Check()
    end)
    bar:Hide()
    self.bar = bar
    return bar
end

--- Show the bar over the item under the mouse. Never in a fight.
function QuickMarks:ShowBar()
    if InFight() then return false end
    local entry, owner = self:Hovered()
    if not entry then return false end
    local marks = QuickMarks.Fits(entry)
    if #marks == 0 then return false end
    local bar = self:BuildBar()
    local size, pad = QuickMarks.SLOT, QuickMarks.PAD
    for i, mark in ipairs(marks) do
        local slot = bar.slots[i] or MakeSlot(bar, i)
        bar.slots[i] = slot
        slot.mark = mark
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", bar, "TOPLEFT", pad + (i - 1) * (size + 2), -pad)
        if ns.Marks then ns.Marks.Set(slot.icon, mark.kind) end
        slot:Show()
    end
    for i = #marks + 1, #bar.slots do
        bar.slots[i].mark = false
        bar.slots[i]:Hide()
    end
    bar:SetSize(pad * 2 + #marks * size + (#marks - 1) * 2, pad * 2 + size)
    bar.entry = entry
    bar.owner = owner
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", owner, "TOP", 0, 2)
    bar.wait = 0
    bar:Show()
    self:Paint()
    return true
end

--- Light the mark the item has now.
function QuickMarks:Paint()
    local bar = self.bar
    if not bar or not bar:IsShown() or not bar.entry then return end
    for _, slot in ipairs(bar.slots) do
        if slot.mark then
            slot.active = QuickMarks.Has(bar.entry, slot.mark.id)
            PaintSlot(slot, MouseOver(slot))
        end
    end
end

function QuickMarks:HideBar()
    local bar = self.bar
    if not bar then return end
    bar.entry, bar.owner = false, false
    if bar:IsShown() then bar:Hide() end
end

--- A click on the bar: set the mark, or take it off.
function QuickMarks:Click(id)
    local bar = self.bar
    if not bar or not bar.entry or not id then return false end
    -- The square may have changed under the bar: read it again.
    local entry = ns.Bags and ns.Bags.ReadSlot(bar.entry.bag, bar.entry.slot)
    if not entry or entry.itemID ~= bar.entry.itemID then
        self:HideBar()
        return false
    end
    local done = self:Pick(entry, id, true)
    if id == "mail" and not QuickMarks.Has(entry, "mail") then
        self:HideBar()
        return done
    end
    bar.entry = entry
    self:Paint()
    return done
end

--- The bar goes once the mouse is off both the square and the bar, or a
--- fight starts.
function QuickMarks:Check()
    local bar = self.bar
    if not bar or not bar:IsShown() then return end
    if InFight() or not (MouseOver(bar.owner) or MouseOver(bar)) then
        self:HideBar()
    end
end

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

function QuickMarks:InstallHooks()
    if self.hooked then return end
    self.hooked = true
    local hook = rawget(_G, "hooksecurefunc")
    local tip = rawget(_G, "GameTooltip")
    if type(hook) == "function" and type(tip) == "table" and type(tip.SetBagItem) == "function" then
        pcall(hook, tip, "SetBagItem", function(self, bag, slot)
            local ok, owner = pcall(self.GetOwner, self)
            if ok and owner then QuickMarks:Hover(owner, bag, slot) end
        end)
    end
end

function QuickMarks:OnEnable()
    self:InstallHooks()
    ns.RegisterEvent(self, "PLAYER_REGEN_DISABLED", function() QuickMarks:HideBar() end)
end
