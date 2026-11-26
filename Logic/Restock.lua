-- Blackthornes Butler -- Logic/Restock.lua
-- The restock list (the top Discord ask; the owner said "build 1-10",
-- 2026-11-26, from the mockup butler-improve-2-restock): tell Butler what
-- this character should always carry, and it says when the bags run low.
-- At a vendor who sells it, one click buys the rest (BuyMany's plan and
-- run). Nothing is bought without that click. An empty list is off.
--
-- A line is an item ID or a kind: "food" or "water", the food or drink
-- for the character's level. A kind counts every food (or drink) in the
-- bags the character can use and that needs at least its level less
-- Restock.LEVEL_SPAN, and buys the vendor's best one that counts.
-- Food and drink are told apart by the spell they cast, named in the
-- client's own words (Restock.SPELLS), so every language works.
--
-- Saved account wide by character GUID, never renamed:
--   restock = { [GUID] = { name = full name, lines = { { item = itemID or
--     "food" or "water", keep = count } } } }
-- with a copy of the playing character's lines in its own save
-- (BlackthornesButlerCharDB.restock, never renamed), read when the client
-- won't give the GUID (a dungeon); nothing is written then.
--
-- Restocked items are kept up to their count: KeepHere:Effective takes
-- Restock:Keep as one of its numbers.

local _, ns = ...
local L = ns.L

local Restock = ns.NewModule("Restock")

local Items = ns.Items

-- A kind counts food that needs at least this many levels below yours.
Restock.LEVEL_SPAN = 15
-- The most a line keeps.
Restock.MOST = 999
-- What a new line keeps at first.
Restock.FIRST = 20
-- The kinds, in the order the Add menu shows them. Each names a spell its
-- items cast (Food, Drink) read in the client's language.
Restock.KINDS = { "food", "water" }
Restock.SPELLS = { food = 433, water = 430 }
-- Item class Consumable (0), subclass Food & Drink (5).
local CONSUMABLE, FOOD_AND_DRINK = 0, 5

Restock.version = 0

local function Text(value)
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

local function Number(value)
    local ok, read = pcall(function() return tonumber(value) end)
    return ok and read or nil
end

local function Level()
    local level = Number((Items.Call({ "UnitLevel" }, "player")))
    if level and level > 0 then return level end
    return nil
end

local function Clean(count)
    count = math.floor(tonumber(count) or 0)
    return math.max(0, math.min(Restock.MOST, count))
end

--- Is `item` one of the kinds?
function Restock.IsKind(item)
    return item == "food" or item == "water"
end

--- A line's name as the player reads it.
function Restock.Label(item)
    if item == "food" then return L["Food for my level"] end
    if item == "water" then return L["Water for my level"] end
    local name = ns.KeepAcrossUI and ns.KeepAcrossUI.ItemName(item)
    return name or L.Format("Item %d", item)
end

--------------------------------------------------------------------------------
-- The list
--------------------------------------------------------------------------------

local function All(make)
    if not ns.db then return {} end
    if type(ns.db.restock) ~= "table" then
        if not make then return {} end
        ns.db.restock = {}
    end
    return ns.db.restock
end

local function Record(guid, make)
    local all = All(make)
    local record = all[guid]
    if type(record) == "table" and type(record.lines) == "table" then return record end
    if not make then return nil end
    record = type(record) == "table" and record or {}
    record.lines = {}
    all[guid] = record
    return record
end

local function Valid(line)
    if type(line) ~= "table" then return false end
    local item = line.item
    return (Restock.IsKind(item) or (type(item) == "number" and item > 0)) and Clean(line.keep) > 0
end

local function Copy(lines)
    local copy = {}
    for _, line in ipairs(lines) do copy[#copy + 1] = { item = line.item, keep = line.keep } end
    return copy
end

--- The character playing's lines, { { item, keep } }, in the order added.
function Restock:MyLines()
    local guid = ns.KeepHere.PlayerGUID()
    local lines
    if guid then
        local record = Record(guid)
        lines = record and record.lines
    else
        lines = ns.charDB and ns.charDB.restock
    end
    local list = {}
    for _, line in ipairs(type(lines) == "table" and lines or {}) do
        if Valid(line) then list[#list + 1] = line end
    end
    return list
end

--- Is the list in use? (Anything on it.)
function Restock:IsOn()
    return #self:MyLines() > 0
end

--- How many of `item` (an item ID or a kind) the character playing keeps,
--- or nil.
function Restock:Count(item)
    for _, line in ipairs(self:MyLines()) do
        if line.item == item then return Clean(line.keep) end
    end
    return nil
end

local function Changed()
    Restock.version = Restock.version + 1
    Restock.lowKey, Restock.offerKey = nil, nil
    if ns.Verdicts then ns.Verdicts:Changed(true) end
    if ns.RestockList then ns.RestockList:Sync() end
end

--- Keep `count` of `item` (an item ID or a kind) on the character
--- playing. 0 takes it off. A new line goes at the end. True when saved.
function Restock:Set(item, count)
    if not Restock.IsKind(item) then
        item = tonumber(item)
        if not item or item <= 0 then return false end
        item = math.floor(item)
    end
    local guid = ns.KeepHere.PlayerGUID()
    -- Not sure who's playing: write nothing.
    if not guid then return false end
    count = Clean(count)
    local record = Record(guid, count > 0)
    if not record then return true end
    record.name = ns.KeepHere.PlayingName() or record.name
    local lines = record.lines
    local at
    for index, line in ipairs(lines) do
        if type(line) == "table" and line.item == item then at = index end
    end
    if count == 0 then
        if at then table.remove(lines, at) end
    elseif at then
        lines[at].keep = count
    else
        lines[#lines + 1] = { item = item, keep = count }
    end
    if ns.charDB then ns.charDB.restock = Copy(lines) end
    Changed()
    return true
end

--- What a new line keeps at first: a stack of the item, at most FIRST.
function Restock.FirstCount(item)
    if Restock.IsKind(item) then return Restock.FIRST end
    local _, _, _, _, _, _, _, stack = Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, item)
    stack = Number(stack)
    if stack and stack >= 1 then return math.min(stack, Restock.FIRST) end
    return Restock.FIRST
end

--- Add a line unless it is on the list already. True when it is there.
function Restock:Add(item)
    if self:Count(item) then return true end
    return self:Set(item, self.FirstCount(item))
end

--------------------------------------------------------------------------------
-- Food and drink
--------------------------------------------------------------------------------

-- What each item ID is: "food", "water" or false, read once.
local kindOf = {}

local function SpellName(spellID)
    local name = Items.Call({ "C_Spell.GetSpellName" }, spellID)
    if Text(name) then return name end
    name = Items.Call({ "GetSpellInfo" }, spellID)
    return Text(name)
end

--- Is the item food ("food"), drink ("water") or neither (nil)? By the
--- spell it casts, in the client's words.
function Restock.KindOf(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local known = kindOf[itemID]
    if known ~= nil then return known or nil end
    local _, _, _, _, _, classID, subclassID = Items.Call({ "C_Item.GetItemInfoInstant", "GetItemInfoInstant" }, itemID)
    if Number(classID) ~= CONSUMABLE or Number(subclassID) ~= FOOD_AND_DRINK then
        kindOf[itemID] = false
        return nil
    end
    local spell = Text((Items.Call({ "C_Item.GetItemSpell", "GetItemSpell" }, itemID)))
    -- Not loaded yet: ask again next time.
    if not spell then return nil end
    for _, kind in ipairs(Restock.KINDS) do
        local okSame, same = pcall(function() return spell == SpellName(Restock.SPELLS[kind]) end)
        if okSame and same then
            kindOf[itemID] = kind
            return kind
        end
    end
    kindOf[itemID] = false
    return nil
end

--- Forget what was learned about items (a test, or new client data).
function Restock.Forget()
    kindOf = {}
end

--- The level an item needs, or nil when the client hasn't loaded it.
local function NeedsLevel(itemID)
    local name, _, _, _, minLevel = Items.Call({ "C_Item.GetItemInfo", "GetItemInfo" }, itemID)
    if not name then
        Items:RequestLoad(itemID)
        return nil
    end
    return Number(minLevel) or 0
end

--- Does the item count toward a kind at this level? Food or drink of
--- that kind, usable now, needing at least the level less LEVEL_SPAN.
function Restock.Fits(kind, itemID, level)
    if Restock.KindOf(itemID) ~= kind then return false end
    level = level or Level()
    local needs = NeedsLevel(itemID)
    if not (level and needs) then return true end
    return needs <= level and needs >= level - Restock.LEVEL_SPAN
end

--------------------------------------------------------------------------------
-- What the bags hold
--------------------------------------------------------------------------------

--- How many the bags hold toward a line.
function Restock:Have(item)
    if not Restock.IsKind(item) then return ns.Bags:Carried(item) end
    local level, have = Level(), 0
    for _, entry in pairs(ns.Bags.slots or {}) do
        if entry.itemID and Restock.Fits(item, entry.itemID, level) then
            have = have + (entry.count or 1)
        end
    end
    return have
end

--- Lines that are short: { { item, keep, have, need } }, in list order.
--- Read once a change of the bags, the list or the level.
function Restock:Low()
    local key = ("%d:%d:%s"):format(self.version, ns.Bags.version or 0, tostring(Level()))
    if self.lowKey == key then return self.low end
    local low = {}
    for _, line in ipairs(self:MyLines()) do
        local keep = Clean(line.keep)
        local have = self:Have(line.item)
        if have < keep then
            low[#low + 1] = { item = line.item, keep = keep, have = have, need = keep - have }
        end
    end
    self.lowKey, self.low = key, low
    return low
end

--- How many of `itemID` the list keeps on the character playing, or nil.
--- A kind keeps its number of each item that counts toward it.
function Restock:Keep(itemID)
    if not itemID then return nil end
    local best
    for _, line in ipairs(self:MyLines()) do
        local keep = Clean(line.keep)
        local counts = line.item == itemID
            or (Restock.IsKind(line.item) and Restock.Fits(line.item, itemID))
        if counts and keep > 0 and (not best or keep > best) then best = keep end
    end
    return best
end

--------------------------------------------------------------------------------
-- At a vendor
--------------------------------------------------------------------------------

local function IDFromLink(link)
    if type(link) ~= "string" then return nil end
    local ok, id = pcall(function() return tonumber(link:match("item:(%d+)")) end)
    return ok and id or nil
end

--- Where this vendor sells what a line wants: the item's index, or for a
--- kind the best food or drink that counts (needs the most level, then
--- the cheapest). Nil when it doesn't.
function Restock:VendorIndex(item)
    local count = Number((Items.Call({ "GetMerchantNumItems" }))) or 0
    local level = Level()
    local best, bestNeeds, bestPrice
    for index = 1, count do
        local itemID = IDFromLink(Items.Call({ "GetMerchantItemLink" }, index))
        if itemID and not Restock.IsKind(item) then
            if itemID == item then return index end
        elseif itemID and Restock.Fits(item, itemID, level) then
            local sold = ns.Ammo.MerchantItem(index)
            if sold and sold.usable and sold.purchasable and not sold.extended and sold.price then
                local needs = NeedsLevel(itemID) or 0
                local price = sold.price / math.max(1, sold.perBuy or 1)
                if not best or needs > bestNeeds or (needs == bestNeeds and price < bestPrice) then
                    best, bestNeeds, bestPrice = index, needs, price
                end
            end
        end
    end
    return best
end

--- What to offer at this vendor: { rows = { { low, plan } }, count, cost },
--- each plan BuyMany's for that line's need (nil when the vendor doesn't
--- sell it); `count` and `cost` add up the plans that can buy. Nil away
--- from a vendor or with nothing low.
function Restock:Offer()
    if not (ns.Selling and ns.Selling:MerchantOpen()) then return nil end
    local low = self:Low()
    if #low == 0 then return nil end
    local purse = Number((Items.Call({ "GetMoney" })))
    local key = ("%s:%d:%s"):format(self.lowKey or "", ns.Ammo and ns.Ammo.version or 0, tostring(purse))
    if self.offerKey == key then return self.offer end
    local offer = { rows = {}, count = 0, cost = 0 }
    for _, each in ipairs(low) do
        local index = self:VendorIndex(each.item)
        local plan = index and ns.BuyMany:Plan(index, each.need) or nil
        offer.rows[#offer.rows + 1] = { low = each, plan = plan }
        if plan and plan.state == "buy" then
            offer.count = offer.count + plan.count
            offer.cost = offer.cost + plan.cost
        end
    end
    self.offerKey, self.offer = key, offer
    return offer
end

--- Buy what is low at this vendor: one line (`only`, an item ID or kind)
--- or every line it sells, each through BuyMany's run, one after another.
--- Only on the player's click.
function Restock:Buy(only)
    if self.buying or (ns.BuyMany and ns.BuyMany:Running()) then return false end
    local offer = self:Offer()
    if not offer then return false end
    local queue = {}
    for _, row in ipairs(offer.rows) do
        if row.plan and row.plan.state == "buy" and (only == nil or row.low.item == only) then
            queue[#queue + 1] = row.low
        end
    end
    if #queue == 0 then return false end
    self.buying = true
    local function Finish()
        Restock.buying = false
        Restock.offerKey = nil
        if ns.UI and ns.UI.Refresh then ns.UI:Refresh(true) end
        if ns.PlaceBar then ns.PlaceBar:Changed() end
    end
    local Next
    local function Plan(position)
        local low = queue[position]
        if not low then return Finish() end
        -- Planned again now: the bags and purse moved since the last one.
        local index = Restock:VendorIndex(low.item)
        local need = low.keep - Restock:Have(low.item)
        local plan = index and need > 0 and ns.BuyMany:Plan(index, need)
        if not (plan and plan.state == "buy") then return Plan(position + 1) end
        local started = ns.BuyMany:Start(plan, function(_, reason)
            if reason then return Finish() end
            -- Let the bags catch up before the next line counts them.
            C_Timer.After(ns.BuyMany.GAP, function() Next(position + 1) end)
        end)
        if not started then return Finish() end
    end
    -- Each line counts the bags read afresh.
    Next = function(position)
        ns.Bags:Scan(function() Plan(position) end)
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh(true) end
    Next(1)
    return true
end

--------------------------------------------------------------------------------
-- Words
--------------------------------------------------------------------------------

--- A low line's name: "Buy 14 Tough Jerky" when this vendor can sell it,
--- else "4 Healing Potion".
function Restock.RowName(row)
    local low, plan = row.low, row.plan
    if plan and plan.state == "buy" then
        local name = plan.item.name and Items:ColorName(plan.item.name, plan.item.itemID)
            or Restock.Label(low.item)
        return L.Format("Buy %d %s", plan.count, name)
    end
    local name = Restock.Label(low.item)
    if not Restock.IsKind(low.item) then name = Items:ColorName(name, low.item) or name end
    return L.Format("%d %s", low.need, name)
end

--- A low line's note under its name.
function Restock.RowReason(row)
    local low, plan = row.low, row.plan
    if plan and plan.state == "buy" then
        local text = L.Format("This vendor sells it. %s in all.", Items.FormatMoney(plan.cost))
        local _, notes = ns.BuyMany.Describe(plan)
        if notes ~= "" then text = text .. " " .. notes end
        return text
    end
    if plan then
        local _, note = ns.BuyMany.Describe(plan)
        if note ~= "" then return note end
    end
    return L.Format("You have %d of %d.", low.have, low.keep)
end

--- One line for /bbutler probe: the Food and Drink spell names and what
--- a bag's food reads as, so a client that names them otherwise shows.
function Restock:ProbeText()
    local parts = {}
    for _, kind in ipairs(self.KINDS) do
        parts[#parts + 1] = ("%s=%s"):format(kind, tostring(SpellName(self.SPELLS[kind])))
    end
    local seen = 0
    for _, entry in pairs(ns.Bags.slots or {}) do
        local kind = entry.itemID and self.KindOf(entry.itemID)
        if kind and seen < 3 then
            seen = seen + 1
            parts[#parts + 1] = ("%d is %s"):format(entry.itemID, kind)
        end
    end
    parts[#parts + 1] = ("%d lines"):format(#self:MyLines())
    return table.concat(parts, "; ")
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function Restock:OnEnable()
    -- Food for my level moves with the level.
    ns.RegisterEvent(self, "PLAYER_LEVEL_UP", function()
        C_Timer.After(0.5, function()
            if Restock:IsOn() then Changed() end
        end)
    end)
    ns.RegisterEvent(self, "MERCHANT_CLOSED", function()
        Restock.offer, Restock.offerKey = nil, nil
    end)
end
