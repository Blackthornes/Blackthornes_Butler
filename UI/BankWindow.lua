-- Blackthornes Butler -- UI/BankWindow.lua
-- The Butler Bank window: at a banker, the bank in the Butler Bags style,
-- beside Butler Bags. Butler idea 8 (the owner said build it, 2026-11-26,
-- from the mockup butler-improve-8-live-bank).
--
-- Off unless ticked ("Butler Bank:" under BAGS on the General page,
-- `bankWindow`), and only with Use Butler Bags on too. The squares
-- are the game's own item button template bound to a bank bag and slot, as
-- Butler Bags' are, so a click, a right-click (to the bags), a drag and the
-- tooltip are the game's. /bbutler bankprobe found Forever allows that from
-- an addon's frame: the square is not protected, reads its bag, and a
-- right-click moved a bank item into the bags with nothing blocked
-- (docs/FOREVER_API_FINDINGS.md, "The bank").
--
-- The game's bank window is put out of sight with ns.Veil (see-through and
-- no mouse; never Hide or Show) while this one is up, and put back when this
-- one closes. The close gem shuts the bank, as the game's own close does. Nothing moves
-- without the player's click: Take for Crafts runs Errands:TakeFromBank, the
-- same as the main window's Take from bank.
--
-- Redrawn only when the bank or bags change (coalesced), never on a timer,
-- and not at all while it is hidden.

local _, ns = ...
local L = ns.L

local BankWindow = ns.NewModule("BankWindow")

local Theme = ns.Theme
local Widgets = ns.Widgets

local WIDTH = 480
local HEIGHT = 560
local PADDING = 18
local EDGE_PAD = 11
local CLOSE_RIGHT = 32
local WELL_TOP = 50
local FOOT = 40
local GAP = 4
local HEADING = 24
local SECTION_GAP = 8
local SCROLL_STEP = 48
local TAB_ICON = 24

BankWindow.GROUPS = { "type", "grid" }
BankWindow.SPOT_KEY = "butler.bank"
BankWindow.GAME_FRAMES = { "BankFrame" }

local buttons = {}   -- ["bag:slot"] = square
local holders = {}   -- [bag] = frame carrying the bag's ID
local headings = {}
local tabIcons = {}

local function InCombat()
    local fn = rawget(_G, "InCombatLockdown")
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn)
    return ok and value == true
end

local function NumSlots(bag)
    return tonumber(ns.Items.Call({ "C_Container.GetContainerNumSlots", "GetContainerNumSlots" }, bag)) or 0
end

--- Its own box, "Butler Bank:" under BAGS, off unless ticked (saved
--- account wide as `bankWindow`; never rename it).
function BankWindow:Ticked()
    return ns.db ~= nil and ns.db.bankWindow == true
end

--- Works only with Butler Bags on too.
function BankWindow:On()
    return self:Ticked() and ns.BagWindow ~= nil and ns.BagWindow:On()
end

function BankWindow:SetOn(on)
    if not ns.db then return end
    ns.db.bankWindow = on and true or nil
    if on then
        if ns.Errands and ns.Errands.bankOpen then self:BankOpened() end
    else
        self:Close()
    end
end

function BankWindow:IsShown()
    return self.frame ~= nil and self.frame:IsShown() == true
end

--- Item Type or One Grid, kept for the session (index into GROUPS).
function BankWindow:GroupIndex()
    return self.groupIndex or 1
end

--------------------------------------------------------------------------------
-- Reading the bank
--------------------------------------------------------------------------------

--- Every bank slot in bag order, empty ones too: { bag, slot, entry or nil }.
--- Read only while the bank is open.
function BankWindow.Slots()
    local places = {}
    local errands = ns.Errands
    if not (errands and errands.bankOpen) then return places end
    local bags, listed = {}, {}
    for _, bag in ipairs(errands.BankBagIDs()) do
        bags[#bags + 1] = bag
        listed[bag] = true
    end
    -- A bag bought in a bag slot past the ones Butler lists still counts.
    for _, info in ipairs(BankWindow.BagSlots()) do
        if info.bought and not listed[info.bag] then bags[#bags + 1] = info.bag end
    end
    for _, bag in ipairs(bags) do
        for slot = 1, NumSlots(bag) do
            local entry = ns.Bags.ReadSlot(bag, slot)
            if entry then entry.quest = ns.Bags.ReadQuest(bag, slot, entry.itemID) end
            places[#places + 1] = { bag = bag, slot = slot, entry = entry }
        end
    end
    return places
end

--- The sections drawn: by item type with the empty slots last, or one grid.
function BankWindow:Sections(places)
    if self.GROUPS[self:GroupIndex()] == "grid" then
        return { { key = "grid", places = places } }
    end
    local BagView = ns.BagView
    local byType, filled, empty = {}, {}, {}
    for _, key in ipairs(BagView.TYPE_ORDER) do
        byType[key] = { key = key, label = BagView.TYPE_WORDS[key], places = {} }
    end
    for _, place in ipairs(places) do
        if place.entry then filled[#filled + 1] = place else empty[#empty + 1] = place end
    end
    table.sort(filled, function(a, b)
        local an, bn = BagView.NameOf(a.entry) or "", BagView.NameOf(b.entry) or ""
        if an ~= bn then return an < bn end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    for _, place in ipairs(filled) do
        local list = byType[BagView.TypeOf(place.entry)] or byType.other
        list.places[#list.places + 1] = place
    end
    local sections = {}
    for _, key in ipairs(BagView.TYPE_ORDER) do
        if #byType[key].places > 0 then sections[#sections + 1] = byType[key] end
    end
    if #empty > 0 then
        sections[#sections + 1] = { key = "empty", label = L["EMPTY SLOTS"], places = empty, free = #empty }
    end
    return sections
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

function BankWindow:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "BlackthornesButlerBank", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata(ns.BagWindow and ns.BagWindow.STRATA or "HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    Theme.Fill(frame, "window")

    if ns.Titanforged then
        local trim = ns.Titanforged:Dress(frame, {
            title = L["Bank"],
            portrait = true,
            close = function() BankWindow:Close() end,
        })
        self.trim = trim
        local left, right, top, bottom = ns.Titanforged.Reach(trim)
        if frame.SetClampRectInsets then frame:SetClampRectInsets(-left, right, top, -bottom) end
    else
        Theme.Border(frame, "borderLit")
    end

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function()
        GameTooltip:Hide()
        BankWindow:UncoverGame()
    end)
    self.frame = frame

    local search = Widgets.CreateSearchBox(frame, L["Search the bank"], function()
        BankWindow:Changed(true)
    end)
    search:SetPoint("TOPLEFT", 59, -EDGE_PAD - 6)
    search:SetWidth(math.max(170, Theme.TextWidth("small", L["Search the bank"]) + 40))
    if ns.SearchWords and ns.SearchWords.AttachTip then ns.SearchWords.AttachTip(search) end
    self.search = search

    local words = {}
    for i, key in ipairs(self.GROUPS) do words[i] = ns.BagView.GROUP_WORDS[key] end
    local group = Widgets.CreateChoice(frame, {
        min = 1, max = #self.GROUPS, step = 1, value = self:GroupIndex(),
        format = function(v) return words[v] end,
        onChange = function(v)
            BankWindow.groupIndex = v
            BankWindow:Changed(true)
        end,
    })
    if ns.SettingsPages and ns.SettingsPages.FitStepper then ns.SettingsPages.FitStepper(group, words) end
    group:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CLOSE_RIGHT, -EDGE_PAD - 6)
    self.groupStepper = group
    local groupLabel = Theme.CreateLabel(frame, "small", "muted", "RIGHT")
    groupLabel:SetPoint("RIGHT", group, "LEFT", -6, 0)
    groupLabel:SetText(L["Group By:"])

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", EDGE_PAD, -44)
    rule:SetPoint("TOPRIGHT", -EDGE_PAD, -44)
    rule:SetHeight(1)
    Theme.SetGradientAlpha(rule, "HORIZONTAL", "accent", 0.6, 0.05)

    self:BuildWell()
    self:BuildFoot()
    if ns.SharedWindow and ns.SharedWindow.KeepSpot then ns.SharedWindow.KeepSpot(frame, self.SPOT_KEY) end
    frame:Hide()
    return frame
end

function BankWindow:BuildWell()
    local frame = self.frame
    local well = Theme.CreatePanel(frame, "panel", "border")
    well:SetPoint("TOPLEFT", PADDING, -WELL_TOP - 6)
    well:SetPoint("BOTTOMRIGHT", -PADDING, FOOT)
    if Theme.Recess then Theme.Recess(well) end
    self.well = well

    local scroll = CreateFrame("ScrollFrame", nil, well)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -16, 6)
    self.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 2 * PADDING - 22, 10)
    scroll:SetScrollChild(content)
    self.content = content

    local bar = Widgets.CreateScrollbar and Widgets.CreateScrollbar(well, "metal")
    if bar then
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", well, "TOPRIGHT", -4, -6)
        bar:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -4, 6)
        bar.onValueChanged = function(value) scroll:SetVerticalScroll(value) end
        self.bar = bar
    end
    well:EnableMouseWheel(true)
    well:SetScript("OnMouseWheel", function(_, delta) BankWindow:ScrollBy(-delta * SCROLL_STEP) end)
end

function BankWindow:ScrollBy(pixels)
    local scroll = self.scroll
    if not scroll then return end
    local most = math.max(0, (self.contentHeight or 0) - (tonumber(scroll:GetHeight() or 0) or 0))
    local value = math.max(0, math.min(most, (tonumber(scroll:GetVerticalScroll() or 0) or 0) + pixels))
    scroll:SetVerticalScroll(value)
    if self.bar then self.bar:SetValue(value) end
end

function BankWindow:SizeScroll()
    local scroll, bar = self.scroll, self.bar
    local view = tonumber(scroll:GetHeight() or 0) or 0
    local most = math.max(0, (self.contentHeight or 0) - view)
    if (tonumber(scroll:GetVerticalScroll() or 0) or 0) > most then scroll:SetVerticalScroll(most) end
    if bar then
        bar:SetMinMaxValues(0, most)
        bar:SetValue(tonumber(scroll:GetVerticalScroll() or 0) or 0)
        if bar.SizeThumb then bar:SizeThumb(view, math.max(view, self.contentHeight or 0)) end
        bar:SetShown(most > 0)
    end
end

--- "Bag Slots:" along the foot, as the game's bank shows them: each bank
--- bag slot with the bag in it, then a lock for each slot not bought yet.
--- The free slots on the right.
function BankWindow:BuildFoot()
    local frame = self.frame
    local label = Theme.CreateLabel(frame, "small", "muted", "LEFT")
    label:SetPoint("BOTTOMLEFT", PADDING, 14)
    label:SetText(L["Bag Slots:"])
    self.bagsLabel = label

    local free = Theme.CreateLabel(frame, "normal", "text", "RIGHT")
    free:SetPoint("BOTTOMRIGHT", -PADDING, 13)
    self.freeLabel = free

    -- Game Bank: swap to the game's own bank without leaving the banker
    -- (the owner, 2026-11-26). Its Butler Bank button swaps back.
    local swap = Widgets.CreateButton(frame, L["Game Bank"], function() BankWindow:SwapToGame() end, { height = 22 })
    swap:SetPoint("BOTTOMRIGHT", -PADDING, 9)
    self.swapButton = swap
    free:ClearAllPoints()
    free:SetPoint("RIGHT", swap, "LEFT", -10, 0)
end

BankWindow.EMPTY_SLOT = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
BankWindow.LOCK = "Interface\\PetBattles\\PetBattle-LockIcon"
BankWindow.MOST_BAG_SLOTS = 12
BankWindow.LEAST_ICON = 12

--- The square shown for a bank bag slot along the foot, made once.
local function TabIcon(index)
    local icon = tabIcons[index]
    if icon then return icon end
    icon = CreateFrame("Frame", nil, BankWindow.frame)
    icon:SetSize(TAB_ICON, TAB_ICON)
    local back = icon:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("TOPLEFT", -1, 1)
    back:SetPoint("BOTTOMRIGHT", 1, -1)
    back:SetColorTexture(Theme.Unpack("border", 0.9))
    local art = icon:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints(icon)
    art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.art = art
    local lock = icon:CreateTexture(nil, "OVERLAY")
    lock:SetPoint("CENTER")
    lock:SetSize(TAB_ICON - 8, TAB_ICON - 8)
    lock:SetTexture(BankWindow.LOCK)
    lock:Hide()
    icon.lock = lock
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function(self)
        if not self.invSlot or not self.bought then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local shown = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.invSlot)
        if not shown or (GameTooltip.NumLines and GameTooltip:NumLines() == 0) then
            GameTooltip:SetText(self.name or L["Bank"], 1, 1, 1)
        end
        GameTooltip:AddLine(L.Format("%d free", self.free or 0), Theme.Unpack("muted"))
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tabIcons[index] = icon
    return icon
end

local function InventorySlot(bag)
    local slot = ns.Items.Call({ "C_Container.ContainerIDToInventoryID", "ContainerIDToInventoryID" }, bag)
    return type(slot) == "number" and slot or nil
end

--- The bank's bag slots after the bank itself, as the game's bank shows
--- them: { bag, invSlot, bought, icon, name }. The first bank container is
--- the bank's own slots; each bag after it that has a bag slot counts,
--- bought when it has slots. Forever showed 2 bags and 6 locks (2026-11-26).
function BankWindow.BagSlots()
    local ids = ns.Errands and ns.Errands.BankBagIDs() or {}
    local main = ids[1]
    local slots = {}
    if type(main) ~= "number" then return slots end
    for bag = main + 1, main + BankWindow.MOST_BAG_SLOTS do
        local invSlot = InventorySlot(bag)
        if not invSlot then break end
        local bought = NumSlots(bag) > 0
        local icon = bought and ns.Items.Call({ "GetInventoryItemTexture" }, "player", invSlot) or nil
        if type(icon) ~= "string" and type(icon) ~= "number" then icon = nil end
        slots[#slots + 1] = {
            bag = bag, invSlot = invSlot, bought = bought,
            icon = icon or (bought and "Interface\\Icons\\INV_Misc_Bag_08") or BankWindow.EMPTY_SLOT,
            name = bought and ns.BagView.BagInfo(bag) or nil,
        }
    end
    -- A client that names no bag slots: the bags that hold slots, no locks.
    if #slots == 0 then
        for i = 2, #ids do
            if NumSlots(ids[i]) > 0 then
                local name, icon = ns.BagView.BagInfo(ids[i])
                slots[#slots + 1] = { bag = ids[i], bought = true, name = name,
                    icon = icon or "Interface\\Icons\\INV_Misc_Bag_08" }
            end
        end
    end
    return slots
end

function BankWindow:DrawFoot(places)
    local free, total = {}, 0
    for _, place in ipairs(places) do
        if not place.entry then
            free[place.bag] = (free[place.bag] or 0) + 1
            total = total + 1
        end
    end
    local slots = self.BagSlots()
    local x = Theme.TextWidth("small", L["Bag Slots:"]) + 8
    -- The slots shrink to the room left of Game Bank, so twelve bags (or a
    -- long label in another language) never run over its words.
    local swapWidth = self.swapButton and tonumber(self.swapButton:GetWidth()) or 0
    local room = WIDTH - 2 * PADDING - swapWidth - 10 - x
    local size, gap = TAB_ICON, 4
    if #slots > 0 and #slots * (size + gap) - gap > room then
        size = math.floor((room + gap) / #slots) - gap
        if size < TAB_ICON - 6 then gap = 2 size = math.floor((room + gap) / #slots) - gap end
        size = math.max(size, BankWindow.LEAST_ICON)
    end
    self.footStart, self.footIcon = x, size
    for i, info in ipairs(slots) do
        local icon = TabIcon(i)
        icon.name, icon.free, icon.invSlot, icon.bought = info.name, free[info.bag] or 0, info.invSlot, info.bought
        icon.art:SetTexture(info.icon)
        if icon.art.SetDesaturated then icon.art:SetDesaturated(not info.bought) end
        icon.lock:SetShown(not info.bought)
        icon:SetSize(size, size)
        icon.lock:SetSize(math.max(size - 8, 8), math.max(size - 8, 8))
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", self.bagsLabel, "LEFT", x, 0)
        icon:Show()
        x = x + size + gap
    end
    self.footEnd = #slots > 0 and x - gap or x
    for i = #slots + 1, #tabIcons do tabIcons[i]:Hide() end
    local text = L.Format("%d free", total)
    self.freeLabel:SetText(text)
    -- Only where it fits between the bag slots and Game Bank (a long
    -- label in another language); the empty slots heading says it too.
    room = WIDTH - 2 * PADDING - swapWidth - 10 - x
    self.freeLabel:SetShown(room >= Theme.TextWidth("normal", text) + 8)
end

--------------------------------------------------------------------------------
-- Squares
--------------------------------------------------------------------------------

local function Holder(bag)
    local holder = holders[bag]
    if holder then return holder end
    holder = CreateFrame("Frame", nil, BankWindow.content)
    holder:SetAllPoints(BankWindow.content)
    if holder.SetID then pcall(holder.SetID, holder, bag) end
    holders[bag] = holder
    return holder
end

local made = 0

--- The game's square for a bank slot, made once. Its holder carries the
--- bag, the square the slot, as Butler Bags does.
local function MakeButton(bag, slot)
    local place = bag .. ":" .. slot
    if buttons[place] then return buttons[place] end
    made = made + 1
    local name = "BlackthornesButlerBankItem" .. made
    local holder = Holder(bag)
    local ok, button = pcall(CreateFrame, "ItemButton", name, holder, "ContainerFrameItemButtonTemplate")
    if ok and type(button) == "table" then
        BankWindow.templateOK = true
    else
        BankWindow.templateOK = false
        button = CreateFrame("Button", name, holder)
    end
    if button.SetID then pcall(button.SetID, button, slot) end
    if type(button.SetBagID) == "function" and ns.BagWindow.ReadsBag(button) ~= bag then
        pcall(button.SetBagID, button, bag)
    end
    button.bfrBag, button.bfrSlot = bag, slot
    ns.BagWindow.Dress(button)
    if not BankWindow.templateOK then ns.BagWindow.OwnIcon(button) end
    ns.BagWindow.QuietTemplateGlow(button)
    button:HookScript("OnShow", ns.BagWindow.QuietTemplateGlow)
    button:Hide()
    buttons[place] = button
    return button
end
BankWindow.MakeButton = MakeButton

--- How a square looks: the item, its count and colour, its mark, item
--- level, and whether the search leaves it dim.
function BankWindow:Paint(button, entry, search)
    local icon = entry and entry.icon or nil
    local count = entry and entry.count or 0
    if self.templateOK then
        local G = _G
        if type(G.SetItemButtonTexture) == "function" then pcall(G.SetItemButtonTexture, button, icon) end
        if type(G.SetItemButtonCount) == "function" then pcall(G.SetItemButtonCount, button, count) end
        if type(G.SetItemButtonQuality) == "function" then
            pcall(G.SetItemButtonQuality, button, entry and entry.quality or nil, entry and entry.link or nil)
        end
        if type(G.SetItemButtonDesaturated) == "function" then
            pcall(G.SetItemButtonDesaturated, button, entry and entry.locked and true or false)
        end
    else
        local own = ns.BagWindow.OwnIcon(button)
        own:SetTexture(icon)
        button.bfrCount:SetText(count > 1 and tostring(count) or "")
    end

    button.bfrMark:Hide()
    local marks = entry and ns.BagView:Marks(entry)
    if marks then
        for _, kind in ipairs(ns.BagWindow.MARK_ORDER) do
            if marks[kind] then
                ns.BagWindow.ShowMark(button.bfrMark, kind)
                break
            end
        end
    end
    local level = entry and ns.BagView:ItemLevelOn() and ns.BagView.ItemLevel(entry)
    button.bfrLevel:SetText(level and tostring(level) or "")
    button.bfrGlow:Hide()
    ns.BagWindow.QuietTemplateGlow(button)

    local lit = true
    if entry then
        lit = ns.BagView.MatchesEntry(entry, search)
    elseif search then
        lit = false
    end
    button:SetAlpha(lit and 1 or 0.25)
end

local function Heading(index)
    local heading = headings[index]
    if heading then return heading end
    heading = CreateFrame("Frame", nil, BankWindow.content)
    heading:SetHeight(HEADING - 2)
    Theme.Fill(heading, "glassAlt")
    local line = heading:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(Theme.Unpack("border", 0.6))
    local name = Theme.CreateLabel(heading, "small", "accent", "LEFT")
    name:SetPoint("LEFT", 6, 0)
    heading.nameLabel = name
    local count = Theme.CreateLabel(heading, "small", "muted", "LEFT")
    count:SetPoint("LEFT", name, "RIGHT", 6, 0)
    heading.countLabel = count
    local right = Theme.CreateLabel(heading, "small", "text", "RIGHT")
    right:SetPoint("RIGHT", -6, 0)
    heading.rightLabel = right
    headings[index] = heading
    return heading
end

--- Take for Crafts on the trade goods heading: what Butler and Tradeskills
--- want from the bank, as the main window's Take from bank.
function BankWindow:TakeButton()
    if self.takeButton then return self.takeButton end
    local button = Widgets.CreateButton(self.content, L["Take for Crafts"], function()
        local _, message = ns.Errands:TakeFromBank()
        if message then ns.Print(message) end
    end, { height = 18, primary = true })
    button:Hide()
    self.takeButton = button
    return button
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

--- Something moved: draw again, once, in a moment. `now` draws at once.
function BankWindow:Changed(now)
    if not self:IsShown() then return end
    if now then return self:Draw() end
    if self.drawSoon then return end
    self.drawSoon = true
    C_Timer.After(0.05, function()
        BankWindow.drawSoon = false
        BankWindow:Draw()
    end)
end

function BankWindow:Draw()
    if not self:IsShown() then return end
    local width = tonumber(self.scroll:GetWidth()) or 0
    if width < 100 then width = WIDTH - 2 * PADDING - 22 end
    self.content:SetWidth(width)
    local size = ns.BagView:Pixels()
    local columns = math.max(1, math.floor((width + GAP) / (size + GAP)))
    local search = ns.SearchWords.Parse(self.search:GetText())

    local places = self.Slots()
    local fight = InCombat()
    local used, y, index = {}, 0, 0
    for _, heading in ipairs(headings) do heading:Hide() end
    if self.takeButton then self.takeButton:Hide() end
    local wanted = ns.Errands and ns.Errands:WantedCount() or 0
    for _, section in ipairs(self:Sections(places)) do
        if section.label then
            index = index + 1
            local heading = Heading(index)
            heading:ClearAllPoints()
            heading:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
            heading:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
            heading.nameLabel:SetText(section.label)
            heading.countLabel:SetText(section.free and "" or tostring(#section.places))
            heading.rightLabel:SetText(section.free and L.Format("%d free", section.free) or "")
            heading:Show()
            if section.key == "trade" and wanted > 0 then
                local take = self:TakeButton()
                take:SetText(L["Take for Crafts"] .. " " .. wanted)
                take:ClearAllPoints()
                take:SetPoint("RIGHT", heading, "RIGHT", -6, 0)
                take:SetFrameLevel(heading:GetFrameLevel() + 2)
                take:Show()
            end
            y = y + HEADING
        end
        local column = 0
        for _, place in ipairs(section.places) do
            local key = place.bag .. ":" .. place.slot
            local button = buttons[key] or (not fight and MakeButton(place.bag, place.slot)) or nil
            if button then
                button:SetSize(size, size)
                if ns.BagWindow.FitSquare then ns.BagWindow.FitSquare(button, size) end
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", self.content, "TOPLEFT", column * (size + GAP), -y)
                self:Paint(button, place.entry, search)
                button:Show()
                used[key] = true
            else
                self.makeWaiting = true
            end
            column = column + 1
            if column >= columns then
                column = 0
                y = y + size + GAP
            end
        end
        if column > 0 then y = y + size + GAP end
        y = y + SECTION_GAP
    end
    for key, button in pairs(buttons) do
        if not used[key] then button:Hide() end
    end
    self.contentHeight = y
    self.content:SetHeight(math.max(10, y))
    self:DrawFoot(places)
    self:SizeScroll()
end

--------------------------------------------------------------------------------
-- Opening and closing
--------------------------------------------------------------------------------

function BankWindow:CoverGame()
    if not ns.Veil then return end
    for _, name in ipairs(self.GAME_FRAMES) do
        local frame = rawget(_G, name)
        if type(frame) == "table" and not ns.Veil:Covers(frame) then ns.Veil:Cover(frame) end
    end
end

function BankWindow:UncoverGame()
    if not ns.Veil then return end
    for _, name in ipairs(self.GAME_FRAMES) do
        local frame = rawget(_G, name)
        if type(frame) == "table" and ns.Veil:Covers(frame) then ns.Veil:Uncover(frame) end
    end
end

--- First open with no kept spot: just left of Butler Bags, else left of
--- the middle.
function BankWindow:Place()
    local frame = self.frame
    local spots = ns.db and ns.db.windowSpots
    if type(spots) == "table" and spots[self.SPOT_KEY] then return end
    frame:ClearAllPoints()
    local bags = ns.BagWindow and ns.BagWindow.frame
    if bags and bags:IsShown() then
        frame:SetPoint("TOPRIGHT", bags, "TOPLEFT", -24, 0)
    else
        frame:SetPoint("RIGHT", UIParent, "CENTER", -40, 0)
    end
end

--- At a banker: up beside Butler Bags, with the game's bank out of sight.
function BankWindow:BankOpened()
    if not self:On() or InCombat() then return end
    self.swapped = false
    if self.backButton then self.backButton:Hide() end
    self:Build()
    self:Place()
    self.frame:Show()
    self:CoverGame()
    self:Draw()
end

--- Leaving the banker closes it.
function BankWindow:BankClosed()
    self.swapped = false
    if self.backButton then self.backButton:Hide() end
    if self.frame and self.frame:IsShown() then self.frame:Hide() end
    self:UncoverGame()
end

--- The Butler Bank button shown under the game's bank while it is swapped
--- in, made once. It sits on UIParent, placed under the game's frame;
--- nothing is written on the game's frame.
function BankWindow:BackButton()
    if self.backButton then return self.backButton end
    local button = Widgets.CreateButton(UIParent, L["Butler Bank"], function() BankWindow:SwapToButler() end,
        { height = 22, primary = true })
    button:SetFrameStrata("DIALOG")
    button:Hide()
    self.backButton = button
    return button
end

--- Game Bank: Butler's window goes and the game's bank shows, still open.
function BankWindow:SwapToGame()
    if InCombat() then return end
    self.swapped = true
    if self.frame then self.frame:Hide() end
    self:UncoverGame()
    local game = rawget(_G, "BankFrame")
    if type(game) == "table" then
        local back = self:BackButton()
        back:ClearAllPoints()
        back:SetPoint("TOP", game, "BOTTOM", 0, -6)
        back:Show()
    end
end

--- Butler Bank: back from the game's bank to Butler's window.
function BankWindow:SwapToButler()
    if InCombat() then return end
    self.swapped = false
    if self.backButton then self.backButton:Hide() end
    if not (ns.Errands and ns.Errands.bankOpen) then return end
    self:Build()
    self.frame:Show()
    self:CoverGame()
    self:Draw()
end

--- The close gem: this window goes and the game's bank comes back.
--- The close gem shuts the bank, as the game's own close does (the owner,
--- 2026-11-26). Forever has no CloseBankFrame, so the newer calls are
--- tried in turn. If none is there, the game's bank comes back instead,
--- so it can still be closed.
function BankWindow.CloseBank()
    local bank = rawget(_G, "C_Bank")
    if type(bank) == "table" and type(bank.CloseBankFrame) == "function" and pcall(bank.CloseBankFrame) then
        return true
    end
    local old = rawget(_G, "CloseBankFrame")
    if type(old) == "function" and pcall(old) then return true end
    local manager = rawget(_G, "C_PlayerInteractionManager")
    local enum = rawget(_G, "Enum")
    local types = type(enum) == "table" and enum.PlayerInteractionType
    local banker = type(types) == "table" and types.Banker or nil
    if type(manager) == "table" and type(manager.ClearInteraction) == "function" and banker ~= nil
        and pcall(manager.ClearInteraction, banker) then
        return true
    end
    return false
end

function BankWindow:Close()
    if self.frame then self.frame:Hide() end
    self:UncoverGame()
    self.CloseBank()
end

function BankWindow:OnEnable()
    local function Soon() BankWindow:Changed() end
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "ITEM_LOCK_CHANGED" }) do
        ns.RegisterEvent(self, event, Soon)
    end
    ns.RegisterEvent(self, "PLAYER_REGEN_ENABLED", function()
        if BankWindow.makeWaiting then
            BankWindow.makeWaiting = false
            BankWindow:Changed()
        end
    end)
end
