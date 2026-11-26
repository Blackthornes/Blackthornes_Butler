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
    self:PruneMyAsks(low)
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
-- Other places to get it (PR 2): your bank, your other characters, a craft
-- one of yours can make, the auction house. Item lines only; a kind is
-- bought at a vendor.
--------------------------------------------------------------------------------

local function Tradeskills(method)
    local global = rawget(_G, "BlackthornesTS")
    local butler = type(global) == "table" and rawget(global, "Butler")
    if type(butler) ~= "table" or type(butler[method]) ~= "function" then return nil end
    return butler
end

--- Who on the account can craft the item, from Tradeskills, checked field
--- by field: { recipeID, per, makers = { { short, playing } } }, or nil.
function Restock.Makers(itemID)
    local butler = Tradeskills("MakersOf")
    if not butler then return nil end
    local ok, answer = pcall(butler.MakersOf, butler, itemID)
    if not ok or type(answer) ~= "table" then return nil end
    local recipeID = Number(answer.recipeID)
    if not recipeID or type(answer.makers) ~= "table" then return nil end
    local makers = {}
    for _, maker in ipairs(answer.makers) do
        local name = type(maker) == "table" and (Text(maker.short) or Text(maker.name))
        if name then makers[#makers + 1] = { short = name, playing = maker.playing == true } end
    end
    if #makers == 0 then return nil end
    return { recipeID = recipeID, per = math.max(1, math.floor(Number(answer.per) or 1)), makers = makers }
end

--- About what one costs on the auction house, from Tradeskills' price, or nil.
function Restock.AuctionPrice(itemID)
    local api = rawget(_G, "BlackthornesTS_API")
    if type(api) ~= "table" or type(api.GetPrice) ~= "function" then return nil end
    local ok, price = pcall(api.GetPrice, itemID)
    price = ok and Number(price) or nil
    if price and price > 0 then return price end
    return nil
end

--- How many another character can spare: what it carries and banks, less
--- what it keeps itself.
local function Spare(entry, itemID)
    local bags, bank = entry.bags[itemID] or 0, entry.bank[itemID] or 0
    local keep = ns.KeepHere:CountFor(entry.key, itemID) or 0
    local record = Record(entry.key)
    for _, line in ipairs(record and record.lines or {}) do
        if line.item == itemID then keep = math.max(keep, Clean(line.keep)) end
    end
    local spare = math.max(0, bags + bank - keep)
    return spare, bags, bank
end

--- The places a low line can come from, in order of cost: { bank = count }
--- (your own bank), { alt = entry, count, inBank } (the one who can spare
--- most), { craft = Makers }, { auction = price }. Each only when known.
function Restock:Sources(low)
    local sources = {}
    local itemID = low.item
    if Restock.IsKind(itemID) then return sources end
    for _, entry in ipairs(ns.KeepAcross and ns.KeepAcross:Characters() or {}) do
        if entry.isCurrent then
            local bank = entry.bank[itemID] or 0
            if bank > 0 then sources[#sources + 1] = { bank = bank } end
        end
    end
    local best
    for _, entry in ipairs(ns.KeepAcross and ns.KeepAcross:Characters() or {}) do
        if not entry.isCurrent and not entry.linked and not ns.Errands:IsMe(entry.name) then
            local spare, bags, bank = Spare(entry, itemID)
            if spare > 0 and (not best or spare > best.count) then
                best = { alt = entry, count = spare, inBank = bank > bags }
            end
        end
    end
    if best then sources[#sources + 1] = best end
    local makers = Restock.Makers(itemID)
    if makers then sources[#sources + 1] = { craft = makers } end
    local price = Restock.AuctionPrice(itemID)
    if price then sources[#sources + 1] = { auction = price } end
    return sources
end

--------------------------------------------------------------------------------
-- Asking another character (Add a Job)
--------------------------------------------------------------------------------

-- Saved account wide, never renamed:
--   restockAsks = { { from = holder key, fromName, to = full name,
--     toGUID, itemID, count } }
-- On the holder, the ask is a mail (Errands:Recipients) and a take from the
-- bank (Errands:BankWants). It goes once mailed, or once the one who asked
-- has enough.

local function Asks(make)
    if not ns.db then return {} end
    if type(ns.db.restockAsks) ~= "table" then
        if not make then return {} end
        ns.db.restockAsks = {}
    end
    return ns.db.restockAsks
end

local function AskValid(ask)
    return type(ask) == "table" and Number(ask.itemID) and Number(ask.count) and Text(ask.to)
        and Text(ask.toGUID) and (Text(ask.from) or Text(ask.fromName))
end

--- The ask this character made for an item, or nil.
function Restock:MyAsk(itemID)
    local me = ns.KeepHere.PlayerGUID()
    if not me then return nil end
    for _, ask in ipairs(Asks()) do
        if AskValid(ask) and ask.toGUID == me and ask.itemID == itemID then return ask end
    end
    return nil
end

--- Ask `entry` (another character, from Sources) to mail `count` of an
--- item here. Never the character playing; nothing when the GUID won't read.
function Restock:Ask(itemID, entry, count)
    local me = ns.KeepHere.PlayerGUID()
    local myName = ns.KeepHere.PlayingName()
    if not (me and myName and type(entry) == "table" and Text(entry.key)) then return false end
    if entry.isCurrent or entry.key == me or ns.Errands:IsMe(entry.name) then return false end
    count = Clean(count)
    if count < 1 then return false end
    local asks = Asks(true)
    for index = #asks, 1, -1 do
        local ask = asks[index]
        if type(ask) == "table" and ask.toGUID == me and ask.itemID == itemID then table.remove(asks, index) end
    end
    asks[#asks + 1] = { from = entry.key, fromName = entry.name, to = myName, toGUID = me,
        itemID = itemID, count = count }
    Changed()
    return true
end

--- Is the ask for the character playing to do?
local function ForMe(ask)
    local me = ns.KeepHere.PlayerGUID()
    if not me or ask.toGUID == me then return false end
    if ns.Errands:IsMe(ask.to) then return false end
    if Text(ask.from) and ask.from == me then return true end
    return Text(ask.fromName) ~= nil and ns.Errands:IsMe(ask.fromName)
end

--- What other characters asked the one playing to mail: { ask, to (the
--- name the mail goes to) }.
function Restock:AsksHere()
    local list = {}
    local short = {}
    for _, entry in ipairs(ns.KeepAcross and ns.KeepAcross:Characters() or {}) do
        short[entry.key] = entry.short or entry.name
    end
    for _, ask in ipairs(Asks()) do
        if AskValid(ask) and ForMe(ask) then
            list[#list + 1] = { ask = ask, to = short[ask.toGUID] or ask.to }
        end
    end
    return list
end

--- Asks mailed to `to` go once what was attached covered them. `ids` is
--- what the mail carried ({ [itemID] = count or true }), nil to trust it.
function Restock:Mailed(to, ids)
    local asks = Asks()
    local changed = false
    for index = #asks, 1, -1 do
        local ask = asks[index]
        if AskValid(ask) and ForMe(ask) and ns.Errands.SameName(ask.to, to) then
            local went = ids == nil or (ids[ask.itemID] ~= nil and ids[ask.itemID] ~= false)
            if went then
                table.remove(asks, index)
                changed = true
            end
        end
    end
    if changed then Changed() end
end

--- The one playing's asks for items no longer low go (it has enough now).
function Restock:PruneMyAsks(low)
    local me = ns.KeepHere.PlayerGUID()
    if not me or type(ns.db and ns.db.restockAsks) ~= "table" then return end
    local short = {}
    for _, each in ipairs(low) do short[each.item] = true end
    local asks = ns.db.restockAsks
    for index = #asks, 1, -1 do
        local ask = asks[index]
        if type(ask) == "table" and ask.toGUID == me and not short[ask.itemID] then table.remove(asks, index) end
    end
end

--- Restock's part of the mailbox: { to, items = { { itemID, count } } }.
function Restock:MailPlan()
    local byTo, list = {}, {}
    for _, each in ipairs(self:AsksHere()) do
        local plan = byTo[each.to]
        if not plan then
            plan = { to = each.to, items = {} }
            byTo[each.to] = plan
            list[#list + 1] = plan
        end
        plan.items[#plan.items + 1] = { itemID = each.ask.itemID, count = each.ask.count }
    end
    return list
end

--- What the asks want taken from the bank: { [itemID] = count } past what
--- the bags hold.
function Restock:BankWants()
    local wants = {}
    for _, each in ipairs(self:AsksHere()) do
        local itemID = each.ask.itemID
        wants[itemID] = (wants[itemID] or 0) + each.ask.count
    end
    for itemID, count in pairs(wants) do
        local short = count - ns.Bags:Carried(itemID)
        wants[itemID] = short > 0 and short or nil
    end
    return wants
end

--- Queue enough crafts for a low line in Tradeskills.
function Restock:QueueCraft(low, makers)
    if not (makers and low) then return false end
    local crafts = math.ceil(low.need / makers.per)
    local done = ns.Sisters:QueueCraft(makers.recipeID, crafts)
    if done then
        ns.Print(L.Format("queued %d %s in Tradeskills.", crafts, Restock.Label(low.item)))
    end
    return done
end

--------------------------------------------------------------------------------
-- Words
--------------------------------------------------------------------------------

--- The places a low line can come from, kept while the line, the bags and
--- the verdicts stand still (Tradeskills is asked once a look).
function Restock:SourcesFor(low)
    local key = ("%s:%d"):format(self.lowKey or "", ns.Verdicts and ns.Verdicts.version or 0)
    if self.sourcesKey ~= key then self.sourcesKey, self.sources = key, {} end
    local found = self.sources[low.item]
    if not found then
        found = self:Sources(low)
        self.sources[low.item] = found
    end
    return found
end

--- The rows of the RESTOCK group: { low, plan, sources } for each short
--- line (the vendor's plan at a vendor), then { ask, to } for each mail
--- another character asked of this one.
function Restock:Rows()
    local rows = {}
    local low = self:Low()
    local offer = #low > 0 and self:Offer()
    if offer then
        for _, row in ipairs(offer.rows) do rows[#rows + 1] = row end
    else
        for _, each in ipairs(low) do rows[#rows + 1] = { low = each } end
    end
    for _, row in ipairs(rows) do
        if not (row.plan and row.plan.state == "buy") then row.sources = self:SourcesFor(row.low) end
    end
    for _, each in ipairs(self:AsksHere()) do rows[#rows + 1] = { ask = each.ask, to = each.to } end
    return rows
end

local function ItemName(itemID)
    local name = Restock.Label(itemID)
    return Items:ColorName(name, itemID) or name
end

--- A row's name: "Buy 14 Tough Jerky" when this vendor can sell it, "Mail
--- 6 Heavy Wool Bandage to Ana" for an ask, else "4 Healing Potion".
function Restock.RowName(row)
    if row.ask then
        return L.Format("Mail %d %s to %s", row.ask.count, ItemName(row.ask.itemID), row.to)
    end
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

--- One sentence for a place the line can come from.
function Restock.SourceText(source, low)
    if source.bank then return L.Format("Your bank has %d.", source.bank) end
    if source.alt then
        local ask = ns.Restock:MyAsk(low.item)
        local name = source.alt.short or source.alt.name
        if ask then return L.Format("Asked %s to mail %d.", name, ask.count) end
        if source.inBank then return L.Format("%s has %d in the bank.", name, source.count) end
        return L.Format("%s has %d in their bags.", name, source.count)
    end
    if source.craft then
        local maker = source.craft.makers[1]
        for _, each in ipairs(source.craft.makers) do
            if each.playing then maker = each end
        end
        if maker.playing then return L["You can make them."] end
        return L.Format("%s can make them.", maker.short)
    end
    if source.auction then
        return L.Format("On the auction house, about %s each.", Items.FormatMoney(source.auction))
    end
    return nil
end

--- A row's note under its name.
function Restock.RowReason(row)
    if row.ask then return L.Format("%s runs low on these.", row.to) end
    local low, plan = row.low, row.plan
    if plan and plan.state == "buy" then
        local text = L.Format("This vendor sells it. %s in all.", Items.FormatMoney(plan.cost))
        local _, notes = ns.BuyMany.Describe(plan)
        if notes ~= "" then text = text .. " " .. notes end
        return text
    end
    local parts = {}
    if plan then
        local _, note = ns.BuyMany.Describe(plan)
        if note ~= "" then parts[#parts + 1] = note end
    end
    for _, source in ipairs(row.sources or {}) do
        if #parts >= 2 then break end
        parts[#parts + 1] = Restock.SourceText(source, low)
    end
    if #parts == 0 then return L.Format("You have %d of %d.", low.have, low.keep) end
    return table.concat(parts, " ")
end

--- The row's button, or nil: { label, run }. Buy at a vendor who sells
--- it; Search at the auction house; Add a Job for another character who
--- has some; Queue for a craft one of yours can make.
function Restock.RowAction(row)
    if row.ask then return nil end
    local low, plan = row.low, row.plan
    if plan and plan.state == "buy" then
        return { label = ns.Restock.buying and L["Buying..."] or L.Format("Buy %d", plan.count),
            run = function() ns.Restock:Buy(low.item) end }
    end
    local find = {}
    for _, source in ipairs(row.sources or {}) do
        for kind in pairs(source) do find[kind] = find[kind] or source end
    end
    if find.auction and ns.Quests and ns.Quests.CanSearch() then
        return { label = L["Search"], run = function()
            return ns.Quests:Search({ { itemID = low.item, count = low.need } })
        end }
    end
    if find.alt and not ns.Restock:MyAsk(low.item) then
        local count = math.min(low.need, find.alt.count)
        return { label = L["Add a Job"], tip = L.Format("%s mails you %d next time they're at a mailbox.",
            find.alt.alt.short or find.alt.alt.name, count),
            run = function() return ns.Restock:Ask(low.item, find.alt.alt, count) end }
    end
    if find.craft and Tradeskills("QueueCraft") then
        return { label = L["Queue"], tip = L["Adds the crafts to the Tradeskills queue."],
            run = function() return ns.Restock:QueueCraft(low, find.craft.craft) end }
    end
    return nil
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
