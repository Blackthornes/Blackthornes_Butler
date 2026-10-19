-- Blackthornes Butler -- Logic/BagView.lua
-- What the Bags window shows: the items in groups, the marks on them, what a
-- search or a chip keeps lit, which items are new, and the bank's and every
-- character's items for the view-only tabs.
--
-- The owner asked (2026-10-19, players kept asking for a bag addon in the
-- house style) for a bag window inside Butler, with a one big bag choice.
-- Nothing here changes the bags: it only reads what Bags, Verdicts, the
-- sisters and Tradeskills' Holdings already know. UI/BagWindow.lua draws it.
--
-- Saved, account wide, never rename them: `bagWindow` (on only when true),
-- `bagGroupBy` ("todo", "type" or "grid"), `bagItemSize` ("normal",
-- "large" or "larger"), `bagItemLevel` and `bagNewGlow` (on unless false),
-- `bagScale` (the size grip's).

local _, ns = ...
local L = ns.L

local BagView = ns.NewModule("BagView")

local Items = ns.Items

BagView.GROUPS = { "todo", "type", "grid" }
BagView.GROUP_WORDS = {
    todo = L["What To Do"],
    type = L["Item Type"],
    grid = L["One Grid"],
}

BagView.SIZES = { "normal", "large", "larger" }
BagView.SIZE_WORDS = {
    normal = L["Normal"],
    large = L["Large"],
    larger = L["Larger"],
}
-- An item's square, in pixels, at each size.
BagView.SIZE_PIXELS = { normal = 37, large = 43, larger = 49 }

-- The chips, one lit at a time: what each keeps bright.
BagView.CHIPS = { "upgrade", "sell", "craft", "goal" }
BagView.CHIP_WORDS = {
    upgrade = L["Upgrades"],
    sell = L["To Sell"],
    craft = L["For My Crafts"],
    goal = L["For My Goals"],
}

-- Item Type: the game's item classes, in this order. Greys go under Sell.
BagView.TYPE_ORDER = { "quest", "armor", "weapons", "trade", "food", "other", "sell" }
BagView.TYPE_WORDS = {
    quest = L["QUEST"],
    armor = L["ARMOR"],
    weapons = L["WEAPONS"],
    trade = L["TRADE GOODS"],
    food = L["FOOD AND DRINK"],
    other = L["OTHER"],
    sell = L["Sell"]:upper(),
}

-- Moves whenever what the window shows could change.
BagView.version = 0

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

local function DB()
    return ns.db or {}
end

--- Is Butler's bag window in use? Off unless ticked (a big new feature).
function BagView:On()
    return DB().bagWindow == true
end

local function Pick(list, value, fallback)
    for _, item in ipairs(list) do
        if item == value then return value end
    end
    return fallback
end

function BagView:GroupBy()
    return Pick(self.GROUPS, DB().bagGroupBy, "todo")
end

function BagView:SetGroupBy(value)
    if not ns.db then return end
    ns.db.bagGroupBy = Pick(self.GROUPS, value, "todo")
    self:Changed()
end

function BagView:ItemSize()
    return Pick(self.SIZES, DB().bagItemSize, "normal")
end

function BagView:SetItemSize(value)
    if not ns.db then return end
    ns.db.bagItemSize = Pick(self.SIZES, value, "normal")
    self:Changed()
end

function BagView:Pixels()
    return self.SIZE_PIXELS[self:ItemSize()]
end

function BagView:ItemLevelOn()
    return DB().bagItemLevel ~= false
end

function BagView:SetItemLevelOn(on)
    if ns.db then ns.db.bagItemLevel = on and true or false end
    self:Changed()
end

function BagView:NewGlowOn()
    return DB().bagNewGlow ~= false
end

function BagView:SetNewGlowOn(on)
    if ns.db then ns.db.bagNewGlow = on and true or false end
    self:Changed()
end

--- Something the window shows moved: draw it again.
function BagView:Changed()
    self.version = self.version + 1
    if ns.BagWindow then ns.BagWindow:Changed() end
end

--------------------------------------------------------------------------------
-- Marks
--------------------------------------------------------------------------------

-- [link or ID] = marks, for one Verdicts.version.
local marks, marksVersion = {}, -1

--- What an item's square says at a glance: { upgrade, sell, mail, goal,
--- craft, quest, verdict }. The sisters are asked once per item each time
--- the verdicts move, as the Butler window asks them.
function BagView:Marks(entry)
    if not entry or not entry.itemID then return nil end
    local verdicts = ns.Verdicts
    if marksVersion ~= verdicts.version then
        marks, marksVersion = {}, verdicts.version
    end
    local key = tostring(entry.link or entry.itemID) .. "|" .. tostring(entry.count or 1)
        .. "|" .. entry.bag .. ":" .. entry.slot
    local known = marks[key]
    if known then return known end

    local verdict = verdicts:VerdictOf(entry)
    local said = ns.Sisters:AskAll(entry)
    local Sisters = ns.Sisters
    local result = {
        verdict = verdict,
        upgrade = Sisters.String(said.equipment, "upgrade") == "now",
        sell = verdict == "sell" or verdict == "auction",
        mail = verdict == "mail",
        goal = (Sisters.Number(said.farmer, "need") or 0) > 0,
        craft = (Sisters.Number(said.ts, "need") or 0) > 0 or (Sisters.Number(said.ts, "mailCount") or 0) > 0,
        quest = entry.quest ~= nil,
    }
    marks[key] = result
    return result
end

--- Does an item answer the chip lit (nil: every item does)?
function BagView:MatchesChip(entry, chip)
    if not chip then return true end
    local found = self:Marks(entry)
    return found ~= nil and found[chip] == true
end

--------------------------------------------------------------------------------
-- Search
--------------------------------------------------------------------------------

--- The words typed, folded for matching, or nil for none.
function BagView.Fold(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    return text:lower()
end

--- Does an item's name or number match what was typed?
function BagView.Matches(name, itemID, search)
    if not search then return true end
    if type(name) == "string" and name:lower():find(search, 1, true) then return true end
    return itemID ~= nil and tostring(itemID) == search
end

--- An item's name from its link, else the client.
function BagView.NameOf(entry)
    local name = Items.NameFromLink(entry.link)
    if name then return name end
    local info = ns.Everyone and ns.Everyone.Info(entry.itemID)
    return info and info.name or nil
end

--------------------------------------------------------------------------------
-- New items
--
-- How many of each item the bags held at the first look this session. More
-- than that is new until the player hovers it. Nothing is saved.
--------------------------------------------------------------------------------

BagView.seen = nil

function BagView:NoteSeen()
    if self.seen then return end
    self.seen = {}
    for _, entry in pairs(ns.Bags.slots) do
        if entry.itemID then self.seen[entry.itemID] = (self.seen[entry.itemID] or 0) + (entry.count or 1) end
    end
end

function BagView:IsNew(entry)
    if not (self.seen and entry and entry.itemID) then return false end
    return ns.Bags:Carried(entry.itemID) > (self.seen[entry.itemID] or 0)
end

--- The player looked at it: not new any more.
function BagView:Saw(itemID)
    if not (self.seen and itemID) then return end
    local now = ns.Bags:Carried(itemID)
    if now > (self.seen[itemID] or 0) then
        self.seen[itemID] = now
        return true
    end
end

--------------------------------------------------------------------------------
-- Sections
--------------------------------------------------------------------------------

local function BagOrder(a, b)
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

--- An item's place under Item Type.
function BagView.TypeOf(entry)
    if entry.quest then return "quest" end
    if entry.quality == 0 then return "sell" end
    local _, _, _, _, _, classID, subclassID = Items.Call({ "C_Item.GetItemInfoInstant", "GetItemInfoInstant" }, entry.itemID)
    classID, subclassID = tonumber(classID), tonumber(subclassID)
    if classID == 4 then return "armor" end
    if classID == 2 then return "weapons" end
    if classID == 7 then return "trade" end
    if classID == 0 and subclassID == 5 then return "food" end
    return "other"
end

--- Every slot of the carried bags in bag order, empty ones too, for One
--- Grid: { bag, slot, entry or nil }.
function BagView.AllSlots()
    local list = {}
    for _, bag in ipairs(ns.Bags.BagIDs()) do
        local count = tonumber(Items.Call({ "C_Container.GetContainerNumSlots", "GetContainerNumSlots" }, bag)) or 0
        for slot = 1, count do
            list[#list + 1] = { bag = bag, slot = slot, entry = ns.Bags.slots[bag .. ":" .. slot] }
        end
    end
    return list
end

--- The carried bags as the window lays them out: a list of sections, each
--- { key, label, verdict, places = { { bag, slot, entry } } }. A section
--- with no label is One Grid.
function BagView:Sections(groupBy)
    groupBy = groupBy or self:GroupBy()
    local sections = {}

    if groupBy == "grid" then
        sections[1] = { key = "grid", places = self.AllSlots() }
        return sections
    end

    if groupBy == "type" then
        local byType = {}
        for _, key in ipairs(self.TYPE_ORDER) do
            byType[key] = { key = key, label = self.TYPE_WORDS[key], places = {} }
        end
        local entries = {}
        for _, entry in pairs(ns.Bags.slots) do entries[#entries + 1] = entry end
        table.sort(entries, function(a, b)
            local an, bn = self.NameOf(a) or "", self.NameOf(b) or ""
            if an ~= bn then return an < bn end
            return BagOrder(a, b)
        end)
        for _, entry in ipairs(entries) do
            local places = byType[self.TypeOf(entry)].places
            places[#places + 1] = { bag = entry.bag, slot = entry.slot, entry = entry }
        end
        for _, key in ipairs(self.TYPE_ORDER) do
            if #byType[key].places > 0 then sections[#sections + 1] = byType[key] end
        end
        return sections
    end

    -- What To Do: Butler's own groups, in its order, most worth first.
    for _, group in ipairs(ns.Verdicts:Groups()) do
        local places = {}
        for _, row in ipairs(group.rows) do
            for _, entry in ipairs(row.slots) do
                places[#places + 1] = { bag = entry.bag, slot = entry.slot, entry = entry }
            end
        end
        if #places > 0 then
            sections[#sections + 1] = {
                key = group.verdict, verdict = group.verdict,
                label = (group.label or ""):upper(), places = places,
                worth = (group.worth or 0) > 0 and group.worth or nil,
            }
        end
    end
    return sections
end

--------------------------------------------------------------------------------
-- Bank and Everyone (view only)
--------------------------------------------------------------------------------

--- The character playing's bank: read live at a banker, else as
--- Tradeskills last saw it. A list of { itemID, count, link, icon, quality,
--- name }, and whether it was read live.
function BagView:BankItems()
    local list = {}
    local errands = ns.Errands
    if errands and errands.bankOpen then
        for _, bag in ipairs(errands.BankBagIDs()) do
            local count = tonumber(Items.Call({ "C_Container.GetContainerNumSlots", "GetContainerNumSlots" }, bag)) or 0
            for slot = 1, count do
                local entry = ns.Bags.ReadSlot(bag, slot)
                if entry then
                    list[#list + 1] = {
                        itemID = entry.itemID, count = entry.count, link = entry.link,
                        icon = entry.icon, quality = entry.quality, name = self.NameOf(entry),
                    }
                end
            end
        end
        return list, true
    end

    local _, me = errands and errands:Holdings()
    local bank = me and type(me.bank) == "table" and me.bank or {}
    for itemID, count in pairs(bank) do
        if type(itemID) == "number" and type(count) == "number" and count > 0 then
            local info = ns.Everyone.Info(itemID)
            list[#list + 1] = {
                itemID = itemID, count = count,
                icon = info and info.icon, quality = info and info.quality, name = info and info.name,
            }
        end
    end
    table.sort(list, function(a, b)
        local an, bn = a.name or "~", b.name or "~"
        if an ~= bn then return an < bn end
        return a.itemID < b.itemID
    end)
    return list, false
end

--- Every character's items, from All characters' list (Logic/Everyone.lua).
--- `done` runs once it is built.
function BagView:EveryoneItems(done)
    local everyone = ns.Everyone
    -- Only a build under way or one still to do calls back: a list already
    -- fresh would call `done` at once, and its redraw would ask again.
    if everyone.building or everyone:IsStale() then everyone:Fresh(done) end
    return everyone.sorted or {}
end

--------------------------------------------------------------------------------
-- The foot
--------------------------------------------------------------------------------

--- Free slots in the bags that take anything, or nil when the client won't
--- say.
function BagView.Free()
    local read = ns.FreeSpace and ns.FreeSpace.Read()
    return read and read.free or nil
end

--- The gold of every character on this realm and side Tradeskills knows,
--- the one playing as it is now. nil without Tradeskills.
function BagView.Gold()
    local errands = ns.Errands
    local list = errands and errands:Holdings()
    if type(list) ~= "table" then return nil end
    local total, any = 0, false
    for _, entry in ipairs(list) do
        if type(entry) == "table" then
            if entry.isCurrent == true then
                local money = Items.Call({ "GetMoney" })
                money = tonumber(money) or tonumber(entry.gold)
                if money then total, any = total + money, true end
            elseif entry.playing ~= true and tonumber(entry.gold) then
                -- An old record of the character playing (`playing` without
                -- `isCurrent`) is the same purse: counted once.
                total, any = total + tonumber(entry.gold), true
            end
        end
    end
    return any and total or nil
end

--------------------------------------------------------------------------------
-- Item level
--------------------------------------------------------------------------------

-- [link] = item level or false.
local levels = {}

--- The item level shown on gear (armor and weapons), or nil.
function BagView.ItemLevel(entry)
    if not (entry and entry.itemID) then return nil end
    local kind = BagView.TypeOf(entry)
    if kind ~= "armor" and kind ~= "weapons" then
        local classID = Items.ClassID(entry.itemID)
        if classID ~= 2 and classID ~= 4 then return nil end
    end
    local key = entry.link or entry.itemID
    local known = levels[key]
    if known ~= nil then return known or nil end
    local level = Items.Call({ "C_Item.GetDetailedItemLevelInfo", "GetDetailedItemLevelInfo" }, key)
    level = tonumber(level)
    if not level or level <= 1 then
        levels[key] = false
        return nil
    end
    levels[key] = math.floor(level + 0.5)
    return levels[key]
end
